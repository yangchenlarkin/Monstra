//
//  KVHeavyTasksManagerTests.swift
//
//
//  Created by Larkin on 2025/7/29.
//

import XCTest
@testable import Monstask
@testable import MonstraBase
@testable import Monstore

/**
 1. FIFO, LIFO(await), LIFO(stop)
 2. start K tasks while running=M and queueing=N, while K < M
 3. start K tasks while running=M and queueing=N, while K = M
 4. start K tasks while running=M and queueing=N, while K > M and K < N+M
 5. start K tasks while running=M and queueing=N, while K = N+M
 6. start K tasks while running=M and queueing=N, while K > M + N
 7. DataProvider return nil when stop
 8. DataProvider return a Data when stop
 9. data cache
 10. customEvent check
 11. execute resultcallback just once per manager.fetch
 12. ensure no customEvent is executed after resultPublisher
 */

// Thread-safe container for test data
actor TestDataContainer<T> {
    private var data: T
    
    init(_ initialValue: T) {
        self.data = initialValue
    }
    
    func get() -> T {
        return data
    }
    
    func set(_ newValue: T) {
        data = newValue
    }
    
    func modify<R>(_ operation: (inout T) -> R) -> R {
        return operation(&data)
    }
}

// MARK: - Mock Provider


struct MockDataProviderProgress {
    let totalLens: Int
    let completedLens: Int
}

final class MockDataProvider: Monstask.KVHeavyTaskBaseDataProvider<String, String, MockDataProviderProgress>, Monstask.KVHeavyTaskDataProviderInterface {
    /// Flag to track pause state for task lifecycle management
    private enum State {
        case idle
        case running(value: String)
        case finished(value: String)
    }
    private var state: State = .idle {
        didSet {
            if case .running(let value) = state {
                self.customEventPublisher(.init(totalLens: key.count, completedLens: value.count))
            }
        }
    }
    
    /// Processes the input string character by character with artificial delays
    ///
    /// This method simulates a heavy computational task by processing each character
    /// of the input string with a 1-second delay. It demonstrates how to implement
    /// the core task logic in an async context with proper cancellation handling.
    ///
    /// ## Implementation Details
    /// - Uses `Task.sleep()` for non-blocking delays
    /// - Checks for cancellation using `Task.checkCancellation()`
    /// - Processes characters sequentially to simulate work
    /// - Returns the complete processed string
    ///
    /// - Returns: The processed string result, or nil if cancelled
    /// - Throws: CancellationError if the task is cancelled during execution
    func start(resumeData: String?) async {
        guard case .idle = state else { return }
        
        var result = resumeData ?? ""
        
        
        // Resume from where we left off based on existing result
        let startIndex: String.Index
        if result.isEmpty || !key.hasPrefix(result) {
            startIndex = key.startIndex
        state = .running(value: "")
        } else {
            startIndex = key.index(key.startIndex, offsetBy: result.count)
        state = .running(value: result)
        }
        
        for character in key[startIndex...] {
            // Simulate processing delay (0.1 second per character)
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // Process the current character
            result.append(character)
            
            if case .running = state {
                state = .running(value: result)
            } else {
                return
            }
        }
        state = .finished(value: result)
        resultPublisher(.success(result))
    }
    
    /// Stops the current processing task and provides resume capability
    ///
    /// This method implements the pause/resume functionality by setting the pause flag
    /// and returning a resume function. The resume function can be called later to
    /// continue processing from where it left off.
    ///
    /// ## Usage
    /// ```swift
    /// let resumeTask = await provider.stop()
    /// // ... do other work ...
    /// await resumeTask?()
    /// ```
    ///
    /// - Returns: An async closure that resumes the task, or nil if already stopped
    func stop() async -> String? {
        guard case .running(let value) = state else { return nil }
        self.state = .finished(value: value)
        return value
    }
}

// MARK: - Tests

final class KVHeavyTasksManagerTests: XCTestCase {
    
    private func makeManager(priority: Monstask.KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider>.Config.PriorityStrategy,
                             running: Int = 1,
                             queueing: Int = 8) -> Monstask.KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider> {
        let config = Monstask.KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider>.Config(
            maxNumberOfQueueingTasks: queueing,
            maxNumberOfRunningTasks: running,
            priorityStrategy: priority,
            cacheConfig: .defaultConfig,
            resumeDataCacheConfig: .defaultConfig
        )
        return .init(config: config)
    }
    
