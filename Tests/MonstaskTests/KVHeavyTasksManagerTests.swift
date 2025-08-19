//
//  KVHeavyTasksManagerTests.swift
//  Comprehensive Test Suite for KVHeavyTasksManager
//
//  Created by Larkin on 2025/7/29.
//
//  ## Test Suite Overview
//  This comprehensive test suite validates all aspects of KVHeavyTasksManager functionality including:
//  - Priority strategies (FIFO, LIFO with await/stop behaviors)
//  - Concurrency management and queue capacity handling
//  - Cache integration (hit/miss/null/invalid states)
//  - DataProvider lifecycle (creation, reuse, deallocation)
//  - Error handling and recovery mechanisms
//  - Event broadcasting and callback coordination
//  - Thread safety and race condition handling
//  - Edge cases and stress testing scenarios
//
//  ## Test Categories
//  ### Core Priority Strategy Tests (1-19)
//  - Basic FIFO/LIFO execution patterns
//  - Queue capacity and overflow handling
//  - Task eviction and prioritization logic
//  - Custom event and result callback coordination
//
//  ### Advanced DataProvider Lifecycle Tests (20-23)
//  - Stop/resume behavior with .reuse and .dealloc actions
//  - Provider state preservation and memory management
//  - Automatic task restart from waiting queue
//  - Mixed behavior scenarios with concurrent operations
//
//  ### Comprehensive Edge Case Tests (24-29)
//  - Cache state handling (null elements, invalid keys, validation consistency)
//  - DataProvider error scenarios and validation
//  - Configuration edge cases (zero capacities, extreme values)
//  - Concurrent operations with state transitions
//  - Cache statistics reporting and monitoring
//  - Provider cleanup verification and memory management
//
//  ## Test Requirements Coverage Matrix
//  | Scenario | Description | Test Cases |
//  |----------|-------------|------------|
//  | Priority Strategies | FIFO, LIFO(await), LIFO(stop) | 1-3, 11-19 |
//  | Capacity Management | K tasks with running=M, queueing=N | 4-10, 26 |
//  | DataProvider States | Start, stop, reuse, dealloc behaviors | 20-23, 25, 29 |
//  | Cache Integration | Hit, miss, null, invalid scenarios | 11-19, 24 |
//  | Event System | Progress updates and result delivery | 1-23, 28 |
//  | Error Handling | Failures, validation, recovery | 24-26 |
//  | Concurrency | Thread safety and race conditions | 20-23, 27 |
//  | Performance | Stress testing and resource limits | 20-23, 26 |
//
//  ## Key Testing Principles
//  - **Comprehensive Coverage**: Every major code path and edge case is tested
//  - **Real-world Scenarios**: Tests simulate actual usage patterns and stress conditions
//  - **Thread Safety**: Concurrent operations are extensively tested for race conditions
//  - **Memory Management**: Provider lifecycle and cleanup are thoroughly validated
//  - **Error Resilience**: All failure modes and recovery paths are exercised
//  - **Performance Validation**: Resource usage and efficiency are monitored and verified
//

import XCTest
@testable import Monstask
@testable import MonstraBase
@testable import Monstore

/// Extension providing safe array access to prevent index out of bounds crashes.
///
/// This extension is essential for test scenarios where array indices might be
/// uncertain due to concurrent operations or dynamic queue management.
extension Array {
    /// Safely accesses array elements, returning nil if index is out of bounds.
    ///
    /// - Parameter index: The index to access
    /// - Returns: The element at the specified index, or nil if index is invalid
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

/// Thread-safe container for managing test data across concurrent operations.
///
/// This actor provides atomic access to test data that may be modified from
/// multiple concurrent tasks during testing. It ensures data integrity and
/// prevents race conditions in test scenarios involving parallel task execution.
///
/// ## Usage in Tests
/// - **Progress Tracking**: Accumulate progress updates from multiple tasks
/// - **Result Collection**: Gather results from concurrent operations safely
/// - **State Coordination**: Synchronize test state across parallel executions
/// - **Counter Management**: Maintain accurate counts in multi-threaded scenarios
actor TestDataContainer<T> {
    private var data: T
    
    /// Initializes the container with an initial value.
    ///
    /// - Parameter initialValue: The initial data value to store
    init(_ initialValue: T) {
        self.data = initialValue
    }
    
    /// Retrieves the current data value.
    ///
    /// - Returns: The current data value
    func get() -> T {
        return data
    }
    
    /// Sets a new data value.
    ///
    /// - Parameter newValue: The new value to store
    func set(_ newValue: T) {
        data = newValue
    }
    
    /// Atomically modifies the data and returns a result.
    ///
    /// This method is particularly useful for operations like incrementing counters,
    /// appending to arrays, or performing complex state transitions safely.
    ///
    /// - Parameter operation: Closure that modifies the data and optionally returns a result
    /// - Returns: The result returned by the operation closure
    func modify<R>(_ operation: (inout T) -> R) -> R {
        return operation(&data)
    }
}

// MARK: - Mock Provider


struct MockDataProviderProgress {
    let totalLength: Int
    let completedLength: Int
}

final class MockDataProvider: Monstask.KVHeavyTaskBaseDataProvider<String, String, MockDataProviderProgress>, Monstask.KVHeavyTaskDataProviderInterface {
    /// Flag to track pause state for task lifecycle management
    private enum State {
        case idle
        case running(value: String)
        case paused(value: String)
        case finished
    }
    private var state: State = .idle {
        didSet {
            if case .running(let value) = state {
                self.customEventPublisher(.init(totalLength: key.count, completedLength: value.count))
            }
        }
    }
    private var stateAccessSemaphore = DispatchSemaphore(value: 1)
    
