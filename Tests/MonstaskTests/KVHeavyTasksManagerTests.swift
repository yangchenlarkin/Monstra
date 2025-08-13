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
}