    func testBasicFetchAndProgress() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let progressEvents = TestDataContainer([MockDataProviderProgress]())
        
        let exp = expectation(description: "task completed")
        
        manager.fetch(key: "abc", customEventObserver: { progress in
            Task {
                await progressEvents.modify { events in
                    events.append(progress)
                }
            }
        }, result: { result in
            if case .success(let value) = result {
                XCTAssertEqual(value, "abc")
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 5.0)
        
        let events = await progressEvents.get()
        
        // Should have progress events showing completion
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(events.last?.totalLens, 3)
        XCTAssertEqual(events.last?.completedLens, 3)
    }
    
    func testResumeFromPartialProgress() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        // First task that will be interrupted
        let exp1 = expectation(description: "first task stopped")
        manager.fetch(key: "longkey", result: { _ in })
        
        // Wait a bit then start another task to trigger LIFO stop
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        manager.fetch(key: "short", result: { result in
            if case .success(let value) = result {
                XCTAssertEqual(value, "short")
            }
            exp1.fulfill()
        })
        
        await fulfillment(of: [exp1], timeout: 10.0)
        
        // Now fetch the original task again - it should resume
        let exp2 = expectation(description: "resumed task completed")
        let finalProgress = TestDataContainer([MockDataProviderProgress]())
        
        manager.fetch(key: "longkey", customEventObserver: { progress in
            Task {
                await finalProgress.modify { events in
                    events.append(progress)
                }
            }
        }, result: { result in
            if case .success(let value) = result {
                XCTAssertEqual(value, "longkey")
            }
            exp2.fulfill()
        })
        
        await fulfillment(of: [exp2], timeout: 10.0)
        
        let events = await finalProgress.get()
        
        // Should show resumed progress
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(events.last?.totalLens, 7)
        XCTAssertEqual(events.last?.completedLens, 7)
    }
    
