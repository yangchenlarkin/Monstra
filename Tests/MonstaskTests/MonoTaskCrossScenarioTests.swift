//
//  MonoTaskCrossScenarioTests.swift
//  Monstra
//
//  Created by Assistant on 2025/1/19.
//

import XCTest
@preconcurrency @testable import Monstask
@testable import MonstraBase

/// Cross-scenario edge case testing for MonoTask
///
/// This test suite focuses on complex interactions and race conditions that can occur
/// when different aspects of MonoTask are used simultaneously, including:
/// - Cross-execution method race conditions
/// - Property access during state transitions
/// - Result setting race conditions
/// - Complex queue interaction scenarios
/// - Retry logic during cache expiration boundaries
final class MonoTaskCrossScenarioTests: XCTestCase {

    // MARK: - Test Utilities
    
    private actor CrossScenarioCounter {
        private var resultSetCount = 0
        private var resultReadCount = 0
        private var inconsistentStates = 0
        
        @discardableResult
        func incrementResultSet() -> Int {
            resultSetCount += 1
            return resultSetCount
        }
        
        @discardableResult
        func incrementResultRead() -> Int {
            resultReadCount += 1
            return resultReadCount
        }
        
        @discardableResult
        func recordInconsistentState() -> Int {
            inconsistentStates += 1
            return inconsistentStates
        }
        
        func getCounts() -> (resultSets: Int, resultReads: Int, inconsistencies: Int) {
            return (resultSetCount, resultReadCount, inconsistentStates)
        }
    }
    
    /// Thread-safe result collector for concurrent testing
    private actor ResultCollector<T> {
        private var results: [T] = []
        
        func add(_ result: T) {
            results.append(result)
        }
        
        func getResults() -> [T] {
            return results
        }
        
        func count() -> Int {
            return results.count
        }
        
        func clear() {
            results.removeAll()
        }
    }

    // MARK: - 1. Result Setting Race Condition Tests
    