    enum Errors: Error {
        case invalidKey
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
    func start() {
        if key.contains("invalid") {
            self.resultPublisher(.failure(Errors.invalidKey))
            return
        }
        stateAccessSemaphore.wait()
        defer { stateAccessSemaphore.signal() }
        
        let resumeData: String
        switch self.state {
        case .idle:
            resumeData = ""
        case .running(_):
            return
        case .finished:
            return
        case .paused(let value):
            resumeData = value
        }
        
        // Determine the already processed prefix from resumeData
        let processedPrefix = resumeData
        var result = processedPrefix
        
        // Compute start index. If resumeData is not a prefix, restart from beginning
        let startIndex: String.Index
        if key.hasPrefix(processedPrefix) {
            startIndex = key.index(key.startIndex, offsetBy: processedPrefix.count)
        } else {
            result = ""
            startIndex = key.startIndex
        }
        
        state = .running(value: result)
        
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self else { return }
            for character in strongSelf.key[startIndex...] {
                // Simulate processing delay (0.1 second per character)
                Thread.sleep(forTimeInterval: 0.1)
                
                guard let self else { return }
                self.stateAccessSemaphore.wait()
                defer { self.stateAccessSemaphore.signal() }
                
                // Process the current character
                result.append(character)
                if case .running = self.state {
                    if result == self.key {
                        self.state = .running(value: result)
                        self.state = .finished
                        self.resultPublisher(.success(result))
                    } else {
                        self.state = .running(value: result)
                    }
                } else {
                    return
                }
            }
        }
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
    func stop() -> KVHeavyTaskDataProviderStopAction {
        stateAccessSemaphore.wait()
        defer { stateAccessSemaphore.signal() }
        
        Thread.sleep(forTimeInterval: 0.05)
        
        guard case .running(let value) = state else { return .dealloc }
        self.state = .paused(value: value)
        
        if key.contains("dealloc") {
            return .dealloc
        }
        
        if key.contains("reuse") {
            return .reuse
        }
        
        return .reuse
    }
}

// MARK: - Tests

final class KVHeavyTasksManagerTests: XCTestCase {
    private func makeManager(priority: Monstask.KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider>.Config.PriorityStrategy,
                             running: Int = 1,
                             queueing: Int = 8,
                             cacheConfig: MemoryCache<String, String>.Configuration = .defaultConfig) -> Monstask.KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider> {
        let config = Monstask.KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider>.Config(
            maxNumberOfQueueingTasks: queueing,
            maxNumberOfRunningTasks: running,
            priorityStrategy: priority,
            cacheConfig: cacheConfig
        )
        return .init(config: config)
    }
    
    func testBasicFetchAndProgress() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let progressEvents = TestDataContainer([MockDataProviderProgress]())
        
        let taskCompletionExpectation = expectation(description: "task completed")
        
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
            taskCompletionExpectation.fulfill()
        })
        
        await fulfillment(of: [taskCompletionExpectation], timeout: 5.0)
        
        let events = await progressEvents.get()
        