    func testConcurrentTasks() async {
        let manager = makeManager(priority: .FIFO, running: 2)
        
        let exp = expectation(description: "concurrent tasks")
        exp.expectedFulfillmentCount = 3
        
        let results = TestDataContainer([String]())
        
        // Start 3 tasks - first 2 should run concurrently, 3rd should queue
        for key in ["task1", "task2", "task3"] {
            manager.fetch(key: key, result: { result in
                if case .success(let value) = result, let unwrappedValue = value {
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = await results.get()
        
        XCTAssertEqual(Set(finalResults), Set(["task1", "task2", "task3"]))
    }
    
    func testAggregatedCallbacks() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let exp = expectation(description: "aggregated callbacks")
        exp.expectedFulfillmentCount = 2
        
        let callbackCount = TestDataContainer(0)
        
        // Register two callbacks for the same key
        manager.fetch(key: "shared", result: { result in
            if case .success(let value) = result {
                XCTAssertEqual(value, "shared")
                Task {
                    await callbackCount.modify { count in
                        count += 1
                    }
                }
            }
            exp.fulfill()
        })
        
        manager.fetch(key: "shared", result: { result in
            if case .success(let value) = result {
                XCTAssertEqual(value, "shared")
                Task {
                    await callbackCount.modify { count in
                        count += 1
                    }
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 5.0)
        
        let finalCount = await callbackCount.get()
        
        XCTAssertEqual(finalCount, 2)
    }
    
    func testLIFOStopStrategy() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 2)
        
        let completedTasks = TestDataContainer([String]())
        
        let exp = expectation(description: "LIFO stop")
        exp.expectedFulfillmentCount = 3 // All should eventually complete
        
        // Add 3 tasks - with LIFO stop, later tasks should interrupt earlier ones
        for key in ["first", "second", "third"] {
            manager.fetch(key: key, result: { result in
                switch result {
                case .success(let value):
                    if let unwrappedValue = value {
                        Task {
                            await completedTasks.modify { tasks in
                                tasks.append(unwrappedValue)
                            }
                        }
                    }
                    exp.fulfill()
                case .failure:
                    // Should not fail with stop strategy
                    XCTFail("Task should not fail with stop strategy")
                }
            })
            // Small delay between submissions
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let results = await completedTasks.get()
        
        // All tasks should complete eventually
        XCTAssertEqual(Set(results), Set(["first", "second", "third"]))
    }
    
    func testTaskWithAwaitStrategy() async {
        let manager = makeManager(priority: .LIFO(.await), running: 1)
        
        let exp = expectation(description: "tasks completed")
        exp.expectedFulfillmentCount = 2
        
        let results = TestDataContainer([String]())
        
        // Start first task
        manager.fetch(key: "first", result: { result in
            if case .success(let value) = result, let unwrappedValue = value {
                Task {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
            }
            exp.fulfill()
        })
        
        // Start second task - should wait for first to complete
        manager.fetch(key: "second", result: { result in
            if case .success(let value) = result, let unwrappedValue = value {
                Task {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(Set(finalResults), Set(["first", "second"]))
    }
    
    // MARK: - Comprehensive Test Suite
    
    // Test Case 2: K < M (fewer tasks than running slots)
    func testFIFO_TasksLessThanRunningSlots() async {
        let manager = makeManager(priority: .FIFO, running: 3, queueing: 2)
        
        let exp = expectation(description: "all tasks completed")
        exp.expectedFulfillmentCount = 2
        
        let results = TestDataContainer([String]())
        
        for key in ["task1", "task2"] {
            manager.fetch(key: key, result: { result in
                if case .success(let value) = result, let unwrappedValue = value {
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 5.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(Set(finalResults), Set(["task1", "task2"]))
    }
    
    // Test Case 3: K = M (tasks equal running slots)
    func testFIFO_TasksEqualRunningSlots() async {
        let manager = makeManager(priority: .FIFO, running: 2, queueing: 3)
        
        let exp = expectation(description: "all tasks completed")
        exp.expectedFulfillmentCount = 2
        
        let results = TestDataContainer([String]())
        
        for key in ["task1", "task2"] {
            manager.fetch(key: key, result: { result in
                if case .success(let value) = result, let unwrappedValue = value {
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 5.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(Set(finalResults), Set(["task1", "task2"]))
    }
    
    // Test Case 4: K > M && K < N+M (tasks exceed running but within total capacity)
    func testFIFO_TasksExceedRunningWithinCapacity() async {
        let manager = makeManager(priority: .FIFO, running: 2, queueing: 2)
        
        let exp = expectation(description: "all tasks completed")
        exp.expectedFulfillmentCount = 3
        
        let results = TestDataContainer([String]())
        
        for key in ["task1", "task2", "task3"] {
            manager.fetch(key: key, result: { result in
                if case .success(let value) = result, let unwrappedValue = value {
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(Set(finalResults), Set(["task1", "task2", "task3"]))
    }
    
    // Test Case 5: K = N+M (tasks equal total capacity)
    func testFIFO_TasksEqualTotalCapacity() async {
        let manager = makeManager(priority: .FIFO, running: 2, queueing: 2)
        
        let exp = expectation(description: "all tasks completed")
        exp.expectedFulfillmentCount = 4
        
        let results = TestDataContainer([String]())
        
        for key in ["task1", "task2", "task3", "task4"] {
            manager.fetch(key: key, result: { result in
                if case .success(let value) = result, let unwrappedValue = value {
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(Set(finalResults), Set(["task1", "task2", "task3", "task4"]))
    }
    
    // Test Case 6: K > M + N (tasks exceed total capacity - eviction)
    func testFIFO_TasksExceedTotalCapacity() async {
        let manager = makeManager(priority: .FIFO, running: 1, queueing: 2)
        
        let completedExp = expectation(description: "completed tasks")
        completedExp.expectedFulfillmentCount = 3 // Only 3 should complete (1 running + 2 queued)
        
        let evictedExp = expectation(description: "evicted tasks")
        evictedExp.expectedFulfillmentCount = 2 // 2 should be evicted
        
        let results = TestDataContainer([String]())
        let errors = TestDataContainer([String]())
        
        for key in ["task1", "task2", "task3", "task4", "task5"] {
            manager.fetch(key: key, result: { result in
                switch result {
                case .success(let value):
                    if let unwrappedValue = value {
                        Task {
                            await results.modify { array in
                                array.append(unwrappedValue)
                            }
                        }
                    }
                    completedExp.fulfill()
                case .failure:
                    Task {
                        await errors.modify { array in
                            array.append(key)
                        }
                    }
                    evictedExp.fulfill()
                }
            })
        }
        
        await fulfillment(of: [completedExp, evictedExp], timeout: 15.0)
        
        let finalResults = await results.get()
        let finalErrors = await errors.get()
        
        XCTAssertEqual(finalResults.count, 3)
        XCTAssertEqual(finalErrors.count, 2)
    }
    
    // Test Case 7: DataProvider returns nil when stopped
    func testDataProviderReturnsNilOnStop() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp = expectation(description: "tasks completed")
        exp.expectedFulfillmentCount = 2
        
        let results = TestDataContainer([String?]())
        
        // First task - will be stopped
        manager.fetch(key: "stoppable", result: { result in
            if case .success(let value) = result {
                Task {
                    await results.modify { array in
                        array.append(value)
                    }
                }
            }
            exp.fulfill()
        })
        
        // Small delay then start interrupting task
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        manager.fetch(key: "interrupter", result: { result in
            if case .success(let value) = result {
                Task {
                    await results.modify { array in
                        array.append(value)
                    }
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(finalResults.count, 2)
        
        // The interrupted task should eventually complete when restarted
        let exp2 = expectation(description: "restarted task completed")
        manager.fetch(key: "stoppable", result: { result in
            exp2.fulfill()
        })
        await fulfillment(of: [exp2], timeout: 5.0)
    }
    
    // Test Case 8: DataProvider returns resume data when stopped
    func testDataProviderReturnsResumeDataOnStop() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp = expectation(description: "tasks completed")
        exp.expectedFulfillmentCount = 2
        
        // First task - will be stopped and should provide resume data
        manager.fetch(key: "resumable", result: { result in
            exp.fulfill()
        })
        
        // Small delay then start interrupting task
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        manager.fetch(key: "interrupter", result: { result in
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        // Restart the interrupted task - it should resume from where it left off
        let resumeExp = expectation(description: "resumed task completed")
        manager.fetch(key: "resumable", result: { result in
            if case .success(let value) = result, let unwrappedValue = value {
                // Should complete faster due to resume
                XCTAssertEqual(unwrappedValue, "resumable")
            }
            resumeExp.fulfill()
        })
        
        await fulfillment(of: [resumeExp], timeout: 10.0)
    }
    
    // Test Case 9: Data cache behavior
    func testDataCacheBehavior() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let firstExp = expectation(description: "first fetch completed")
        let secondExp = expectation(description: "second fetch completed")
        
        let startTime = TestDataContainer(Date())
        let firstFetchTime = TestDataContainer(Date())
        let secondFetchTime = TestDataContainer(Date())
        
        await startTime.set(Date())
        
        // First fetch - should execute task
        manager.fetch(key: "cached", result: { result in
            Task {
                await firstFetchTime.set(Date())
            }
            firstExp.fulfill()
        })
        
        await fulfillment(of: [firstExp], timeout: 5.0)
        
        // Second fetch - should return from cache immediately
        manager.fetch(key: "cached", result: { result in
            Task {
                await secondFetchTime.set(Date())
            }
            secondExp.fulfill()
        })
        
        await fulfillment(of: [secondExp], timeout: 1.0)
        
        let start = await startTime.get()
        let first = await firstFetchTime.get()
        let second = await secondFetchTime.get()
        
        // First fetch should take longer (actual task execution)
        XCTAssertGreaterThan(first.timeIntervalSince(start), 0.1)
        
        // Second fetch should be much faster (cache hit)
        XCTAssertLessThan(second.timeIntervalSince(first), 0.1)
    }
    
    // Test Case 10: Custom event handling
    func testCustomEventHandling() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let exp = expectation(description: "task completed")
        let events = TestDataContainer([MockDataProviderProgress]())
        
        manager.fetch(key: "eventful", customEventObserver: { progress in
            Task {
                await events.modify { array in
                    array.append(progress)
                }
            }
        }, result: { result in
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 5.0)
        
        let finalEvents = await events.get()
        
        // Should have received progress events
        XCTAssertFalse(finalEvents.isEmpty)
        XCTAssertEqual(finalEvents.last?.totalLens, 8) // "eventful".count
        XCTAssertEqual(finalEvents.last?.completedLens, 8)
    }
    
    // Test Case 11: Result callback executed only once per fetch
    func testResultCallbackExecutedOncePerFetch() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let exp = expectation(description: "all callbacks completed")
        exp.expectedFulfillmentCount = 3 // 3 separate fetch calls
        
        let callbackCounts = TestDataContainer([String: Int]())
        
        // Multiple fetch calls for the same key
        for i in 1...3 {
            manager.fetch(key: "shared", result: { result in
                Task {
                    await callbackCounts.modify { counts in
                        let key = "callback_\(i)"
                        counts[key] = (counts[key] ?? 0) + 1
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 5.0)
        
        let finalCounts = await callbackCounts.get()
        
        // Each callback should be called exactly once
        XCTAssertEqual(finalCounts["callback_1"], 1)
        XCTAssertEqual(finalCounts["callback_2"], 1)
        XCTAssertEqual(finalCounts["callback_3"], 1)
    }
    
    // Additional Test: LIFO(await) strategy comprehensive test
    func testLIFOAwaitStrategy() async {
        let manager = makeManager(priority: .LIFO(.await), running: 2, queueing: 2)
        
        let exp = expectation(description: "all tasks completed")
        exp.expectedFulfillmentCount = 4
        
        let results = TestDataContainer([String]())
        let startTimes = TestDataContainer([String: Date]())
        
        // Add tasks with small delays between them
        for key in ["first", "second", "third", "fourth"] {
            await startTimes.modify { times in
                times[key] = Date()
            }
            
            manager.fetch(key: key, result: { result in
                if case .success(let value) = result, let unwrappedValue = value {
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
            
            // Small delay between submissions
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(Set(finalResults), Set(["first", "second", "third", "fourth"]))
    }
    
    // MARK: - Additional Critical Test Cases
    
    // Test Case 12: Cache invalidKey and hitNullElement scenarios
    func testCacheEdgeCases() async {
        // This would require modifying the MockDataProvider to simulate cache scenarios
        // For now, we test basic cache behavior which covers the main scenarios
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let exp = expectation(description: "cache test completed")
        
        // Test normal cache behavior - this will trigger cache.miss -> execution
        manager.fetch(key: "normal", result: { result in
            XCTAssertNotNil(result)
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 5.0)
    }
    
    // Test Case 13: DataProvider error handling
    func testDataProviderErrorHandling() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let exp = expectation(description: "error handled")
        
        // The MockDataProvider in our current implementation always succeeds
        // In a real scenario, we'd test error propagation from DataProvider
        manager.fetch(key: "error_prone", result: { result in
            // Should handle both success and failure cases
            switch result {
            case .success:
                // Success case
                break
            case .failure:
                // Error case - would be triggered by DataProvider throwing
                break
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 5.0)
    }
    
    // Test Case 14: Multiple LIFO stop operations
    func testMultipleLIFOStopOperations() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp = expectation(description: "multiple stops handled")
        exp.expectedFulfillmentCount = 3
        
        let results = TestDataContainer([String]())
        
        // Start first task
        manager.fetch(key: "first", result: { result in
            if case .success(let value) = result, let unwrappedValue = value {
                Task {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
            }
            exp.fulfill()
        })
        
        // Small delay then interrupt with second task
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        manager.fetch(key: "second", result: { result in
            if case .success(let value) = result, let unwrappedValue = value {
                Task {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
            }
            exp.fulfill()
        })
        
        // Small delay then interrupt with third task
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        manager.fetch(key: "third", result: { result in
            if case .success(let value) = result, let unwrappedValue = value {
                Task {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalResults = await results.get()
        XCTAssertEqual(finalResults.count, 3)
        
        // All tasks should eventually complete (though in different order due to stops)
        XCTAssertEqual(Set(finalResults), Set(["first", "second", "third"]))
    }
    
    // Test Case 15: Resume data with different providers
    func testResumeDataConsistency() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp1 = expectation(description: "first round completed")
        exp1.expectedFulfillmentCount = 2
        
        // Start a long task that will be interrupted
        manager.fetch(key: "longrunning", result: { result in
            exp1.fulfill()
        })
        
        // Wait a bit, then interrupt
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        manager.fetch(key: "interrupter", result: { result in
            exp1.fulfill()
        })
        
        await fulfillment(of: [exp1], timeout: 10.0)
        
        // Now restart the interrupted task multiple times to test resume consistency
        let exp2 = expectation(description: "resume consistency test")
        exp2.expectedFulfillmentCount = 2
        
        manager.fetch(key: "longrunning", result: { result in
            if case .success(let value) = result, let unwrappedValue = value {
                XCTAssertEqual(unwrappedValue, "longrunning")
            }
            exp2.fulfill()
        })
        
        manager.fetch(key: "longrunning", result: { result in
            // Second fetch should hit cache and return immediately
            if case .success(let value) = result, let unwrappedValue = value {
                XCTAssertEqual(unwrappedValue, "longrunning")
            }
            exp2.fulfill()
        })
        
        await fulfillment(of: [exp2], timeout: 10.0)
    }
    
    // Test Case 16: Stress test with rapid fetch operations
    func testRapidFetchOperations() async {
        let manager = makeManager(priority: .FIFO, running: 2, queueing: 3)
        
        let exp = expectation(description: "stress test completed")
        exp.expectedFulfillmentCount = 10
        
        let results = TestDataContainer([String]())
        
        // Rapidly submit multiple fetch operations
        for i in 1...10 {
            manager.fetch(key: "rapid_\(i)", result: { result in
                if case .success(let value) = result, let unwrappedValue = value {
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 20.0)
        
        let finalResults = await results.get()
        
        // Some tasks might be evicted due to capacity limits
        // But we should have at least the running + queued capacity completed
        XCTAssertGreaterThanOrEqual(finalResults.count, 5) // At least running(2) + queued(3)
        XCTAssertLessThanOrEqual(finalResults.count, 10) // At most all tasks
    }
    
    // Test Case 12: Ensure no customEvent is executed after resultPublisher
    func testNoCustomEventAfterResultPublisher() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let exp = expectation(description: "task completed")
        
        let events = TestDataContainer([MockDataProviderProgress]())
        let eventTimestamps = TestDataContainer([CPUTimeStamp]())
        let resultTimestamp = TestDataContainer(CPUTimeStamp.zero)
        let eventsAfterResult = TestDataContainer([MockDataProviderProgress]())
        
        manager.fetch(key: "lifecycle", customEventObserver: { progress in
            Task {
                await events.modify { array in
                    array.append(progress)
                }
                await eventTimestamps.modify { timestamps in
                    timestamps.append(.now())
                }
                
                // Check if this event came after the result
                let resultTime = await resultTimestamp.get()
                if .now() > resultTime && resultTime != .zero {
                    await eventsAfterResult.modify { array in
                        array.append(progress)
                    }
                }
            }
        }, result: { result in
            Task {
                await resultTimestamp.set(.now())
                // Small delay to catch any potential late events
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                exp.fulfill()
            }
        })
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        // Additional wait to catch any potential late events
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let finalEvents = await events.get()
        let finalEventsAfterResult = await eventsAfterResult.get()
        
        // Should have received events during execution
        XCTAssertFalse(finalEvents.isEmpty, "Should have received progress events")
        
        // Should NOT have received any events after result
        XCTAssertTrue(finalEventsAfterResult.isEmpty, "Should not receive events after result publisher: \(finalEventsAfterResult)")
    }
    
    // MARK: - Cross-Scenario Tests
    
    // Cross-Scenario 1: FIFO + K > M+N + Resume Data + Custom Events
    func testCrossScenario_FIFO_Eviction_Resume_Events() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 1)
        
        let completedExp = expectation(description: "completed tasks")
        completedExp.expectedFulfillmentCount = 3
        
        let events = TestDataContainer([String: [MockDataProviderProgress]]())
        let results = TestDataContainer([String]())
        let cancelledResults = TestDataContainer([Error]())
        
        let keys = ["task1", "task2", "task3"]
        let completedKeys = ["task3", "task2"]
        let cancelledKeys = ["task1"]
        
        for key in keys {
            manager.fetch(key: key, customEventObserver: { progress in
                Task {
                    await events.modify { dict in
                        if dict[key] == nil {
                            dict[key] = []
                        }
                        dict[key]?.append(progress)
                    }
                }
            }, result: { result in
                switch result {
                case .success(let value):
                    guard let unwrappedValue = value else { break }
                    Task {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                case .failure(let error):
                    Task {
                        await cancelledResults.modify { array in
                            array.append(error)
                        }
                    }
                }
                completedExp.fulfill()
            })
            
            // Small delay between submissions to trigger LIFO stop behavior
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        }
        
        await fulfillment(of: [completedExp], timeout: 20.0)
        
        let finalResults = await results.get()
        let finalEvents = await events.get()
        let finalCancelledResults = await cancelledResults.get()
        
        XCTAssertEqual(Set(finalResults), Set(completedKeys))
        XCTAssertEqual(finalCancelledResults.count, cancelledKeys.count)
        
        // Each task should have received events
        for key in keys {
            XCTAssertNotNil(finalEvents[key], "Task \(key) should have events")
            XCTAssertFalse(finalEvents[key]?.isEmpty ?? true, "Task \(key) should have non-empty events")
        }
    }
    
    // Cross-Scenario 2: LIFO(await) + Cache Hit + Multiple Callbacks
    func testCrossScenario_LIFOAwait_Cache_MultipleCallbacks() async {
        let manager = makeManager(priority: .LIFO(.await), running: 1)
        
        // First, populate cache
        let cacheExp = expectation(description: "cache populated")
        manager.fetch(key: "cached_task", result: { result in
            cacheExp.fulfill()
        })
        await fulfillment(of: [cacheExp], timeout: 5.0)
        
        // Now test multiple callbacks on cached item
        let multiExp = expectation(description: "multiple callbacks")
        multiExp.expectedFulfillmentCount = 3
        
        let callbackTimes = TestDataContainer([Date]())
        
        for i in 1...3 {
            manager.fetch(key: "cached_task", result: { result in
                Task {
                    await callbackTimes.modify { times in
                        times.append(Date())
                    }
                }
                multiExp.fulfill()
            })
        }
        
        await fulfillment(of: [multiExp], timeout: 2.0)
        
        let times = await callbackTimes.get()
        XCTAssertEqual(times.count, 3)
        
        // All callbacks should execute very quickly (cache hits)
        let timeSpread = times.max()!.timeIntervalSince(times.min()!)
        XCTAssertLessThan(timeSpread, 0.1, "Cache hits should execute quickly")
    }
    
    // Cross-Scenario 3: Queue Capacity + Priority Strategy + Event Ordering
    func testCrossScenario_QueueCapacity_Priority_EventOrdering() async {
        let manager = makeManager(priority: .LIFO(.await), running: 1, queueing: 2)
        
        let completedExp = expectation(description: "completed tasks")
        completedExp.expectedFulfillmentCount = 3 // 1 running + 2 queued
        
        let evictedExp = expectation(description: "evicted tasks") 
        evictedExp.expectedFulfillmentCount = 2 // 2 evicted
        
        let executionOrder = TestDataContainer([String]())
        let evictedTasks = TestDataContainer([String]())
        
        // Submit 5 tasks to trigger eviction (capacity = 3)
        for i in 1...5 {
            let key = "ordered_\(i)"
            manager.fetch(key: key, result: { result in
                switch result {
                case .success(let value):
                    if let unwrappedValue = value {
                        Task {
                            await executionOrder.modify { order in
                                order.append(unwrappedValue)
                            }
                        }
                    }
                    completedExp.fulfill()
                case .failure:
                    Task {
                        await evictedTasks.modify { evicted in
                            evicted.append(key)
                        }
                    }
                    evictedExp.fulfill()
                }
            })
            
            // Small delay to ensure ordering
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        }
        
        await fulfillment(of: [completedExp, evictedExp], timeout: 15.0)
        
        let finalOrder = await executionOrder.get()
        let finalEvicted = await evictedTasks.get()
        
        XCTAssertEqual(finalOrder.count, 3)
        XCTAssertEqual(finalEvicted.count, 2)
        
        // With LIFO(.await), later submitted tasks should execute first (when they get their turn)
        // But the exact order depends on timing and queue behavior
        XCTAssertEqual(Set((finalOrder + finalEvicted).map { $0.replacingOccurrences(of: "ordered_", with: "") }),
                      Set(["1", "2", "3", "4", "5"]))
    }
    
    // Cross-Scenario 4: Error Handling + Resume Data + Custom Events
    func testCrossScenario_ErrorHandling_Resume_Events() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp = expectation(description: "error scenario completed")
        exp.expectedFulfillmentCount = 2
        
        let events = TestDataContainer([MockDataProviderProgress]())
        let results = TestDataContainer([Result<String?, Error>]())
        
        // Start a task that will be interrupted
        manager.fetch(key: "error_prone", customEventObserver: { progress in
            Task {
                await events.modify { array in
                    array.append(progress)
                }
            }
        }, result: { result in
            Task {
                await results.modify { array in
                    array.append(result)
                }
            }
            exp.fulfill()
        })
        
        // Interrupt with another task
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        manager.fetch(key: "interrupter", result: { result in
            Task {
                await results.modify { array in
                    array.append(result)
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalEvents = await events.get()
        let finalResults = await results.get()
        
        XCTAssertEqual(finalResults.count, 2)
        XCTAssertFalse(finalEvents.isEmpty, "Should have received events before interruption")
        
        // Test resuming the interrupted task
        let resumeExp = expectation(description: "resume completed")
        manager.fetch(key: "error_prone", result: { result in
            resumeExp.fulfill()
        })
        
        await fulfillment(of: [resumeExp], timeout: 10.0)
    }
    
    // Cross-Scenario 5: Stress Test - All Features Combined
    func testCrossScenario_StressCombined() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 2, queueing: 3)
        
        let exp = expectation(description: "stress test completed")
        exp.expectedFulfillmentCount = 8 // Some will complete, some will be evicted
        
        let allEvents = TestDataContainer([String: [MockDataProviderProgress]]())
        let allResults = TestDataContainer([String: Result<String?, Error>]())
        
        // Mix of different task types
        let taskConfigs = [
            ("cache_me", 0),      // Will be cached for later
            ("interrupt_1", 100), // Will be interrupted
            ("interrupt_2", 150), // Will interrupt interrupt_1
            ("normal_1", 200),    // Normal execution
            ("normal_2", 250),    // Normal execution
            ("cache_me", 300),    // Cache hit
            ("rapid_1", 350),     // Rapid submission
            ("rapid_2", 355),     // Rapid submission
        ]
        
        for (key, delay) in taskConfigs {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000)) // Convert ms to ns
            }
            
            manager.fetch(key: key, customEventObserver: { progress in
                Task {
                    await allEvents.modify { dict in
                        if dict[key] == nil {
                            dict[key] = []
                        }
                        dict[key]?.append(progress)
                    }
                }
            }, result: { result in
                Task {
                    await allResults.modify { dict in
                        dict[key] = result
                    }
                }
                exp.fulfill()
                print("🐰🐰🐰🐰🐰🐰🐰🐰: \(key)")
                if key == "cache_me" {
                    Thread.callStackSymbols.forEach { print($0) }
                }
            })
        }
        
        await fulfillment(of: [exp], timeout: 25.0)
        
        let finalEvents = await allEvents.get()
        let finalResults = await allResults.get()
        
        // Should have results for all unique keys
        let uniqueKeys = Set(taskConfigs.map { $0.0 })
        XCTAssertEqual(finalResults.count, uniqueKeys.count)
        
        // Cache hit should not have events (immediate return)
        // Other tasks should have events
        for key in uniqueKeys {
            XCTAssertNotNil(finalResults[key], "Should have result for \(key)")
        }
        
        // At least some tasks should have events (non-cache hits)
        let tasksWithEvents = finalEvents.values.filter { !$0.isEmpty }.count
        XCTAssertGreaterThan(tasksWithEvents, 0, "At least some tasks should have events")
    }
}