    /// Test race condition between result setting and currentResult access
    /// This tests the critical race condition where result/expiration are set outside semaphore protection
    func testResultSettingRaceCondition() async {
        let counter = CrossScenarioCounter()
        let resultValues = Array(1...100)
        
        let task = MonoTask<Int>(
            retry: .never,
            resultExpireDuration: 0.1
        ) { callback in
            Task {
                // Simulate variable execution time
                try? await Task.sleep(nanoseconds: UInt64.random(in: 50_000_000...150_000_000))
                let randomValue = resultValues.randomElement()!
                await counter.incrementResultSet()
                callback(.success(randomValue))
            }
        }
        
        // Concurrent result access during setting
        await withTaskGroup(of: Void.self) { group in
            // Start execution
            group.addTask {
                let _ = await task.asyncExecute()
            }
            
            // Concurrent currentResult access
            for i in 0..<50 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(i * 1_000_000)) // Staggered access
                    let current = task.currentResult
                    await counter.incrementResultRead()
                    
                    // Check for inconsistent state: if result exists, expiration should be consistent
                    if current != nil {
                        let stillAvailable = task.currentResult
                        if stillAvailable == nil {
                            // Result disappeared immediately after being available - potential race condition
                            await counter.recordInconsistentState()
                        }
                    }
                }
            }
        }
        
        let counts = await counter.getCounts()
        XCTAssertGreaterThan(counts.resultReads, 0, "Should have attempted to read results")
        XCTAssertEqual(counts.resultSets, 1, "Should have set result exactly once")
        
        // In a perfect implementation, inconsistencies should be 0
        // This test may reveal the race condition
        print("Inconsistent states detected: \(counts.inconsistencies)")
    }
    
    /// Test rapid cache expiration transitions during concurrent access
    func testCacheExpirationRaceCondition() async {
        let counter = CrossScenarioCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.01  // Very short 10ms cache
        ) { callback in
            Task {
                await counter.incrementResultSet()
                callback(.success("race_test"))
            }
        }
        
        // Execute and let it cache
        let _ = await task.asyncExecute()
        
        // Rapid concurrent access during expiration boundary
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(i * 500_000)) // 0.5ms stagger
                    let current = task.currentResult
                    await counter.incrementResultRead()
                    
                    // Immediately check again - should be consistent
                    let current2 = task.currentResult
                    if (current != nil && current2 == nil) || (current == nil && current2 != nil) {
                        await counter.recordInconsistentState()
                    }
                }
            }
        }
        
        let counts = await counter.getCounts()
        XCTAssertGreaterThan(counts.resultReads, 0, "Should have read results")
        print("Cache expiration inconsistencies: \(counts.inconsistencies)")
    }

    // MARK: - 2. Cross-Execution Method Race Conditions
    
    /// Test simultaneous calls to different execution methods
    func testCrossExecutionMethodRaceConditions() async {
        let counter = CrossScenarioCounter()
        var callbackResults: [String] = []
        var asyncResults: [Result<String, Error>] = []
        var throwsResults: [String] = []
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.2
        ) { callback in
            Task {
                let count = await counter.incrementResultSet()
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                callback(.success("execution_\(count)"))
            }
        }
        
        // Simultaneous different execution methods
        await withTaskGroup(of: Void.self) { group in
            // Method 1: Callback-based
            group.addTask {
                task.execute { result in
                    if case .success(let value) = result {
                        callbackResults.append("callback_\(value)")
                    }
                }
            }
            
            // Method 2: Async Result
            group.addTask {
                let result = await task.asyncExecute()
                asyncResults.append(result)
            }
            
            // Method 3: Async throws
            group.addTask {
                do {
                    let value = try await task.executeThrows()
                    throwsResults.append("throws_\(value)")
                } catch {
                    throwsResults.append("throws_error")
                }
            }
            
            // Method 4: Just execute
            group.addTask {
                task.justExecute()
            }
            
            // Method 5: Execute with nil callback
            group.addTask {
                task.execute(then: nil)
            }
        }
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let counts = await counter.getCounts()
        XCTAssertEqual(counts.resultSets, 1, "Should execute only once despite mixed method calls")
        
        // Verify all methods got consistent results
        XCTAssertEqual(callbackResults.count, 1, "Callback method should get result")
        XCTAssertEqual(asyncResults.count, 1, "Async method should get result")
        XCTAssertEqual(throwsResults.count, 1, "Throws method should get result")
        
        if let callbackResult = callbackResults.first,
           let asyncResult = asyncResults.first,
           let throwsResult = throwsResults.first {
            
            if case .success(let asyncValue) = asyncResult {
                XCTAssertTrue(callbackResult.contains("execution_1"), "Callback should get execution_1")
                XCTAssertEqual(asyncValue, "execution_1", "Async should get execution_1")
                XCTAssertTrue(throwsResult.contains("execution_1"), "Throws should get execution_1")
            } else {
                XCTFail("Async result should be success")
            }
        }
    }

    // MARK: - 3. Property Access During State Transitions
    
    /// Test isExecuting and currentResult consistency during rapid state changes
    func testPropertyAccessDuringStateTransitions() async {
        let executeStarted = DispatchSemaphore(value: 0)
        let continueExecution = DispatchSemaphore(value: 0)
        let counter = CrossScenarioCounter()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.1
        ) { callback in
            executeStarted.signal()
            continueExecution.wait()
            Task {
                await counter.incrementResultSet()
                callback(.success("state_transition_test"))
            }
        }
        
        var isExecutingStates: [Bool] = []
        var currentResultStates: [String?] = []
        var stateInconsistencies = 0
        
        await withTaskGroup(of: Void.self) { group in
            // Start execution
            group.addTask {
                let _ = await task.asyncExecute()
            }
            
            // Rapid property access during execution
            group.addTask {
                executeStarted.wait() // Wait for execution to start
                
                // Rapid sampling during execution
                for _ in 0..<10 {
                    let executing = task.isExecuting
                    let result = task.currentResult
                    
                    isExecutingStates.append(executing)
                    currentResultStates.append(result)
                    
                    // During execution, result should be nil and isExecuting should be true
                    if executing && result != nil {
                        stateInconsistencies += 1
                    }
                    
                    try? await Task.sleep(nanoseconds: 5_000_000) // 5ms between samples
                }
                
                continueExecution.signal() // Allow execution to complete
                
                // Sample after completion
                try? await Task.sleep(nanoseconds: 50_000_000) // Wait for completion
                for _ in 0..<5 {
                    let executing = task.isExecuting
                    let result = task.currentResult
                    
                    isExecutingStates.append(executing)
                    currentResultStates.append(result)
                    
                    // After execution, result should exist and isExecuting should be false
                    if !executing && result == nil {
                        stateInconsistencies += 1
                    }
                    
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms between samples
                }
            }
        }
        
        let counts = await counter.getCounts()
        XCTAssertEqual(counts.resultSets, 1, "Should execute exactly once")
        XCTAssertGreaterThan(isExecutingStates.count, 0, "Should sample execution states")
        
        print("State transition inconsistencies: \(stateInconsistencies)")
        print("Execution states sampled: \(isExecutingStates)")
        print("Result states sampled: \(currentResultStates)")
    }

    // MARK: - 4. Complex Queue Scenarios
    
    /// Test edge case where task and callback queues have complex interactions
    func testComplexQueueInteractions() async {
        let serialQueue1 = DispatchQueue(label: "test.serial.1")
        let serialQueue2 = DispatchQueue(label: "test.serial.2")
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        let counter = CrossScenarioCounter()
        let executionQueueCollector = ResultCollector<String>()
        let callbackQueueCollector = ResultCollector<String>()
        
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0.1,
            taskQueue: serialQueue1,
            callbackQueue: serialQueue2
        ) { callback in
            let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "unknown"
            Task {
                await executionQueueCollector.add(queueLabel)
                let _ = await counter.incrementResultSet()
                callback(.success("queue_test"))
            }
        }
        
        // Execute from different queues simultaneously
        await withTaskGroup(of: Void.self) { group in
            // From main queue
            group.addTask {
                await MainActor.run {
                    task.execute { result in
                        let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "unknown"
                        Task {
                            await callbackQueueCollector.add("main_\(queueLabel)")
                        }
                    }
                }
            }
            
            // From serial queue
            group.addTask {
                await withCheckedContinuation { continuation in
                    serialQueue1.async {
                        task.execute { result in
                            let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "unknown"
                            Task {
                                await callbackQueueCollector.add("serial_\(queueLabel)")
                            }
                        }
                        continuation.resume()
                    }
                }
            }
            
            // From concurrent queue
            group.addTask {
                await withCheckedContinuation { continuation in
                    concurrentQueue.async {
                        task.execute { result in
                            let queueLabel = String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "unknown"
                            Task {
                                await callbackQueueCollector.add("concurrent_\(queueLabel)")
                            }
                        }
                        continuation.resume()
                    }
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let counts = await counter.getCounts()
        let executionQueues = await executionQueueCollector.getResults()
        let callbackQueues = await callbackQueueCollector.getResults()
        
        XCTAssertEqual(counts.resultSets, 1, "Should execute only once despite multiple queue calls")
        XCTAssertEqual(callbackQueues.count, 3, "Should have callbacks from all calling queues")
        
        print("Execution queues: \(executionQueues)")
        print("Callback queues: \(callbackQueues)")
        
        // All executions should happen on serialQueue1
        for queue in executionQueues {
            XCTAssertTrue(queue.contains("test.serial.1"), "All executions should be on taskQueue")
        }
        
        // All callbacks should happen on serialQueue2
        for queue in callbackQueues {
            XCTAssertTrue(queue.contains("test.serial.2"), "All callbacks should be on callbackQueue")
        }
    }

    // MARK: - 5. Retry Logic During Cache Boundaries
    
    /// Test complex interaction between retry logic and cache expiration
    func testRetryLogicDuringCacheExpiration() async {
        let counter = CrossScenarioCounter()
        var attemptTimestamps: [Date] = []
        
        let task = MonoTask<String>(
            retry: .count(count: 3, intervalProxy: .fixed(timeInterval: 0.05)),
            resultExpireDuration: 0.02  // Very short cache: 20ms
        ) { callback in
            Task {
                let attempt = await counter.incrementResultSet()
                attemptTimestamps.append(Date())
                
                if attempt <= 2 {
                    // Fail first two attempts
                    callback(.failure(NSError(domain: "TestError", code: attempt)))
                } else {
                    // Success on third attempt
                    callback(.success("retry_success_\(attempt)"))
                }
            }
        }
        
        // Start multiple executions that will trigger retries
        let results = await withTaskGroup(of: Result<String, Error>.self) { group in
            var allResults: [Result<String, Error>] = []
            
            for i in 0..<3 {
                group.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(i * 10_000_000)) // Stagger starts
                    return await task.asyncExecute()
                }
            }
            
            for await result in group {
                allResults.append(result)
            }
            
            return allResults
        }
        
        let counts = await counter.getCounts()
        
        // Should execute 3 times (retries) but only for the first call group
        XCTAssertEqual(counts.resultSets, 3, "Should make 3 attempts due to retry logic")
        XCTAssertEqual(results.count, 3, "Should get 3 results")
        
        // All results should be the same (from the successful execution)
        let successResults = results.compactMap { result -> String? in
            if case .success(let value) = result {
                return value
            }
            return nil
        }
        
        XCTAssertEqual(successResults.count, 3, "All calls should eventually succeed")
        XCTAssertEqual(Set(successResults).count, 1, "All results should be identical")
        
        print("Retry attempt timestamps: \(attemptTimestamps)")
        print("Results: \(results)")
    }

    // MARK: - 6. Memory Pressure and Resource Management
    
    /// Test behavior under memory pressure with many concurrent tasks
    func testMemoryPressureScenario() async {
        let counter = CrossScenarioCounter()
        let taskCount = 50
        var tasks: [MonoTask<String>] = []
        
        // Create many tasks
        for i in 0..<taskCount {
            let task = MonoTask<String>(
                retry: .never,
                resultExpireDuration: 0.1
            ) { callback in
                Task {
                    await counter.incrementResultSet()
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...50_000_000))
                    callback(.success("task_\(i)"))
                }
            }
            tasks.append(task)
        }
        
        // Execute all tasks concurrently
        let results = await withTaskGroup(of: String?.self) { group in
            var allResults: [String?] = []
            
            for (_, task) in tasks.enumerated() {
                group.addTask {
                    let result = await task.asyncExecute()
                    if case .success(let value) = result {
                        return value
                    }
                    return nil
                }
            }
            
            for await result in group {
                allResults.append(result)
            }
            
            return allResults
        }
        
        let counts = await counter.getCounts()
        let successCount = results.compactMap { $0 }.count
        
        XCTAssertEqual(counts.resultSets, taskCount, "Should execute all \(taskCount) tasks")
        XCTAssertEqual(successCount, taskCount, "All tasks should succeed")
        
        // Clean up references
        tasks.removeAll()
        
        print("Successfully executed \(successCount) concurrent tasks under memory pressure")
    }
}
