//
//  MonoTaskClearResultTests.swift
//  Monstra
//
//  Created by Assistant on 2025/1/19.
//

import XCTest
@preconcurrency @testable import Monstask
@testable import MonstraBase

/// Comprehensive test suite for MonoTask clearResult functionality
///
/// This test suite validates clearResult behavior across all scenarios including:
/// - Basic clearResult functionality with different strategies
/// - Cross-scenario interactions (clearResult during execution, caching, retries)
/// - Thread safety under concurrent access
/// - Edge cases and error conditions
/// - Integration with different execution methods
final class MonoTaskClearResultTests: XCTestCase {

    // MARK: - Test Utilities
    
    private actor ClearResultCounter {
        private var executionCount = 0
        private var cancelCount = 0
        private var completionCount = 0
        private var clearResultCallCount = 0
        
        @discardableResult
        func incrementExecution() -> Int {
            executionCount += 1
            return executionCount
        }
        
        @discardableResult
        func incrementCancel() -> Int {
            cancelCount += 1
            return cancelCount
        }
        
        @discardableResult
        func incrementCompletion() -> Int {
            completionCount += 1
            return completionCount
        }
        
        @discardableResult
        func incrementClearResultCall() -> Int {
            clearResultCallCount += 1
            return clearResultCallCount
        }
        
        func getCounts() -> (executions: Int, cancels: Int, completions: Int, clearCalls: Int) {
            return (executionCount, cancelCount, completionCount, clearResultCallCount)
        }
        
        func reset() {
            executionCount = 0
            cancelCount = 0
            completionCount = 0
            clearResultCallCount = 0
        }
    }
    
    private actor TestResultCollector<T> {
        private var results: [T] = []
        private var errors: [Error] = []
        
        func addResult(_ result: T) {
            results.append(result)
        }
        
        func addError(_ error: Error) {
            errors.append(error)
        }
        
        func getResults() -> ([T], [Error]) {
            return (results, errors)
        }
        
        func clear() {
            results.removeAll()
            errors.removeAll()
        }
    }

    // MARK: - 1. Basic clearResult Functionality Tests