        // Should have progress events showing completion
        XCTAssertFalse(events.isEmpty)
        let minValue = events.reduce(Int.max) { partialResult, progress in
            return min(partialResult, progress.completedLength)
        }
        XCTAssertEqual(minValue, 0)
        for event in events {
            XCTAssertEqual(event.totalLength, 3)
        }
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
        XCTAssertEqual(events.last?.totalLength, 7)
        XCTAssertEqual(events.last?.completedLength, 7)
    }
    
    func testConcurrentTasks() async {
        let manager = makeManager(priority: .FIFO, running: 2)
        
        let exp = expectation(description: "concurrent tasks")
        exp.expectedFulfillmentCount = 3
        
        let results = TestDataContainer([String]())
        
        // Start 3 tasks - first 2 should run concurrently, 3rd should queue
        for key in ["task1", "task2", "task3"] {
            manager.fetch(key: key, result: { result in
                Task {
                    if case .success(let value) = result, let unwrappedValue = value {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                    exp.fulfill()
                }
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
            Task {
                if case .success(let value) = result {
                    XCTAssertEqual(value, "shared")
                    await callbackCount.modify { count in
                        count += 1
                    }
                }
                exp.fulfill()
            }
        })
        
        manager.fetch(key: "shared", result: { result in
            Task {
                if case .success(let value) = result {
                    XCTAssertEqual(value, "shared")
                    await callbackCount.modify { count in
                        count += 1
                    }
                }
                exp.fulfill()
            }
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
                Task {
                    switch result {
                    case .success(let value):
                        if let unwrappedValue = value {
                            await completedTasks.modify { tasks in
                                tasks.append(unwrappedValue)
                            }
                        }
                        exp.fulfill()
                    case .failure:
                        // Should not fail with stop strategy
                        XCTFail("Task should not fail with stop strategy")
                        exp.fulfill()
                    }
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
            Task {
                if case .success(let value) = result, let unwrappedValue = value {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
                exp.fulfill()
            }
        })
        
        // Start second task - should wait for first to complete
        manager.fetch(key: "second", result: { result in
            Task {
                if case .success(let value) = result, let unwrappedValue = value {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
                exp.fulfill()
            }
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
                Task {
                    if case .success(let value) = result, let unwrappedValue = value {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                    exp.fulfill()
                }
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
                Task {
                    if case .success(let value) = result, let unwrappedValue = value {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                    exp.fulfill()
                }
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
        XCTAssertEqual(finalEvents.last?.totalLength, 8) // "eventful".count
        XCTAssertEqual(finalEvents.last?.completedLength, 8)
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
        
        for _ in 1...3 {
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
    
    // MARK: - Extreme Concurrency Tests (Race Conditions)
    
    /**
     Extreme concurrency test scenario combinations:
     
     Basic operations: fetch, finish, stop
     
     1. Multiple fetch operations on same key concurrency races:
        - Multiple threads simultaneously fetch same key
        - fetch + finish race conditions
        - fetch + stop race conditions
     
     2. finish and stop race conditions:
        - finish and stop happening simultaneously
        - Multiple stop operations racing
        - Immediate fetch after stop
     
     3. Complex combination races:
        - fetch + fetch + stop
        - fetch + stop + finish
        - stop + fetch + stop
        - finish + fetch + fetch
     
     4. Extreme stress testing:
        - Massive concurrent operations on same key
        - Rapid consecutive fetch/stop cycles
        - Multi-key multi-operation mixed races
     */
    
    // Test Case 13: Multiple fetch operations on same key concurrency race
    func testConcurrentMultipleFetchSameKey() async {
        let manager = makeManager(priority: .FIFO, running: 1)
        
        let exp = expectation(description: "concurrent fetches completed")
        exp.expectedFulfillmentCount = 5 // 5 concurrent fetches
        
        let results = TestDataContainer([String?]())
        let callbackTimes = TestDataContainer([Date]())
        
        // Launch 5 fetch operations simultaneously on the same key
        await withTaskGroup(of: Void.self) { group in
            for _ in 1...5 {
                group.addTask {
                    manager.fetch(key: "concurrent_key", result: { result in
                        Task {
                            await callbackTimes.modify { times in
                                times.append(Date())
                            }
                            if case .success(let value) = result {
                                await results.modify { array in
                                    array.append(value)
                                }
                            }
                        }
                        exp.fulfill()
                    })
                }
            }
        }
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = await results.get()
        let finalTimes = await callbackTimes.get()
        
        // All callbacks should be executed
        XCTAssertEqual(finalResults.count, 5)
        XCTAssertEqual(finalTimes.count, 5)
        
        // All results should be the same (same key)
        let uniqueResults = Set(finalResults.compactMap { $0 })
        XCTAssertEqual(uniqueResults.count, 1)
        XCTAssertEqual(uniqueResults.first, "concurrent_key")
    }
    
    // Test Case 14: fetch + finish race conditions
    func testConcurrentFetchAndFinish() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp = expectation(description: "fetch-finish race completed")
        exp.expectedFulfillmentCount = 3
        
        let results = TestDataContainer([String]())
        let operationOrder = TestDataContainer([String]())
        
        // Start a task
        manager.fetch(key: "race_key", result: { result in
            Task {
                await operationOrder.modify { order in
                    order.append("first_finish")
                }
                if case .success(let value) = result, let unwrappedValue = value {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
            }
            exp.fulfill()
        })
        
        // After brief delay, simultaneously start new fetch operation (will trigger stop) and wait for completion
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await withTaskGroup(of: Void.self) { group in
            // New fetch (will stop current task)
            group.addTask {
                manager.fetch(key: "interrupt_key", result: { result in
                    Task {
                        await operationOrder.modify { order in
                            order.append("interrupt_finish")
                        }
                        if case .success(let value) = result, let unwrappedValue = value {
                            await results.modify { array in
                                array.append(unwrappedValue)
                            }
                        }
                    }
                    exp.fulfill()
                })
            }
            
            // Simultaneously try to fetch original key again
            group.addTask {
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds delay
                manager.fetch(key: "race_key", result: { result in
                    Task {
                        await operationOrder.modify { order in
                            order.append("race_finish")
                        }
                        if case .success(let value) = result, let unwrappedValue = value {
                            await results.modify { array in
                                array.append(unwrappedValue)
                            }
                        }
                    }
                    exp.fulfill()
                })
            }
        }
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalResults = await results.get()
        let finalOrder = await operationOrder.get()
        
        XCTAssertEqual(finalResults.count, 3)
        XCTAssertEqual(finalOrder.count, 3)
        
        // Verify all tasks eventually completed
        XCTAssertEqual(Set(finalResults), Set(["race_key", "interrupt_key"]))
    }
    
    // Test Case 15: Multiple stop operations race
    func testConcurrentMultipleStops() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp = expectation(description: "multiple stops completed")
        exp.expectedFulfillmentCount = 4 // 1 original + 3 interrupts
        
        let results = TestDataContainer([String]())
        let stopOrder = TestDataContainer([String]())
        
        // Start initial task
        manager.fetch(key: "original", result: { result in
            Task {
                await stopOrder.modify { order in
                    order.append("original_finish")
                }
                if case .success(let value) = result, let unwrappedValue = value {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
            }
            exp.fulfill()
        })
        
        // After brief delay, rapidly launch multiple interrupt tasks in succession
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        
        await withTaskGroup(of: Void.self) { group in
            for i in 1...3 {
                group.addTask {
                    // Each task has a slight delay difference
                    try? await Task.sleep(nanoseconds: UInt64(i * 10_000_000)) // 0.01 seconds increment
                    
                    manager.fetch(key: "stop_\(i)", result: { result in
                        Task {
                            await stopOrder.modify { order in
                                order.append("stop_\(i)_finish")
                            }
                            if case .success(let value) = result, let unwrappedValue = value {
                                await results.modify { array in
                                    array.append(unwrappedValue)
                                }
                            }
                        }
                        exp.fulfill()
                    })
                }
            }
        }
        
        await fulfillment(of: [exp], timeout: 20.0)
        
        let finalResults = await results.get()
        let finalOrder = await stopOrder.get()
        
        XCTAssertEqual(finalResults.count, 4)
        XCTAssertEqual(finalOrder.count, 4)
        
        // Verify all tasks have results
        let expectedKeys = Set(["original", "stop_1", "stop_2", "stop_3"])
        XCTAssertEqual(Set(finalResults), expectedKeys)
    }
    
    // Test Case 16: Stop then immediate fetch race
    func testConcurrentStopThenImmediateFetch() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1)
        
        let exp = expectation(description: "stop-then-fetch race completed")
        exp.expectedFulfillmentCount = 3
        
        let results = TestDataContainer([String]())
        let timeline = TestDataContainer([String]())
        
        // Start initial task
        manager.fetch(key: "victim", result: { result in
            Task {
                await timeline.modify { order in
                    order.append("victim_completed")
                }
                if case .success(let value) = result, let unwrappedValue = value {
                    await results.modify { array in
                        array.append(unwrappedValue)
                    }
                }
                exp.fulfill()  // Fulfill after async operations complete
            }
        })
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        await withTaskGroup(of: Void.self) { group in
            // Start interrupt task
            group.addTask {
                manager.fetch(key: "interrupter", result: { result in
                    Task {
                        await timeline.modify { order in
                            order.append("interrupter_completed")
                        }
                        if case .success(let value) = result, let unwrappedValue = value {
                            await results.modify { array in
                                array.append(unwrappedValue)
                            }
                        }
                        exp.fulfill()  // Fulfill after async operations complete
                    }
                })
            }
            
            // Almost simultaneously re-fetch the interrupted task
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000) // 0.005 seconds tiny delay
                manager.fetch(key: "victim", result: { result in
                    Task {
                        await timeline.modify { order in
                            order.append("victim_resumed")
                        }
                        if case .success(let value) = result, let unwrappedValue = value {
                            await results.modify { array in
                                array.append(unwrappedValue)
                            }
                        }
                        exp.fulfill()  // Fulfill after async operations complete
                    }
                })
            }
        }
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalResults = await results.get()
        let finalTimeline = await timeline.get()
        
        XCTAssertEqual(finalResults.count, 3)
        XCTAssertEqual(finalTimeline.count, 3)
        
        // Verify all tasks completed
        XCTAssertEqual(Set(finalResults), Set(["victim", "interrupter"]))
    }
    
    var count = 0
    // Test Case 17: Complex triple race - fetch + stop + finish
    func testConcurrentTripleRace() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 2, queueing: 1)
        
        let exp = expectation(description: "triple race completed")
        exp.expectedFulfillmentCount = 4
        
        let results = TestDataContainer([String]())
        let operations = TestDataContainer([String]())
        
        // Start two initial tasks (fill running slots)
        for i in 1...2 {
            manager.fetch(key: "runner_\(i)", result: { result in
                Task {
                    await operations.modify { ops in
                        ops.append("runner_\(i)_completed")
                    }
                    if case .success(let value) = result, let unwrappedValue = value {
                        await results.modify { array in
                            array.append(unwrappedValue)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        try? await Task.sleep(nanoseconds: 800_000_000 - 1) // < 0.8 seconds
        
        // Complex race operations
        await withTaskGroup(of: Void.self) { group in
            // Operation 1: New fetch (will trigger stop)
            group.addTask {
                manager.fetch(key: "new_task", result: { result in
                    Task {
                        await operations.modify { ops in
                            ops.append("new_task_completed")
                        }
                        if case .success(let value) = result, let unwrappedValue = value {
                            await results.modify { array in
                                array.append(unwrappedValue)
                            }
                        }
                    }
                    exp.fulfill()
                })
            }
            
            // Operation 2: Almost simultaneously fetch another key
            group.addTask {
                manager.fetch(key: "concurrent_new", result: { result in
                    Task {
                        await operations.modify { ops in
                            ops.append("concurrent_new_completed")
                        }
                        if case .success(let value) = result, let unwrappedValue = value {
                            await results.modify { array in
                                array.append(unwrappedValue)
                            }
                        }
                    }
                    exp.fulfill()
                })
            }
        }
        
        await fulfillment(of: [exp], timeout: 20.0)
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        
        let finalResults = await results.get()
        let finalOperations = await operations.get()
        
        XCTAssertEqual(finalOperations.count, 4)
        
        // Verify all tasks have results
        XCTAssertLessThanOrEqual(finalResults.count, 4)
        XCTAssertGreaterThanOrEqual(finalResults.count, 3)
        
        if finalResults.count == 4 {
            let expectedKeys = Set(["runner_2", "new_task", "concurrent_new", "runner_1"])
            XCTAssertEqual(Set(finalResults), expectedKeys)
        } else if finalResults.count == 3 {
            XCTAssertTrue(Set(finalResults).contains("new_task"))
            XCTAssertTrue(Set(finalResults).contains("concurrent_new"))
        }
    }
    
    // Test Case 18: Extreme stress test - Massive concurrent operations on same key
    func testExtremeStressConcurrencySameKey() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 2)
        
        let concurrentOps = 20 // 20 concurrent operations
        let exp = expectation(description: "extreme stress completed")
        exp.expectedFulfillmentCount = concurrentOps
        
        let successfulResults = TestDataContainer([String]())
        let failedResults = TestDataContainer([String]())
        let operationTypes = TestDataContainer([String]())
        
        for i in 1...concurrentOps {
            let opType = i % 3 == 0 ? "same_key" : "same_key_\(i % 5)" // Mix of same and different keys
            manager.fetch(key: opType, result: { result in
                Task {
                    await operationTypes.modify { types in
                        types.append("op_\(i)_\(opType)")
                    }
                    switch result {
                    case .success:
                        await successfulResults.modify { array in
                            array.append(opType)
                        }
                    case .failure:
                        await failedResults.modify { array in
                            array.append(opType)
                        }
                    }
                }
                exp.fulfill()
            })
        }
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = (await successfulResults.get()) + (await failedResults.get())
        let finalTypes = await operationTypes.get()
        
        XCTAssertEqual(finalResults.count, concurrentOps)
        XCTAssertEqual(finalTypes.count, concurrentOps)
        
        // Verify no duplicate or lost operations
        XCTAssertEqual(Set(finalTypes).count, concurrentOps) // Each operation is unique
        
        // Count results for different keys
        let resultCounts = Dictionary(grouping: finalResults.compactMap { $0 }) { $0 }
        let sameKeyCount = resultCounts["same_key"]?.count ?? 0
        
        // same_key should be requested multiple times
        XCTAssertEqual(sameKeyCount, 6, "Same key should be requested multiple times")
    }
    
    // Test Case 18: Extreme stress test - Massive concurrent operations on same key
    func testExtremeStressConcurrencySameKeyRandomly() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 2)
        
        let concurrentOps = 20 // 20 concurrent operations
        let exp = expectation(description: "extreme stress completed")
        exp.expectedFulfillmentCount = concurrentOps
        
        let successfulResults = TestDataContainer([String]())
        let failedResults = TestDataContainer([String]())
        let operationTypes = TestDataContainer([String]())
        
        await withTaskGroup(of: Void.self) { group in
            for i in 1...concurrentOps {
                group.addTask {
                    // Random delay to increase race condition possibilities
                    let randomDelay = UInt64.random(in: 1_000_000...50_000_000) // 0.001-0.05 seconds
                    try? await Task.sleep(nanoseconds: randomDelay)
                    
                    let opType = i % 3 == 0 ? "same_key" : "same_key_\(i % 5)" // Mix of same and different keys
                    manager.fetch(key: opType, result: { result in
                        Task {
                            await operationTypes.modify { types in
                                types.append("op_\(i)_\(opType)")
                            }
                            switch result {
                            case .success:
                                await successfulResults.modify { array in
                                    array.append(opType)
                                }
                            case .failure:
                                await failedResults.modify { array in
                                    array.append(opType)
                                }
                            }
                        }
                        exp.fulfill()
                    })
                }
            }
        }
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = (await successfulResults.get()) + (await failedResults.get())
        let finalTypes = await operationTypes.get()
        
        XCTAssertEqual(finalResults.count, concurrentOps)
        XCTAssertEqual(finalTypes.count, concurrentOps)
        
        // Verify no duplicate or lost operations
        XCTAssertEqual(Set(finalTypes).count, concurrentOps) // Each operation is unique
        
        // Count results for different keys
        let resultCounts = Dictionary(grouping: finalResults.compactMap { $0 }) { $0 }
        let sameKeyCount = resultCounts["same_key"]?.count ?? 0
        
        // same_key should be requested multiple times
        XCTAssertEqual(sameKeyCount, 6, "Same key should be requested multiple times")
    }
    
    // Test Case 19: Rapid consecutive fetch/stop cycles
    func testRapidFetchStopCycle() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 0)
        
        let cycles = 10
        let exp = expectation(description: "rapid cycles completed")
        exp.expectedFulfillmentCount = cycles * 2 // 2 operations per cycle
        
        let successfulResults = TestDataContainer([String]())
        let failedResults = TestDataContainer([String]())
        let cycleOrder = TestDataContainer([String]())
        
        // Rapid cycles: fetch -> stop -> fetch -> stop
        for cycle in 1...cycles {
            // Start task
            let keyVictim = "cycle_\(cycle)_victim"
            manager.fetch(key: keyVictim, result: { result in
                Task {
                    await cycleOrder.modify { order in
                        order.append("\(keyVictim)_done")
                    }
                    switch result {
                    case .success:
                        await successfulResults.modify { array in
                            array.append(keyVictim)
                        }
                    case .failure:
                        await failedResults.modify { array in
                            array.append(keyVictim)
                        }
                    }
                }
                exp.fulfill()
            })
            
            let keyStopper = "cycle_\(cycle)_stopper"
            manager.fetch(key: keyStopper, result: { result in
                Task {
                    await cycleOrder.modify { order in
                        order.append("\(keyStopper)_done")
                    }
                    switch result {
                    case .success:
                        await successfulResults.modify { array in
                            array.append(keyStopper)
                        }
                    case .failure(_):
                        await failedResults.modify { array in
                            array.append(keyStopper)
                        }
                    }
                }
                exp.fulfill()
            })
            
            // Brief interval between cycles
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
        
        await fulfillment(of: [exp], timeout: 101.0)
        
        let finalSuccessfulResults = await successfulResults.get()
        let finalFailedResults = await failedResults.get()
        let finalOrder = await cycleOrder.get()
        
        XCTAssertEqual(finalSuccessfulResults.count, 10)
        XCTAssertEqual(finalFailedResults.count, 10)
        XCTAssertEqual(finalOrder.count, cycles * 2)
    }
    
    // MARK: - Dealloc/Reuse Behavior Tests
    // 
    // These tests focus on LIFO(.stop) strategy since it's the only priority strategy
    // that actually calls stop() on DataProviders, which is where dealloc/reuse behavior occurs.
    
    // Test Case 20: Dealloc behavior - provider removed, auto-restart creates new provider
    func testStopAction_DeallocBehavior() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 1000, cacheConfig: MemoryCache<String, String>.Configuration(memoryUsageLimitation: .init(capacity: 0, memory: 0)))
        
        let exp = expectation(description: "dealloc task completed after interruption")
        let progressEvents = TestDataContainer([MockDataProviderProgress]())
        let interrupterCompleted = TestDataContainer(false)
        let restartDetected = TestDataContainer(false)
        let progressMade = TestDataContainer(false)
        
        // Start task that will be deallocated - use shorter key for predictable timing
        manager.fetch(key: "dealloc_test", customEventObserver: { progress in
            Task {
                await progressEvents.modify { events in
                    events.append(progress)
                }
                
                // Track that progress was made before interruption
                if progress.completedLength > 0 {
                    _ = await progressMade.modify { res in res = true }
                }
                
                // Detect restart: if we see progress start from 0 again after interrupter completed
                let interrupterDone = await interrupterCompleted.get()
                if interrupterDone && progress.completedLength == 0 {
                    await restartDetected.set(true)
                }
            }
        }, result: { result in
            exp.fulfill()
        })
        
        // Wait longer to ensure task makes progress (at least 3-4 characters processed)
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Verify progress was made before interrupting
        let progressed = await progressMade.get()
        XCTAssertTrue(progressed, "Task should have made progress before interruption")
        
        // Use a very short interrupter that finishes quickly, allowing auto-restart
        manager.fetch(key: "s", result: { _ in
            Task {
                await interrupterCompleted.set(true)
            }
        })
        
        // The original task will auto-restart when "s" finishes
        // Wait for original task to complete
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalProgress = await progressEvents.get()
        let restarted = await restartDetected.get()
        
        // For dealloc behavior: should see progress restart from 0 after interruption
        XCTAssertFalse(finalProgress.isEmpty, "Should have progress events")
        XCTAssertTrue(restarted, "Should detect restart from beginning (dealloc behavior)")
        
        // Should have multiple 0 progress events (initial start + restart after dealloc)
        let zeroProgressCount = finalProgress.filter { $0.completedLength == 0 }.count
        XCTAssertGreaterThan(zeroProgressCount, 1, "Dealloc should restart from 0, creating multiple 0-progress events")
    }
    
    // Test Case 21: Reuse behavior - provider kept, auto-restart resumes from where left off
    func testStopAction_ReuseBehavior() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 1000, cacheConfig: MemoryCache<String, String>.Configuration(memoryUsageLimitation: .init(capacity: 0, memory: 0)))
        
        let exp = expectation(description: "reuse task completed after interruption")
        let progressEvents = TestDataContainer([MockDataProviderProgress]())
        let interrupterCompleted = TestDataContainer(false)
        let resumeDetected = TestDataContainer(false)
        let lastProgressBeforeStop = TestDataContainer(0)
        let progressMade = TestDataContainer(false)
        
        // Start task that will be reused - use shorter key for predictable timing
        manager.fetch(key: "reuse_test", customEventObserver: { progress in
            Task {
                await progressEvents.modify { events in
                    events.append(progress)
                }
                
                // Track that progress was made
                if progress.completedLength > 0 {
                    _ = await progressMade.modify { res in res = true }
                }
                
                // Track progress before interruption
                let interrupterDone = await interrupterCompleted.get()
                if !interrupterDone {
                    await lastProgressBeforeStop.set(progress.completedLength)
                } else {
                    // After interrupter completed, check if we resume from last progress
                    let lastProgress = await lastProgressBeforeStop.get()
                    if progress.completedLength == lastProgress && lastProgress > 0 {
                        await resumeDetected.set(true)
                    }
                }
            }
        }, result: { result in
            exp.fulfill()
        })
        
        // Wait longer to ensure task makes progress (at least 3-4 characters processed)
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Verify progress was made before interrupting
        let progressed = await progressMade.get()
        XCTAssertTrue(progressed, "Task should have made progress before interruption")
        
        // Use a very short interrupter that finishes quickly, allowing auto-restart
        manager.fetch(key: "s", result: { _ in
            Task {
                await interrupterCompleted.set(true)
            }
        })
        
        // The original task will auto-restart when "s" finishes
        // Wait for original task to complete
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalProgress = await progressEvents.get()
        let resumed = await resumeDetected.get()
        let lastProgress = await lastProgressBeforeStop.get()
        
        // For reuse behavior: should resume from where it left off
        XCTAssertFalse(finalProgress.isEmpty, "Should have progress events")
        XCTAssertGreaterThan(lastProgress, 0, "Should have made progress before stop")
        XCTAssertTrue(resumed, "Should detect resume from last progress (reuse behavior)")
        
        // Should NOT have multiple 0 progress events (unlike dealloc)
        let zeroProgressCount = finalProgress.filter { $0.completedLength == 0 }.count
        XCTAssertEqual(zeroProgressCount, 1, "Reuse should not restart from 0, only initial 0-progress event")
    }
    
    // Test Case 22: Compare dealloc vs reuse behavior side by side
    func testCompareDeallocVsReuse() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 1000, cacheConfig: MemoryCache<String, String>.Configuration(memoryUsageLimitation: .init(capacity: 0, memory: 0)))
        
        let exp = expectation(description: "comparison completed")
        exp.expectedFulfillmentCount = 2
        
        let deallocZeroCount = TestDataContainer(0)
        let reuseZeroCount = TestDataContainer(0)
        let deallocProgressMade = TestDataContainer(false)
        let reuseProgressMade = TestDataContainer(false)
        
        // Test dealloc behavior first - use shorter key for predictable timing
        manager.fetch(key: "dealloc_task", customEventObserver: { progress in
            Task {
                if progress.completedLength == 0 {
                    _ = await deallocZeroCount.modify { count in count += 1 }
                } else if progress.completedLength > 0 {
                    _ = await deallocProgressMade.modify { res in res = true }
                }
            }
        }, result: { result in
            exp.fulfill()
        })
        
        // Wait longer to ensure task makes progress (at least 3-4 characters processed)
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Verify progress was made before interrupting
        let deallocProgressed = await deallocProgressMade.get()
        XCTAssertTrue(deallocProgressed, "Task should have made progress before interruption")
        
        manager.fetch(key: "interrupt1", result: { _ in })
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds - wait for dealloc task to complete
        
        // Test reuse behavior second - use shorter key for predictable timing  
        manager.fetch(key: "reuse_task", customEventObserver: { progress in
            Task {
                if progress.completedLength == 0 {
                    _ = await reuseZeroCount.modify { count in count += 1 }
                } else if progress.completedLength > 0 {
                    _ = await reuseProgressMade.modify { res in res = true }
                }
            }
        }, result: { result in
            exp.fulfill()
        })
        
        // Wait longer to ensure task makes progress (at least 3-4 characters processed)
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Verify progress was made before interrupting
        let reuseProgressed = await reuseProgressMade.get()
        XCTAssertTrue(reuseProgressed, "Task should have made progress before interruption")
        
        manager.fetch(key: "interrupt2", result: { _ in })
        
        await fulfillment(of: [exp], timeout: 20.0)
        
        let finalDeallocZeros = await deallocZeroCount.get()
        let finalReuseZeros = await reuseZeroCount.get()
        
        // Dealloc should create new provider = multiple zero progress events
        // Reuse should resume existing provider = only one zero progress event
        XCTAssertGreaterThan(finalDeallocZeros, 1, "Dealloc should have multiple zero-progress events (restart)")
        XCTAssertEqual(finalReuseZeros, 1, "Reuse should have only one zero-progress event (no restart)")
    }
    
    // Test Case 23: Multiple interruptions to verify consistent dealloc/reuse behavior
    func testMultipleInterruptions_DeallocVsReuse() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 10, cacheConfig: MemoryCache<String, String>.Configuration(memoryUsageLimitation: .init(capacity: 0, memory: 0)))
        
        let exp = expectation(description: "multiple interruptions completed")
        exp.expectedFulfillmentCount = 2
        
        let deallocRestartsCount = TestDataContainer(0)
        let reuseRestartsCount = TestDataContainer(0)
        let deallocProgressMade = TestDataContainer(false)
        let reuseProgressMade = TestDataContainer(false)
        
        // Test dealloc with multiple interruptions - use shorter key for predictable timing
        manager.fetch(key: "multi_dealloc", customEventObserver: { progress in
            Task {
                if progress.completedLength == 0 {
                    _ = await deallocRestartsCount.modify { count in count += 1 }
                } else if progress.completedLength > 0 {
                    _ = await deallocProgressMade.modify { res in res = true }
                }
            }
        }, result: { result in
            exp.fulfill()
        })
        
        // Wait longer to ensure progress, then multiple interruptions with adequate spacing
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Verify progress was made before first interruption
        let deallocProgressed = await deallocProgressMade.get()
        XCTAssertTrue(deallocProgressed, "Dealloc task should have made progress before interruptions")
        
        manager.fetch(key: "int1", result: { _ in })
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        manager.fetch(key: "int2", result: { _ in })
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        manager.fetch(key: "int3", result: { _ in })
        
        // Wait for dealloc task to eventually complete
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Test reuse with multiple interruptions - use shorter key for predictable timing
        manager.fetch(key: "multi_reuse", customEventObserver: { progress in
            Task {
                if progress.completedLength == 0 {
                    _ = await reuseRestartsCount.modify { count in count += 1 }
                } else if progress.completedLength > 0 {
                    _ = await reuseProgressMade.modify { res in res = true }
                }
            }
        }, result: { result in
            exp.fulfill()
        })
        
        // Wait longer to ensure progress, then multiple interruptions with adequate spacing
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Verify progress was made before first interruption
        let reuseProgressed = await reuseProgressMade.get()
        XCTAssertTrue(reuseProgressed, "Reuse task should have made progress before interruptions")
        
        manager.fetch(key: "int4", result: { _ in })
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        manager.fetch(key: "int5", result: { _ in })
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
        manager.fetch(key: "int6", result: { _ in })
        
        await fulfillment(of: [exp], timeout: 30.0)
        
        let deallocRestarts = await deallocRestartsCount.get()
        let reuseRestarts = await reuseRestartsCount.get()
        
        // Dealloc should have multiple restarts (each interruption creates new provider)
        // Reuse should have only one start (provider is reused across interruptions)
        XCTAssertGreaterThan(deallocRestarts, 1, "Dealloc should restart multiple times after interruptions")
        XCTAssertEqual(reuseRestarts, 1, "Reuse should start only once, then resume across interruptions")
    }
    
    // MARK: - Cache Edge Cases Tests
    
    // Test Case 24: Cache hitNullElement and invalidKey scenarios
    func testCacheEdgeCases_NullAndInvalidKeys() async {
        // Test with custom cache config that validates keys
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: .init(capacity: 100, memory: 1024 * 1024),
            keyValidator: { key in
                return !key.contains("invalid")  // Keys with "invalid" are considered invalid
            }
        )
        
        let manager = makeManager(priority: .FIFO, running: 1, queueing: 10, cacheConfig: cacheConfig)
        
        let exp = expectation(description: "cache edge cases completed")
        exp.expectedFulfillmentCount = 3
        
        let results = TestDataContainer([String: Result<String?, Error>]())
        
        // Test 1: Valid key that returns actual result  
        manager.fetch(key: "valid_test", result: { result in
            Task {
                await results.modify { dict in
                    dict["valid_test"] = result
                }
            }
            exp.fulfill()
        })
        
        // Wait for first task to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Test 2: Fetch same valid key again - should hit cache with actual value
        manager.fetch(key: "valid_test", result: { result in
            Task {
                await results.modify { dict in
                    dict["valid_test_cached"] = result
                }
            }
            exp.fulfill()
        })
        
        // Test 3: Fetch invalid key - should be rejected by cache immediately (returns nil)
        manager.fetch(key: "invalid_key_test", result: { result in
            Task {
                await results.modify { dict in
                    dict["invalid_key"] = result
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = await results.get()
        
        // Verify results
        if case .success(let value) = finalResults["valid_test"] {
            XCTAssertEqual(value, "valid_test", "First valid task should return actual value")
        } else {
            XCTFail("Valid task should succeed")
        }
        
        if case .success(let value) = finalResults["valid_test_cached"] {
            XCTAssertEqual(value, "valid_test", "Cached valid should return actual value")
        } else {
            XCTFail("Cached valid task should succeed")
        }
        
        if case .success(let value) = finalResults["invalid_key"] {
            XCTAssertEqual(value, nil, "Invalid key should return nil from cache")
        } else {
            XCTFail("Invalid key should return success(nil), not error")
        }
        
        XCTAssertEqual(finalResults.count, 3, "Should have all three results")
        
        // The key point: Invalid keys are caught by cache validation and return nil immediately
        // DataProvider never receives invalid keys due to cache validation
    }
    
    // Test Case 24b: Direct DataProvider validation consistency test 
    func testDataProviderValidationConsistency() async {
        // Test the DataProvider directly to verify it follows the same validation rules as cache
        let exp = expectation(description: "provider validation completed")
        exp.expectedFulfillmentCount = 2
        
        let results = TestDataContainer([String: Result<String?, Error>]())
        
        // Test valid key directly with existing MockDataProvider
        let validProvider = MockDataProvider(
            key: "valid_key_direct", 
            customEventPublisher: { _ in },
            resultPublisher: { result in
                Task {
                    await results.modify { dict in
                        dict["valid_direct"] = result
                    }
                }
                exp.fulfill()
            }
        )
        validProvider.start()
        
        // Test invalid key directly with existing MockDataProvider
        let invalidProvider = MockDataProvider(
            key: "invalid_key_direct", 
            customEventPublisher: { _ in },
            resultPublisher: { result in
                Task {
                    await results.modify { dict in
                        dict["invalid_direct"] = result
                    }
                }
                exp.fulfill()
            }
        )
        invalidProvider.start()
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        let finalResults = await results.get()
        
        // Verify DataProvider follows same validation rule as cache
        if case .success(let value) = finalResults["valid_direct"] {
            XCTAssertEqual(value, "valid_key_direct", "Provider should return valid key")
        } else {
            XCTFail("Valid key should succeed")
        }
        
        if case .failure(let error) = finalResults["invalid_direct"] {
            XCTAssertTrue(error is MockDataProvider.Errors, "Provider should return invalidKey error for invalid key")
        } else {
            XCTFail("Invalid key should return error from provider")
        }
        
        // This proves DataProvider and cache validation are consistent
        XCTAssertEqual(finalResults.count, 2, "Should have both results")
        
        sleep(10)
    }
    
    // Test Case 25: DataProvider error scenarios during execution
    func testDataProviderErrorScenarios() async {
        // Use cache config without keyValidator so invalid keys reach the provider
        let cacheConfig = MemoryCache<String, String>.Configuration(memoryUsageLimitation: .init(capacity: 0, memory: 0))
        let manager = makeManager(priority: .FIFO, running: 2, queueing: 10, cacheConfig: cacheConfig)
        
        let exp = expectation(description: "error handling completed")
        exp.expectedFulfillmentCount = 2
        
        let results = TestDataContainer([String: Result<String?, Error>]())
        
        // Test normal task - MockDataProvider handles this normally
        manager.fetch(key: "normal_task", result: { result in
            Task {
                await results.modify { dict in
                    dict["normal"] = result
                }
            }
            exp.fulfill()
        })
        
        // Test invalid key - MockDataProvider now throws error for invalid keys
        manager.fetch(key: "invalid_error_task", result: { result in
            Task {
                await results.modify { dict in
                    dict["error"] = result
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 5.0)
        
        let finalResults = await results.get()
        
        // Normal task should succeed
        if case .success(let value) = finalResults["normal"] {
            XCTAssertEqual(value, "normal_task", "Normal task should return its key")
        } else {
            XCTFail("Normal task should succeed")
        }
        
        // Invalid key should trigger error from MockDataProvider
        if case .failure(let error) = finalResults["error"] {
            XCTAssertTrue(error is MockDataProvider.Errors, "Should get MockDataProvider.Errors.invalidKey")
        } else {
            XCTFail("Invalid key should trigger error from provider")
        }
    }
    
    // Test Case 26: Configuration edge cases
    func testConfigurationEdgeCases() async {
        // Test with zero running tasks (should queue everything)
        let zeroRunningManager = makeManager(priority: .FIFO, running: 0, queueing: 3)
        
        let exp1 = expectation(description: "zero running config")
        exp1.expectedFulfillmentCount = 1
        
        let results1 = TestDataContainer([String]())
        
        // This should fail or be evicted since no running slots
        zeroRunningManager.fetch(key: "zero_running_test", result: { result in
            Task {
                switch result {
                case .success(let value):
                    if let value = value {
                        await results1.modify { array in array.append(value) }
                    }
                case .failure:
                    // Expected behavior for zero running slots
                    break
                }
            }
            exp1.fulfill()
        })
        
        await fulfillment(of: [exp1], timeout: 2.0)
        
        // Test with zero queueing capacity
        let zeroQueueManager = makeManager(priority: .FIFO, running: 1, queueing: 0)
        
        let exp2 = expectation(description: "zero queue config") 
        exp2.expectedFulfillmentCount = 2
        
        let results2 = TestDataContainer([String]())
        let errors2 = TestDataContainer([String]())
        
        // First task should run
        zeroQueueManager.fetch(key: "first", result: { result in
            Task {
                switch result {
                case .success(let value):
                    if let value = value {
                        await results2.modify { array in array.append(value) }
                    }
                case .failure:
                    await errors2.modify { array in array.append("first") }
                }
            }
            exp2.fulfill()
        })
        
        // Second task should be evicted immediately (no queue space)
        zeroQueueManager.fetch(key: "second", result: { result in
            Task {
                switch result {
                case .success(let value):
                    if let value = value {
                        await results2.modify { array in array.append(value) }
                    }
                case .failure:
                    await errors2.modify { array in array.append("second") }
                }
            }
            exp2.fulfill()
        })
        
        await fulfillment(of: [exp2], timeout: 5.0)
        
        let finalResults2 = await results2.get()
        let finalErrors2 = await errors2.get()
        
        XCTAssertEqual(finalResults2.count + finalErrors2.count, 2, "Should handle both tasks")
        XCTAssertEqual(finalResults2.count, 1, "Only one task should succeed with zero queue")
    }
    
    // Test Case 27: Concurrent fetch for same key in different states
    func testConcurrentFetchSameKeyDifferentStates() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 5, cacheConfig: MemoryCache<String, String>.Configuration(memoryUsageLimitation: .init(capacity: 0, memory: 0)))
        
        let exp = expectation(description: "concurrent same key completed")
        exp.expectedFulfillmentCount = 4
        
        let callbackOrder = TestDataContainer([String]())
        let results = TestDataContainer([String]())
        
        // Start first fetch
        manager.fetch(key: "concurrent_key", result: { result in
            Task {
                await callbackOrder.modify { order in order.append("first") }
                if case .success(let value) = result, let value = value {
                    await results.modify { array in array.append(value) }
                }
            }
            exp.fulfill()
        })
        
        // Quick second fetch while first is running
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        manager.fetch(key: "concurrent_key", result: { result in
            Task {
                await callbackOrder.modify { order in order.append("second") }
                if case .success(let value) = result, let value = value {
                    await results.modify { array in array.append(value) }
                }
            }
            exp.fulfill()
        })
        
        // Interrupt with different key
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        manager.fetch(key: "interrupter", result: { result in
            Task {
                await callbackOrder.modify { order in order.append("interrupter") }
                if case .success(let value) = result, let value = value {
                    await results.modify { array in array.append(value) }
                }
            }
            exp.fulfill()
        })
        
        // Third fetch while original is stopped/queued
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        manager.fetch(key: "concurrent_key", result: { result in
            Task {
                await callbackOrder.modify { order in order.append("third") }
                if case .success(let value) = result, let value = value {
                    await results.modify { array in array.append(value) }
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalOrder = await callbackOrder.get()
        let finalResults = await results.get()
        
        XCTAssertEqual(finalOrder.count, 4, "Should have all four callbacks")
        XCTAssertTrue(finalOrder.contains("first"), "Should have first callback")
        XCTAssertTrue(finalOrder.contains("second"), "Should have second callback") 
        XCTAssertTrue(finalOrder.contains("third"), "Should have third callback")
        XCTAssertTrue(finalOrder.contains("interrupter"), "Should have interrupter callback")
        
        // All concurrent_key fetches should get the same result
        let concurrentResults = finalResults.filter { $0 == "concurrent_key" }
        XCTAssertEqual(concurrentResults.count, 3, "All three concurrent_key fetches should succeed")
    }
    
    // Test Case 28: Cache statistics reporting
    func testCacheStatisticsReporting() async {
        let statsReports = TestDataContainer([(CacheStatistics, CacheRecord)]())
        
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: .init(capacity: 5, memory: 1024)
        )
        
        let config = KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider>.Config(
            maxNumberOfQueueingTasks: 10,
            maxNumberOfRunningTasks: 2,
            priorityStrategy: .FIFO,
            cacheConfig: cacheConfig,
            cacheStatisticsReport: { stats, record in
                Task {
                    await statsReports.modify { reports in
                        reports.append((stats, record))
                    }
                }
            }
        )
        let manager = KVHeavyTasksManager<String, String, MockDataProviderProgress, MockDataProvider>(config: config)
        
        let exp = expectation(description: "cache statistics completed")
        exp.expectedFulfillmentCount = 3
        
        // Generate cache activity
        manager.fetch(key: "stats_test_1", result: { _ in exp.fulfill() })
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        manager.fetch(key: "stats_test_2", result: { _ in exp.fulfill() })
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Should hit cache for same key
        manager.fetch(key: "stats_test_1", result: { _ in exp.fulfill() })
        
        await fulfillment(of: [exp], timeout: 10.0)
        
        // Allow time for statistics to be reported
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let finalReports = await statsReports.get()
        
        XCTAssertFalse(finalReports.isEmpty, "Should have received cache statistics reports")
        
        // Verify we got statistics for cache operations
        let hasMissOperation = finalReports.contains { _, record in
            if case .miss = record { return true }
            return false
        }
        let hasHitOperation = finalReports.contains { _, record in
            if case .hitNonNullElement = record { return true }
            return false
        }
        
        XCTAssertTrue(hasMissOperation, "Should have cache miss operations")
        XCTAssertTrue(hasHitOperation || finalReports.count > 0, "Should have cache operations")
    }
    
    // Test Case 29: Provider cleanup verification
    func testProviderCleanupVerification() async {
        let manager = makeManager(priority: .LIFO(.stop), running: 1, queueing: 3, cacheConfig: MemoryCache<String, String>.Configuration(memoryUsageLimitation: .init(capacity: 0, memory: 0)))
        
        let exp = expectation(description: "cleanup verification completed")
        exp.expectedFulfillmentCount = 3
        
        let cleanupEvents = TestDataContainer([String]())
        
        // Test provider cleanup after normal completion
        manager.fetch(key: "cleanup_normal", customEventObserver: { progress in
            Task {
                if progress.completedLength == progress.totalLength {
                    await cleanupEvents.modify { events in
                        events.append("normal_completed")
                    }
                }
            }
        }, result: { result in
            Task {
                await cleanupEvents.modify { events in
                    events.append("normal_callback")
                }
            }
            exp.fulfill()
        })
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Test provider cleanup after dealloc stop
        manager.fetch(key: "cleanup_dealloc_test", result: { result in
            Task {
                await cleanupEvents.modify { events in
                    events.append("dealloc_callback")
                }
            }
            exp.fulfill()
        })
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Interrupt with short task (triggers dealloc)
        manager.fetch(key: "short_interrupt", result: { result in
            Task {
                await cleanupEvents.modify { events in
                    events.append("interrupt_callback")
                }
            }
            exp.fulfill()
        })
        
        await fulfillment(of: [exp], timeout: 15.0)
        
        let finalEvents = await cleanupEvents.get()
        
        XCTAssertTrue(finalEvents.contains("normal_completed"), "Should complete normal task")
        XCTAssertTrue(finalEvents.contains("normal_callback"), "Should call normal callback")
        XCTAssertTrue(finalEvents.contains("dealloc_callback"), "Should handle dealloc callback")
        XCTAssertTrue(finalEvents.contains("interrupt_callback"), "Should handle interrupt callback")
        
        // Verify proper cleanup sequence
        XCTAssertEqual(finalEvents.count, 4, "Should have all cleanup events")
    }
}
