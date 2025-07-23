//
//  KVLightTasksComprehensiveTests.swift
//  MonstaskTests
//
//  Created by Test Generator on 2025/1/27.
//

import XCTest
@testable import Monstask
@testable import MonstraBase

final class KVLightTasksComprehensiveTests: XCTestCase {
}

// MARK: - Configuration & Initialization Tests
extension KVLightTasksComprehensiveTests {
    
    func testConfigInitialization() {
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        XCTAssertNotNil(taskManager)
    }
    
    func testConfigWithDifferentDataProviders() {
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let multifetch: KVLightTasks<String, String>.DataPovider.Multifetch = { keys, callback in
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let monoConfig = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let multiConfig = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maxmumBatchCount: 3, multifetch))
        
        let monoManager = KVLightTasks<String, String>(config: monoConfig)
        let multiManager = KVLightTasks<String, String>(config: multiConfig)
        
        XCTAssertNotNil(monoManager)
        XCTAssertNotNil(multiManager)
    }
}

// MARK: - Cache Integration Tests
extension KVLightTasksComprehensiveTests {
    
    func testCacheHitScenarios() {
        let expectation = XCTestExpectation(description: "Cache hit scenarios")
        expectation.expectedFulfillmentCount = 6
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                results[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second fetch - should hit cache
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                results[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count (should only be 3, not 6 due to caching)
        XCTAssertEqual(fetchCount, 3, "Should only fetch 3 times due to caching")
    }
    
    func testCacheMissScenarios() {
        let expectation = XCTestExpectation(description: "Cache miss scenarios")
        expectation.expectedFulfillmentCount = 3
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // Fetch unique keys - should all hit network
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                results[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count (should be 3 for unique keys)
        XCTAssertEqual(fetchCount, 3, "Should fetch 3 times for unique keys")
    }
}

// MARK: - Thread Management Tests
extension KVLightTasksComprehensiveTests {
    
    func testThreadCountManagement() {
        let expectation = XCTestExpectation(description: "Thread count management")
        expectation.expectedFulfillmentCount = 6
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate network delay without async dispatch
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // Fetch more keys than max threads to test thread management
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6"]) { key, result in
            switch result {
            case .success(let value):
                results[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4", "key5", "key6"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count
        XCTAssertEqual(fetchCount, 6, "Should fetch 6 times")
    }
}

// MARK: - Retry Mechanism Tests
extension KVLightTasksComprehensiveTests {
    func testRetryCountBehaviorSuccess() {
        let expectation = XCTestExpectation(description: "Retry count behavior")
        expectation.expectedFulfillmentCount = 1
        
        var attemptCount = 0
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            attemptCount += 1
            if attemptCount < 3 {
                callback(.failure(testError))
            } else {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch), retryCount: 10)
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var result: String?
        
        taskManager.fetch(key: "retry_key") { key, res in
            switch res {
            case .success(let value):
                result = value
            case .failure(let error):
                XCTFail("Should succeed after retries: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(result, "value_retry_key")
        XCTAssertEqual(attemptCount, 3, "Should attempt 3 times")
    }
    
    func testRetryCountBehaviorFail() {
        let expectation = XCTestExpectation(description: "Retry count behavior")
        expectation.expectedFulfillmentCount = 1
        
        var attemptCount = 0
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            attemptCount += 1
            if attemptCount < 3 {
                callback(.failure(testError))
            } else {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        taskManager.fetch(key: "retry_key") { key, res in
            switch res {
            case .success:
                XCTFail("Should fail due to just 1 retry")
            case .failure:
                break
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertEqual(attemptCount, 1, "Should attempt 1 times")
    }
    
    func testRetryExhaustion() {
        let expectation = XCTestExpectation(description: "Retry exhaustion")
        expectation.expectedFulfillmentCount = 1
        
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            callback(.failure(testError))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var result: Result<String?, Error>?
        
        taskManager.fetch(key: "exhaustion_key") { key, res in
            result = res
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        if case .failure(let error) = result {
            XCTAssertEqual(error as NSError, testError)
        } else {
            XCTFail("Expected failure after retry exhaustion")
        }
    }
}

// MARK: - Batch Processing Edge Cases
extension KVLightTasksComprehensiveTests {
    
    func testBatchSizeBoundaries() {
        let expectation = XCTestExpectation(description: "Batch size boundaries")
        expectation.expectedFulfillmentCount = 5
        
        var batchCount = 0
        let batchSemaphore = DispatchSemaphore(value: 1)
        
        let multifetch: KVLightTasks<String, String>.DataPovider.Multifetch = { keys, callback in
            batchSemaphore.wait()
            batchCount += 1
            batchSemaphore.signal()
            
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maxmumBatchCount: 2, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // Test with exactly batch size
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5"]) { key, result in
            switch result {
            case .success(let value):
                results[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4", "key5"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify batch count (should be 3 batches: 2, 2, 1)
        XCTAssertEqual(batchCount, 3, "Should process in 3 batches")
    }
    
    func testBatchSizeOne() {
        let expectation = XCTestExpectation(description: "Batch size one")
        expectation.expectedFulfillmentCount = 3
        
        var batchCount = 0
        let batchSemaphore = DispatchSemaphore(value: 1)
        
        let multifetch: KVLightTasks<String, String>.DataPovider.Multifetch = { keys, callback in
            batchSemaphore.wait()
            batchCount += 1
            batchSemaphore.signal()
            
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maxmumBatchCount: 1, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // Test with batch size 1
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                results[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify batch count (should be 3 batches of 1 each)
        XCTAssertEqual(batchCount, 3, "Should process in 3 batches of 1 each")
    }
}

// MARK: - Error Propagation Tests
extension KVLightTasksComprehensiveTests {
    
    func testErrorPropagationInBatches() {
        let expectation = XCTestExpectation(description: "Error propagation in batches")
        expectation.expectedFulfillmentCount = 4
        
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let multifetch: KVLightTasks<String, String>.DataPovider.Multifetch = { keys, callback in
            // Fail if any key contains "error"
            if keys.contains(where: { $0.contains("error") }) {
                callback(.failure(testError))
            } else {
                var results: [String: String?] = [:]
                for key in keys {
                    results[key] = "value_\(key)"
                }
                callback(.success(results))
            }
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maxmumBatchCount: 2, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: Result<String?, Error>] = [:]
        
        // Test with mixed success/failure in batches
        taskManager.fetch(keys: ["key1", "error1", "key2", "error2"]) { key, result in
            results[key] = result
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results - all should fail due to batch processing
        for key in ["key1", "error1", "key2", "error2"] {
            if case .failure(let error) = results[key] {
                XCTAssertEqual(error as NSError, testError)
            } else {
                XCTFail("Expected failure for \(key)")
            }
        }
    }
}

// MARK: - Performance Tests
extension KVLightTasksComprehensiveTests {
    
    func testLargeKeySetPerformance() {
        let expectation = XCTestExpectation(description: "Large key set performance")
        expectation.expectedFulfillmentCount = 100
        
        let startTime = Date()
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Generate 100 keys
        let keys = (1...100).map { "key\($0)" }
        
        taskManager.fetch(keys: keys) { key, result in
            resultsSemaphore.wait()
            switch result {
            case .success(let value):
                results[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            resultsSemaphore.signal()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Verify all results
        for key in keys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Performance assertion (should complete within reasonable time)
        XCTAssertLessThan(duration, 10.0, "Should complete within 10 seconds")
        XCTAssertEqual(results.count, 100, "Should have 100 results")
    }
} 