    /// Test clearResult with .allowCompletion strategy (default)
    func testClearResultAllowCompletionWhenIdle() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                callback(.success("execution_\(count)"))
            }
        }
        
        // Execute and cache result
        let result1 = await task.asyncExecute()
        XCTAssertEqual(task.currentResult, "execution_1")
        
        // Clear result when idle
        await counter.incrementClearResultCall()
        task.clearResult(ongoingExecutionStrategy: .allowCompletion)
        
        // Result should be cleared
        XCTAssertNil(task.currentResult, "Result should be cleared")
        XCTAssertFalse(task.isExecuting, "Should not be executing after clear")
        
        // Next execution should be fresh
        let result2 = await task.asyncExecute()
        
        let counts = await counter.getCounts()
        XCTAssertEqual(counts.executions, 2, "Should have 2 executions")
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        
        if case .success(let value1) = result1, case .success(let value2) = result2 {
            XCTAssertEqual(value1, "execution_1")
            XCTAssertEqual(value2, "execution_2")
        } else {
            XCTFail("Both executions should succeed")
        }
    }

    /// Test clearResult with .cancel strategy during execution
    func testClearResultCancelDuringExecution() async {
        let counter = ClearResultCounter()
        let resultCollector = TestResultCollector<String>()
        
        // Use a semaphore to ensure precise timing coordination
        actor ExecutionCoordinator {
            private var executionStarted = false
            private var shouldContinue = false
            
            func markExecutionStarted() {
                executionStarted = true
            }
            
            func waitForContinue() async {
                while !shouldContinue {
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
            }
            
            func allowContinue() {
                shouldContinue = true
            }
            
            func hasExecutionStarted() -> Bool {
                return executionStarted
            }
        }
        
        let coordinator = ExecutionCoordinator()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                // Signal that execution has started
                await coordinator.markExecutionStarted()
                
                // Wait for the coordinator to allow continuation
                await coordinator.waitForContinue()
                
                let count = await counter.incrementExecution()
                callback(.success("execution_\(count)"))
            }
        }
        
        // Start execution and multiple callbacks
        await withTaskGroup(of: Void.self) { group in
            // Start multiple executions (should be merged)
            for i in 0..<3 {
                group.addTask {
                    task.execute { result in
                        Task {
                            switch result {
                            case .success(let value):
                                await resultCollector.addResult("success_\(i)_\(value)")
                            case .failure(let error):
                                await resultCollector.addError(error)
                                await counter.incrementCancel()
                            }
                        }
                    }
                }
            }
            
            // Wait for execution to start, then clear with cancel
            group.addTask {
                // Wait for execution to truly start
                while !(await coordinator.hasExecutionStarted()) {
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
                
                XCTAssertTrue(task.isExecuting, "Task should be executing")
                
                // Clear result with cancel strategy
                await counter.incrementClearResultCall()
                task.clearResult(ongoingExecutionStrategy: .cancel)
                
                // Allow execution to continue (though it should be cancelled)
                await coordinator.allowContinue()
            }
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        let (results, errors) = await resultCollector.getResults()
        let counts = await counter.getCounts()
        
        // All callbacks should receive cancellation errors
        XCTAssertEqual(errors.count, 3, "All 3 callbacks should receive cancellation errors")
        XCTAssertEqual(results.count, 0, "No success results should be received")
        XCTAssertEqual(counts.cancels, 3, "Should record 3 cancellations")
        
        // Verify error type
        for error in errors {
            XCTAssertTrue(error is MonoTask<String>.Errors, "Should be MonoTask.Errors")
            if let monoError = error as? MonoTask<String>.Errors {
                XCTAssertEqual(monoError, .executionCancelledDueToClearResult)
            }
        }
    }

    /// Test clearResult with .restart strategy during execution
    func testClearResultRestartDuringExecution() async {
        let counter = ClearResultCounter()
        let resultCollector = TestResultCollector<String>()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                callback(.success("execution_\(count)"))
            }
        }
        
        await withTaskGroup(of: Void.self) { group in
            // Start execution with callback
            group.addTask {
                task.execute { result in
                    Task {
                        if case .success(let value) = result {
                            await resultCollector.addResult(value)
                        }
                    }
                }
            }
            
            // Wait for execution to start, then clear with restart
            group.addTask {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms - ensure execution started
                XCTAssertTrue(task.isExecuting, "Task should be executing")
                
                await counter.incrementClearResultCall()
                task.clearResult(ongoingExecutionStrategy: .restart)
                
                // Wait for restart execution to complete
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
            }
        }

        let (results, _) = await resultCollector.getResults()
        let counts = await counter.getCounts()
        
        // Should have both original execution and restarted execution
        XCTAssertGreaterThanOrEqual(counts.executions, 2, "Should have at least 2 executions (original + restart)")
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        XCTAssertGreaterThanOrEqual(results.count, 1, "Should have at least 1 result")
    }

    // MARK: - 2. Cross-Scenario Tests: clearResult During Different Execution States

    /// Test clearResult during cache hit scenario
    func testClearResultDuringCacheHit() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                callback(.success("cached_\(count)"))
            }
        }
        
        // First execution - cache the result
        let _ = await task.asyncExecute()
        XCTAssertEqual(task.currentResult, "cached_1")
        
        // Start concurrent executions that should hit cache
        let resultCollector = TestResultCollector<String>()
        
        await withTaskGroup(of: Void.self) { group in
            // Start multiple cache hits
            for i in 0..<5 {
                group.addTask {
                    let result = await task.asyncExecute()
                    if case .success(let value) = result {
                        await resultCollector.addResult("cache_hit_\(i)_\(value)")
                    }
                }
            }
            
            // Clear result during cache hits
            group.addTask {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
                await counter.incrementClearResultCall()
                task.clearResult()
            }
        }
        
        let (results, _) = await resultCollector.getResults()
        let counts = await counter.getCounts()
        
        XCTAssertEqual(counts.executions, 1, "Should still have only 1 execution (cache hits)")
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        XCTAssertEqual(results.count, 5, "All cache hits should succeed")
        XCTAssertNil(task.currentResult, "Result should be cleared after clear call")
    }

    /// Test clearResult during retry scenario
    func testClearResultDuringRetries() async {
        let counter = ClearResultCounter()
        let attemptCounter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .count(count: 3, intervalProxy: .fixed(timeInterval: 0.05)),
            resultExpireDuration: 0.1
        ) { callback in
            Task {
                let execution = await counter.incrementExecution()
                let attempt = await attemptCounter.incrementExecution()
                
                if attempt <= 2 {
                    callback(.failure(NSError(domain: "TestError", code: attempt)))
                } else {
                    callback(.success("retry_success_\(execution)"))
                }
            }
        }
        
        let resultCollector = TestResultCollector<String>()
        
        await withTaskGroup(of: Void.self) { group in
            // Start execution that will retry
            group.addTask {
                let result = await task.asyncExecute()
                switch result {
                case .success(let value):
                    await resultCollector.addResult(value)
                case .failure(let error):
                    await resultCollector.addError(error)
                }
            }
            
            // Clear result during retry phase
            group.addTask {
                try? await Task.sleep(nanoseconds: 30_000_000) // 30ms - during retry
                XCTAssertTrue(task.isExecuting, "Should be executing during retry")
                
                await counter.incrementClearResultCall()
                task.clearResult(ongoingExecutionStrategy: .cancel)
                
                XCTAssertFalse(task.isExecuting, "Should not be executing after cancel")
            }
        }
        
        let (results, errors) = await resultCollector.getResults()
        let counts = await counter.getCounts()
        
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        XCTAssertEqual(errors.count, 1, "Should have 1 cancellation error")
        XCTAssertEqual(results.count, 0, "Should have no success results due to cancellation")
        
        // Verify cancellation error
        if let error = errors.first as? MonoTask<String>.Errors {
            XCTAssertEqual(error, .executionCancelledDueToClearResult)
        } else {
            XCTFail("Should receive MonoTask cancellation error")
        }
    }

    // MARK: - 3. Cross-Method Integration Tests

    /// Test clearResult interaction with different execution methods
    func testClearResultWithMixedExecutionMethods() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.5
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
                callback(.success("mixed_\(count)"))
            }
        }
        
        let resultCollector = TestResultCollector<String>()
        
        await withTaskGroup(of: Void.self) { group in
            // Method 1: Callback-based execute
            group.addTask {
                task.execute { result in
                    Task {
                        if case .success(let value) = result {
                            await resultCollector.addResult("callback_\(value)")
                        }
                    }
                }
            }
            
            // Method 2: Async execute
            group.addTask {
                let result = await task.asyncExecute()
                if case .success(let value) = result {
                    await resultCollector.addResult("async_\(value)")
                }
            }
            
            // Method 3: Execute throws
            group.addTask {
                do {
                    let value = try await task.executeThrows()
                    await resultCollector.addResult("throws_\(value)")
                } catch {
                    await resultCollector.addError(error)
                }
            }
            
            // Clear result during mixed executions
            group.addTask {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s - mid execution
                await counter.incrementClearResultCall()
                task.clearResult(ongoingExecutionStrategy: .allowCompletion)
            }
        }
        
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s - mid execution
        
        let (results, errors) = await resultCollector.getResults()
        let counts = await counter.getCounts()
        
        XCTAssertEqual(counts.executions, 1, "Should execute only once despite mixed methods")
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        XCTAssertEqual(results.count, 3, "All 3 methods should get results")
        XCTAssertEqual(errors.count, 0, "Should have no errors with allowCompletion")
        
        // All methods should get the same result
        let uniqueResults = Set(results.map { $0.contains("mixed_1") })
        XCTAssertEqual(uniqueResults.count, 1, "All methods should get the same execution result")
    }

    // MARK: - 4. Thread Safety and Concurrent Access Tests

    /// Test concurrent clearResult calls
    func testConcurrentClearResultCalls() async {
        let counter = ClearResultCounter()
        
        // Use coordination to ensure cancellation happens during execution
        actor ExecutionCoordinator {
            private var executionStarted = false
            private var shouldContinue = false
            
            func markExecutionStarted() {
                executionStarted = true
            }
            
            func waitForContinue() async {
                while !shouldContinue {
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
            }
            
            func allowContinue() {
                shouldContinue = true
            }
            
            func hasExecutionStarted() -> Bool {
                return executionStarted
            }
        }
        
        let coordinator = ExecutionCoordinator()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                // Signal that execution has started
                await coordinator.markExecutionStarted()
                
                // Wait for the coordinator to allow continuation
                await coordinator.waitForContinue()
                
                let count = await counter.incrementExecution()
                callback(.success("concurrent_clear_\(count)"))
            }
        }
        
        let resultCollector = TestResultCollector<String>()
        
        await withTaskGroup(of: Void.self) { group in
            // Start execution with callback
            group.addTask {
                task.execute { result in
                    Task {
                        switch result {
                        case .success(let value):
                            await resultCollector.addResult(value)
                        case .failure(let error):
                            await resultCollector.addError(error)
                        }
                    }
                }
            }
            
            // Wait for execution to truly start
            group.addTask {
                while !(await coordinator.hasExecutionStarted()) {
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
                
                XCTAssertTrue(task.isExecuting, "Task should be executing")
                
                // Multiple concurrent clearResult calls
                await withTaskGroup(of: Void.self) { clearGroup in
                    for i in 0..<5 {
                        clearGroup.addTask {
                            try? await Task.sleep(nanoseconds: UInt64(i * 2_000_000)) // Stagger calls 0-8ms
                            
                            await counter.incrementClearResultCall()
                            task.clearResult(ongoingExecutionStrategy: .cancel)
                        }
                    }
                }
                
                // Allow execution to continue (though it should be cancelled)
                await coordinator.allowContinue()
            }
        }
        
        let (results, errors) = await resultCollector.getResults()
        let counts = await counter.getCounts()
        
        XCTAssertEqual(counts.clearCalls, 5, "Should have 5 clear calls")
        XCTAssertGreaterThanOrEqual(errors.count, 1, "Should have at least 1 cancellation error")
        XCTAssertEqual(results.count, 0, "Should have no success results due to cancellation")
        XCTAssertFalse(task.isExecuting, "Should not be executing after cancellation")
    }

    /// Test clearResult thread safety with property access
    func testClearResultThreadSafetyWithPropertyAccess() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.2
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                callback(.success("thread_safe_\(count)"))
            }
        }
        
        let resultCollector = TestResultCollector<String?>()
        let executingStates = TestResultCollector<Bool>()
        
        await withTaskGroup(of: Void.self) { group in
            // Start execution
            group.addTask {
                let _ = await task.asyncExecute()
            }
            
            // Concurrent property access and clearResult
            for i in 0..<30 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(i * 5_000_000)) // Staggered access
                    
                    // Access properties
                    let current = task.currentResult
                    let executing = task.isExecuting
                    
                    await resultCollector.addResult(current)
                    await executingStates.addResult(executing)
                    
                    // Clear result occasionally
                    if i % 4 == 0 {
                        await counter.incrementClearResultCall()
                        task.clearResult()
                    }
                }
            }
        }
        
        let (currentResults, _) = await resultCollector.getResults()
        let (executingResults, _) = await executingStates.getResults()
        let counts = await counter.getCounts()
        
        // Should not crash and should collect all results
        XCTAssertEqual(currentResults.count, 30, "Should collect all currentResult calls")
        XCTAssertEqual(executingResults.count, 30, "Should collect all isExecuting calls")
        XCTAssertGreaterThan(counts.clearCalls, 0, "Should have some clear calls")
        
        // Final state should be clean
        XCTAssertNil(task.currentResult, "Final result should be cleared")
        XCTAssertFalse(task.isExecuting, "Should not be executing at end")
    }
    
    func testClearResultThreadSafetyWithPropertyAccess2() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.2
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                callback(.success("thread_safe_\(count)"))
            }
        }
        
        let resultCollector = TestResultCollector<String?>()
        let executingStates = TestResultCollector<Bool>()
        
        await withTaskGroup(of: Void.self) { group in
            // Start execution
            group.addTask {
                let _ = await task.asyncExecute()
            }
            
            // Concurrent property access and clearResult
            for i in 0..<19 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(i * 5_000_000)) // Staggered access
                    
                    // Access properties
                    let current = task.currentResult
                    let executing = task.isExecuting
                    
                    await resultCollector.addResult(current)
                    await executingStates.addResult(executing)
                    
                    // Clear result occasionally
                    if i % 4 == 0 {
                        await counter.incrementClearResultCall()
                        task.clearResult()
                    }
                }
            }
        }
        
        // Ensure execution is complete before final clearResult
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms - ensure execution completed
        
        // Final clearResult to guarantee cleared state
        await counter.incrementClearResultCall()
        task.clearResult()
        
        let (currentResults, _) = await resultCollector.getResults()
        let (executingResults, _) = await executingStates.getResults()
        let counts = await counter.getCounts()
        
        // Should not crash and should collect all results
        XCTAssertEqual(currentResults.count, 19, "Should collect all currentResult calls")
        XCTAssertEqual(executingResults.count, 19, "Should collect all isExecuting calls")
        XCTAssertGreaterThan(counts.clearCalls, 0, "Should have some clear calls")
        
        // Final state should be clean
        XCTAssertNil(task.currentResult, "Final result should be cleared")
        XCTAssertFalse(task.isExecuting, "Should not be executing at end")
    }

    // MARK: - 5. Edge Cases and Error Conditions

    /// Test clearResult on already completed task
    func testClearResultOnCompletedTask() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                callback(.success("completed_\(count)"))
            }
        }
        
        // Execute and complete
        let result1 = await task.asyncExecute()
        XCTAssertEqual(task.currentResult, "completed_1")
        XCTAssertFalse(task.isExecuting)
        
        // Clear result on completed task
        await counter.incrementClearResultCall()
        task.clearResult()
        
        XCTAssertNil(task.currentResult, "Result should be cleared")
        
        // Execute again should work normally
        let result2 = await task.asyncExecute()
        
        let counts = await counter.getCounts()
        XCTAssertEqual(counts.executions, 2, "Should have 2 executions")
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        
        if case .success(let value1) = result1, case .success(let value2) = result2 {
            XCTAssertEqual(value1, "completed_1")
            XCTAssertEqual(value2, "completed_2")
        } else {
            XCTFail("Both executions should succeed")
        }
    }

    /// Test clearResult behavior with expired cache
    func testClearResultWithExpiredCache() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.05 // Very short 50ms cache
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                callback(.success("expired_\(count)"))
            }
        }
        
        // Execute and cache
        let _ = await task.asyncExecute()
        XCTAssertEqual(task.currentResult, "expired_1")
        
        // Wait for cache expiration
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Cache should be expired (currentResult returns nil)
        XCTAssertNil(task.currentResult, "Cache should be expired")
        
        // Clear result on expired cache
        await counter.incrementClearResultCall()
        task.clearResult()
        
        // Should still be nil and work normally
        XCTAssertNil(task.currentResult, "Result should still be nil")
        
        // Next execution should be fresh
        let result2 = await task.asyncExecute()
        
        let counts = await counter.getCounts()
        XCTAssertEqual(counts.executions, 2, "Should have 2 executions")
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        
        if case .success(let value2) = result2 {
            XCTAssertEqual(value2, "expired_2")
        } else {
            XCTFail("Second execution should succeed")
        }
    }

    /// Test clearResult error handling and recovery
    func testClearResultErrorHandlingAndRecovery() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                if count == 1 {
                    callback(.failure(NSError(domain: "TestError", code: 1)))
                } else {
                    callback(.success("recovered_\(count)"))
                }
            }
        }
        
        // First execution fails
        let result1 = await task.asyncExecute()
        XCTAssertNil(task.currentResult, "Should have no cached result after failure")
        
        // Clear result after failure
        await counter.incrementClearResultCall()
        task.clearResult()
        
        // Second execution should succeed
        let result2 = await task.asyncExecute()
        
        let counts = await counter.getCounts()
        XCTAssertEqual(counts.executions, 2, "Should have 2 executions")
        XCTAssertEqual(counts.clearCalls, 1, "Should have 1 clear call")
        
        if case .failure = result1, case .success(let value2) = result2 {
            XCTAssertEqual(value2, "recovered_2")
        } else {
            XCTFail("First should fail, second should succeed")
        }
    }

    // MARK: - 6. Performance and Stress Tests

    /// Test clearResult under high concurrency
    func testClearResultHighConcurrencyStress() async {
        let counter = ClearResultCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.1
        ) { callback in
            Task {
                let count = await counter.incrementExecution()
                // Variable execution time
                try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...50_000_000))
                callback(.success("stress_\(count)"))
            }
        }
        
        let resultCollector = TestResultCollector<String>()
        
        // High concurrency: 50 concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    if i % 10 == 0 {
                        // Clear result occasionally
                        try? await Task.sleep(nanoseconds: UInt64(i * 1_000_000))
                        await counter.incrementClearResultCall()
                        task.clearResult(ongoingExecutionStrategy: .allowCompletion)
                    } else {
                        // Execute normally
                        let result = await task.asyncExecute()
                        if case .success(let value) = result {
                            await resultCollector.addResult(value)
                        }
                    }
                }
            }
        }
        
        let (results, _) = await resultCollector.getResults()
        let counts = await counter.getCounts()
        
        // Should not crash under high concurrency
        XCTAssertGreaterThan(results.count, 0, "Should have some successful results")
        XCTAssertGreaterThan(counts.clearCalls, 0, "Should have some clear calls")
        XCTAssertFalse(task.isExecuting, "Should not be executing at end")
        
        print("High concurrency stress test completed:")
        print("- Executions: \(counts.executions)")
        print("- Clear calls: \(counts.clearCalls)")
        print("- Successful results: \(results.count)")
    }
}
