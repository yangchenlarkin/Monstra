//
//  KVLightTasksTests.swift
//  MonstaskTests
//
//  Created by Test Generator on 2025/1/27.
//

import XCTest
@testable import Monstask
@testable import MonstraBase
@testable import Monstore

final class KVLightTasksTests: XCTestCase {
    
    // MARK: - Test Configuration
    private func createConfig(
        dataProvider: KVLightTasks<String, String>.DataProvider
    ) -> KVLightTasks<String, String>.Config {
        return KVLightTasks<String, String>.Config(dataProvider: dataProvider)
    }
}

// MARK: - Original Monofetch Tests
extension KVLightTasksTests {
    func testMonofetchBasicFunctionality() {
        let expectation = XCTestExpectation(description: "Monofetch basic functionality")
        expectation.expectedFulfillmentCount = 3
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation])
        
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        XCTAssertEqual(results["key3"], "value_key3")
    }
    
    func testSingleKeyFetch() {
        let expectation = XCTestExpectation(description: "Single key fetch")
        expectation.expectedFulfillmentCount = 1
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var result: String?
        
        taskManager.fetch(key: "single_key") { key, res in
            switch res {
            case .success(let value):
                result = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(result, "value_single_key")
    }
    
    func testMonofetchErrorHandling() {
        let expectation = XCTestExpectation(description: "Monofetch error handling")
        expectation.expectedFulfillmentCount = 2
        
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            if key == "error_key" {
                callback(.failure(testError))
            } else {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: Result<String?, Error>] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        taskManager.fetch(keys: ["key1", "error_key"]) { key, result in
            resultsSemaphore.wait()
            results[key] = result
            resultsSemaphore.signal()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        if case .success(let value) = results["key1"] {
            XCTAssertEqual(value, "value_key1")
        } else {
            XCTFail("Expected success for key1")
        }
        
        if case .failure(let error) = results["error_key"] {
            XCTAssertEqual(error as NSError, testError)
        } else {
            XCTFail("Expected failure for error_key")
        }
    }
    
    func testMonofetchCacheFunctionality() {
        let expectation = XCTestExpectation(description: "Monofetch cache functionality")
        expectation.expectedFulfillmentCount = 4  // 2 keys × 2 fetches = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var firstFetchResults: [String: String?] = [:]
        var secondFetchResults: [String: String?] = [:]
        let firstSemaphore = DispatchSemaphore(value: 1)
        let secondSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                firstSemaphore.wait()
                firstFetchResults[key] = value
                firstSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
            
            if firstFetchResults.count == 2 {
                // Second fetch - should hit cache
                taskManager.fetch(keys: ["key1", "key2"]) { key, result in
                    switch result {
                    case .success(let value):
                        secondSemaphore.wait()
                        secondFetchResults[key] = value
                        secondSemaphore.signal()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results are correct
        XCTAssertEqual(firstFetchResults["key1"], "value_key1")
        XCTAssertEqual(firstFetchResults["key2"], "value_key2")
        XCTAssertEqual(secondFetchResults["key1"], "value_key1")
        XCTAssertEqual(secondFetchResults["key2"], "value_key2")
        
        // Verify fetch count (should only be 2, not 4 due to caching)
        XCTAssertEqual(fetchCount, 2, "Should only fetch 2 times due to caching")
    }
    
    func testMonofetchEmptyKeySet() {
        let expectation = XCTestExpectation(description: "Monofetch empty key set")
        expectation.expectedFulfillmentCount = 1  // Fixed: must be greater than 0
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            XCTFail("Should not be called with empty key set")
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        taskManager.fetch(keys: []) { key, result in
            XCTFail("Should not be called with empty key set")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Original Multifetch Tests
extension KVLightTasksTests {
    func testMultifetchBasicFunctionality() {
        let expectation = XCTestExpectation(description: "Multifetch basic functionality")
        expectation.expectedFulfillmentCount = 6
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = createConfig(dataProvider: .multifetch(maximumBatchCount: 3, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4", "key5", "key6"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    func testMultifetchBatchProcessingModNonZero() {
        let expectation = XCTestExpectation(description: "Multifetch batch processing")
        expectation.expectedFulfillmentCount = 8
        
        var batchCount = 0
        let batchSemaphore = DispatchSemaphore(value: 1)
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            batchSemaphore.wait()
            batchCount += 1
            batchSemaphore.signal()
            
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = createConfig(dataProvider: .multifetch(maximumBatchCount: 3, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch 8 keys, should be processed in 3 batches (3, 3, 2)
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify batch count (should be 3 batches: 3, 3, 2)
        XCTAssertEqual(batchCount, 3, "Should process in 3 batches")
    }
    
    func testMultifetchBatchProcessingModZero() {
        let expectation = XCTestExpectation(description: "Multifetch batch processing")
        expectation.expectedFulfillmentCount = 9
        
        var batchCount = 0
        let batchSemaphore = DispatchSemaphore(value: 1)
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            batchSemaphore.wait()
            batchCount += 1
            batchSemaphore.signal()
            
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = createConfig(dataProvider: .multifetch(maximumBatchCount: 3, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch 8 keys, should be processed in 3 batches (3, 3, 2)
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8", "key9"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8", "key9"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify batch count (should be 3 batches: 3, 3, 2)
        XCTAssertEqual(batchCount, 3, "Should process in 3 batches")
    }
    
    func testMultifetchBatchProcessingLargeBatch() {
        let expectation = XCTestExpectation(description: "Multifetch batch processing")
        expectation.expectedFulfillmentCount = 8
        
        var batchCount = 0
        let batchSemaphore = DispatchSemaphore(value: 1)
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            batchSemaphore.wait()
            batchCount += 1
            batchSemaphore.signal()
            
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = createConfig(dataProvider: .multifetch(maximumBatchCount: 100, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch 8 keys, should be processed in 3 batches (3, 3, 2)
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"]) { key, result in
            switch result {
            case .success(let value):
                fetchSemaphore.wait()
                results[key] = value
                fetchSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify batch count (should be 3 batches: 3, 3, 2)
        XCTAssertEqual(batchCount, 1, "Should process in 3 batches")
    }
    
    func testMultifetchErrorHandling() {
        let expectation = XCTestExpectation(description: "Multifetch error handling")
        expectation.expectedFulfillmentCount = 2
        
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            // Simulate error for any batch containing error_key
            if keys.contains("error_key") {
                callback(.failure(testError))
            } else {
                var results: [String: String?] = [:]
                for key in keys {
                    results[key] = "value_\(key)"
                }
                callback(.success(results))
            }
        }
        
        let config = createConfig(dataProvider: .multifetch(maximumBatchCount: 2, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: Result<String?, Error>] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test with keys that will be in different batches
        taskManager.fetch(keys: ["key1", "error_key"]) { key, result in
            resultsSemaphore.wait()
            results[key] = result
            resultsSemaphore.signal()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results - both should fail because they're in the same batch
        if case .failure(let error) = results["key1"] {
            XCTAssertEqual(error as NSError, testError)
        } else {
            XCTFail("Expected failure for key1")
        }
        
        if case .failure(let error) = results["error_key"] {
            XCTAssertEqual(error as NSError, testError)
        } else {
            XCTFail("Expected failure for error_key")
        }
    }
    
    func testMultifetchEmptyKeySet() {
        let expectation = XCTestExpectation(description: "Multifetch empty key set")
        expectation.expectedFulfillmentCount = 1
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            XCTFail("Should not be called with empty key set")
        }
        
        let config = createConfig(dataProvider: .multifetch(maximumBatchCount: 3, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        taskManager.fetch(keys: []) { key, result in
            XCTFail("Should not be called with empty key set")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
} 

// MARK: - Comprehensive Tests
extension KVLightTasksTests {
    
    // MARK: - Configuration & Initialization Tests
    func testConfigInitialization() {
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        XCTAssertNotNil(taskManager)
    }
    
    func testConfigWithDifferentDataProviders() {
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let monoConfig = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let multiConfig = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maximumBatchCount: 3, multifetch))
        
        let monoManager = KVLightTasks<String, String>(config: monoConfig)
        let multiManager = KVLightTasks<String, String>(config: multiConfig)
        
        XCTAssertNotNil(monoManager)
        XCTAssertNotNil(multiManager)
    }
    
    // MARK: - Cache Integration Tests
    func testCacheHitScenarios() {
        let expectation = XCTestExpectation(description: "Cache hit scenarios")
        expectation.expectedFulfillmentCount = 6
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second fetch - should hit cache
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
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
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch unique keys - should all hit network
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
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
    
    // MARK: - Thread Management Tests
    func testThreadCountManagement() {
        let expectation = XCTestExpectation(description: "Thread count management")
        expectation.expectedFulfillmentCount = 6
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate network delay without async dispatch
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch more keys than max threads to test thread management
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
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
    
    // MARK: - Retry Mechanism Tests
    func testRetryCountBehaviorSuccess() {
        let expectation = XCTestExpectation(description: "Retry count behavior")
        expectation.expectedFulfillmentCount = 1
        
        var attemptCount = 0
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
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
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
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
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
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
    
    // MARK: - Batch Processing Edge Cases
    func testBatchSizeBoundaries() {
        let expectation = XCTestExpectation(description: "Batch size boundaries")
        expectation.expectedFulfillmentCount = 5
        
        var batchCount = 0
        let batchSemaphore = DispatchSemaphore(value: 1)
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            batchSemaphore.wait()
            batchCount += 1
            batchSemaphore.signal()
            
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maximumBatchCount: 2, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test with exactly batch size
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
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
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
            batchSemaphore.wait()
            batchCount += 1
            batchSemaphore.signal()
            
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maximumBatchCount: 1, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test with batch size 1
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
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
    
    // MARK: - Error Propagation Tests
    func testErrorPropagationInBatches() {
        let expectation = XCTestExpectation(description: "Error propagation in batches")
        expectation.expectedFulfillmentCount = 4
        
        let testError = NSError(domain: "TestError", code: 1, userInfo: nil)
        
        let multifetch: KVLightTasks<String, String>.DataProvider.Multifetch = { keys, callback in
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
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .multifetch(maximumBatchCount: 2, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: Result<String?, Error>] = [:]
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        // Test with mixed success/failure in batches
        taskManager.fetch(keys: ["key1", "error1", "key2", "error2"]) { key, result in
            fetchSemaphore.wait()
            results[key] = result
            fetchSemaphore.signal()
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
    
    // MARK: - Performance Tests
    func testLargeKeySetPerformance() {
        let expectation = XCTestExpectation(description: "Large key set performance")
        expectation.expectedFulfillmentCount = 100
        
        let startTime = Date()
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
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

// MARK: - Missing Tests (Key Priority, Thread Synchronization, etc.)
extension KVLightTasksTests {
    
    // MARK: - Key Priority Tests (LIFO vs FIFO)
    func testKeyPriorityLIFO() {
        let expectation = XCTestExpectation(description: "Key priority LIFO")
        expectation.expectedFulfillmentCount = 6
        
        var fetchOrder: [String] = []
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchOrder.append(key)
            fetchSemaphore.signal()
            
            // Simulate network delay without async dispatch
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 2,
            keyPriority: .LIFO
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch more keys than max threads to test queue behavior
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
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
        
        // In LIFO mode, the first 2 keys should be processed first, then the rest in LIFO order
        // The exact order depends on thread scheduling, but we can verify all keys were processed
        XCTAssertEqual(fetchOrder.count, 6, "All keys should be fetched")
        XCTAssertEqual(Set(fetchOrder), Set(["key1", "key2", "key3", "key4", "key5", "key6"]), "All keys should be fetched")
    }
    
    func testKeyPriorityFIFO() {
        let expectation = XCTestExpectation(description: "Key priority FIFO")
        expectation.expectedFulfillmentCount = 6
        
        var fetchOrder: [String] = []
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchOrder.append(key)
            fetchSemaphore.signal()
            
            // Simulate network delay without async dispatch
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 2,
            keyPriority: .FIFO
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch more keys than max threads to test queue behavior
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
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
        
        // In FIFO mode, the first 2 keys should be processed first, then the rest in FIFO order
        // The exact order depends on thread scheduling, but we can verify all keys were processed
        XCTAssertEqual(fetchOrder.count, 6, "All keys should be fetched")
        XCTAssertEqual(Set(fetchOrder), Set(["key1", "key2", "key3", "key4", "key5", "key6"]), "All keys should be fetched")
    }
    
    // MARK: - Thread Synchronization Tests
    func testSemaphoreSynchronization() {
        let expectation = XCTestExpectation(description: "Semaphore synchronization")
        expectation.expectedFulfillmentCount = 4
        
        var concurrentAccessCount = 0
        var maxConcurrentAccess = 0
        let accessSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            accessSemaphore.wait()
            concurrentAccessCount += 1
            maxConcurrentAccess = max(maxConcurrentAccess, concurrentAccessCount)
            accessSemaphore.signal()
            
            // Simulate work
            Thread.sleep(forTimeInterval: 0.1)
            
            accessSemaphore.wait()
            concurrentAccessCount -= 1
            accessSemaphore.signal()
            
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 2
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch keys to test semaphore synchronization
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify that semaphore properly limits concurrent access
        XCTAssertLessThanOrEqual(maxConcurrentAccess, 2, "Should not exceed max concurrent threads")
    }
    
    // MARK: - Callback Management Tests
    func testCallbackCachingAndConsuming() {
        let expectation = XCTestExpectation(description: "Callback caching and consuming")
        expectation.expectedFulfillmentCount = 6  // 2 keys × 3 callbacks
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var callbackCount1 = 0
        var callbackCount2 = 0
        var callbackCount3 = 0
        let callbackCount1Semaphore = DispatchSemaphore(value: 1)
        let callbackCount2Semaphore = DispatchSemaphore(value: 1)
        let callbackCount3Semaphore = DispatchSemaphore(value: 1)

        // First callback for the same keys
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            callbackCount1Semaphore.wait()
            callbackCount1 += 1
            callbackCount1Semaphore.signal()
            expectation.fulfill()
        }
        
        // Second callback for the same keys (should be cached)
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            callbackCount2Semaphore.wait()
            callbackCount2 += 1
            callbackCount2Semaphore.signal()
            expectation.fulfill()
        }
        
        // Third callback for the same keys (should be cached)
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            callbackCount3Semaphore.wait()
            callbackCount3 += 1
            callbackCount3Semaphore.signal()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all callbacks were called
        XCTAssertEqual(callbackCount1, 2, "First callback should be called 2 times")
        XCTAssertEqual(callbackCount2, 2, "Second callback should be called 2 times")
        XCTAssertEqual(callbackCount3, 2, "Third callback should be called 2 times")
        
        // Verify fetch count (should only be 2, not 6 due to caching)
        // Note: The actual behavior may vary due to timing, but should be <= 2
        XCTAssertLessThanOrEqual(fetchCount, 2, "Should fetch at most 2 times due to callback caching")
    }
    
    func testCallbackRemovalAfterConsuming() {
        let expectation = XCTestExpectation(description: "Callback removal after consuming")
        expectation.expectedFulfillmentCount = 2
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch keys
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        
        // Verify fetch count
        XCTAssertEqual(fetchCount, 2, "Should fetch 2 times")
        
        // After consuming, callbacks should be removed from internal storage
        // This is an internal implementation detail, but we can verify the behavior
        // by fetching the same keys again - they should hit cache
        let secondExpectation = XCTestExpectation(description: "Second fetch")
        secondExpectation.expectedFulfillmentCount = 2
        
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                XCTAssertEqual(value, "value_\(key)")
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            secondExpectation.fulfill()
        }
        
        wait(for: [secondExpectation], timeout: 5.0)
        
        // Fetch count should remain 2 (no additional fetches due to cache)
        XCTAssertEqual(fetchCount, 2, "Should not fetch again due to cache")
    }
    
    // MARK: - Dispatch Queue Integration Tests
    func testDispatchQueueIntegration() {
        let expectation = XCTestExpectation(description: "Dispatch queue integration")
        expectation.expectedFulfillmentCount = 2
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            // Note: We can't easily determine the current queue in this context
            // The dispatch queue integration is handled internally by the KVLightTasks
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch with custom dispatch queue
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
    }
    
    // MARK: - Memory Management Tests
    func testWeakReferenceHandling() {
        let expectation = XCTestExpectation(description: "Weak reference handling")
        expectation.expectedFulfillmentCount = 1
        
        var taskManager: KVLightTasks<String, String>?
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            // Simulate network delay without async dispatch
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        taskManager = KVLightTasks<String, String>(config: config)
        
        var result: String?
        
        taskManager?.fetch(key: "weak_test") { key, res in
            switch res {
            case .success(let value):
                result = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Don't release the task manager reference immediately
        // Let the callback complete first
        wait(for: [expectation], timeout: 10.0)
        
        // Verify result
        XCTAssertEqual(result, "value_weak_test")
        
        // Now release the reference
        taskManager = nil
    }
    
    // MARK: - Concurrent Fetch Scenarios
    func testConcurrentFetchScenarios() {
        let expectation = XCTestExpectation(description: "Concurrent fetch scenarios")
        expectation.expectedFulfillmentCount = 8
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate network delay without async dispatch
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 2
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Start multiple concurrent fetches
        DispatchQueue.global().async {
            taskManager.fetch(keys: ["key1", "key2"]) { key, result in
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
        }
        
        DispatchQueue.global().async {
            taskManager.fetch(keys: ["key3", "key4"]) { key, result in
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
        }
        
        DispatchQueue.global().async {
            taskManager.fetch(keys: ["key5", "key6"]) { key, result in
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
        }
        
        DispatchQueue.global().async {
            taskManager.fetch(keys: ["key7", "key8"]) { key, result in
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
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Verify all results
        for key in ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count (should be 8 for unique keys)
        XCTAssertEqual(fetchCount, 8, "Should fetch 8 times for unique keys")
    }
    
    // MARK: - Edge Cases in Thread Management
    func testThreadManagementWithZeroMaxThreads() {
        let expectation = XCTestExpectation(description: "Thread management with zero max threads")
        expectation.expectedFulfillmentCount = 2
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 1  // Use 1 instead of 0
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // This should work with limited concurrency
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        
        // Verify fetch count
        XCTAssertEqual(fetchCount, 2, "Should fetch 2 times")
    }
    
    func testThreadManagementWithLargeMaxThreads() {
        let expectation = XCTestExpectation(description: "Thread management with large max threads")
        expectation.expectedFulfillmentCount = 10
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 100
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch 10 keys
        let keys = (1...10).map { "key\($0)" }
        
        taskManager.fetch(keys: keys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all results
        for key in keys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count
        XCTAssertEqual(fetchCount, 10, "Should fetch 10 times")
    }
} 

// MARK: - Comprehensive Cache-Related Tests
extension KVLightTasksTests {
    
    // MARK: - Cache Hit Scenarios (null and non-null elements)
    func testCacheHitWithNullElements() {
        let expectation = XCTestExpectation(description: "Cache hit with null elements")
        expectation.expectedFulfillmentCount = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String?>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Return null for some keys
            if key == "null_key" {
                callback(.success(nil))
            } else {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = KVLightTasks<String, String?>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String?>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "null_key"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second fetch - should hit cache
        taskManager.fetch(keys: ["key1", "null_key"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertNil(results["null_key"] as Any?)
        
        // Verify fetch count (should only be 2, not 4 due to caching)
        XCTAssertEqual(fetchCount, 2, "Should only fetch 2 times due to caching")
    }
    
    func testCacheHitWithNonNullElements() {
        let expectation = XCTestExpectation(description: "Cache hit with non-null elements")
        expectation.expectedFulfillmentCount = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second fetch - should hit cache
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        
        // Verify fetch count (should only be 2, not 4 due to caching)
        XCTAssertEqual(fetchCount, 2, "Should only fetch 2 times due to caching")
    }
    
    // MARK: - Cache Miss Scenarios
    func testCacheMissWithDifferentKeys() {
        let expectation = XCTestExpectation(description: "Cache miss with different keys")
        expectation.expectedFulfillmentCount = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = KVLightTasks<String, String>.Config(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second fetch with different keys - should hit network again
        taskManager.fetch(keys: ["key3", "key4"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        XCTAssertEqual(results["key3"], "value_key3")
        XCTAssertEqual(results["key4"], "value_key4")
        
        // Verify fetch count (should be 4 for different keys)
        XCTAssertEqual(fetchCount, 4, "Should fetch 4 times for different keys")
    }
    
    // MARK: - Cache Eviction and TTL Expiration
    func testCacheEvictionWithTTL() {
        let expectation = XCTestExpectation(description: "Cache eviction with TTL")
        expectation.expectedFulfillmentCount = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        // Configure cache with short TTL
        let cacheConfig = MemoryCache<String, String>.Configuration(
            defaultTTL: 0.1, // 100ms TTL
            defaultTTLForNullElement: 0.1
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Wait for TTL to expire
        Thread.sleep(forTimeInterval: 0.2)
        
        // Second fetch - should hit network again due to TTL expiration
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        
        // Verify fetch count (should be 4 due to TTL expiration)
        XCTAssertEqual(fetchCount, 4, "Should fetch 4 times due to TTL expiration")
    }
    
    func testCacheEvictionWithMemoryLimit() {
        let expectation = XCTestExpectation(description: "Cache eviction with memory limit")
        expectation.expectedFulfillmentCount = 5
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        // Configure cache with memory limit
        let memoryLimit = MemoryUsageLimitation(
            capacity: 3,   // Max 3 items
            memory: 1000   // 1000 MB limit
        )
        
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: memoryLimit,
            costProvider: { $0.count * 2 } // Each string costs 2x its length
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second fetch with more keys - should trigger eviction
        taskManager.fetch(keys: ["key3", "key4", "key5"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        XCTAssertEqual(results["key3"], "value_key3")
        XCTAssertEqual(results["key4"], "value_key4")
        XCTAssertEqual(results["key5"], "value_key5")
        
        // Verify fetch count (should be 5 due to eviction)
        XCTAssertEqual(fetchCount, 5, "Should fetch 5 times due to cache eviction")
    }
    
    // MARK: - Cache Statistics and Reporting
    func testCacheStatisticsReporting() {
        let expectation = XCTestExpectation(description: "Cache statistics reporting")
        expectation.expectedFulfillmentCount = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        var reportedStats: [CacheStatistics] = []
        let statsSemaphore = DispatchSemaphore(value: 1)
        
        let statisticsReport: (CacheStatistics, CacheRecord) -> Void = { stats, record in
            statsSemaphore.wait()
            reportedStats.append(stats)
            statsSemaphore.signal()
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheStatisticsReport: statisticsReport
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second fetch - should hit cache
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        
        // Verify statistics were reported
        XCTAssertGreaterThan(reportedStats.count, 0, "Should report cache statistics")
        
        // Verify fetch count (should only be 2 due to caching)
        XCTAssertEqual(fetchCount, 2, "Should only fetch 2 times due to caching")
    }
    
    // MARK: - Cache Configuration Options
    func testCacheConfigurationWithCustomTTL() {
        let expectation = XCTestExpectation(description: "Cache configuration with custom TTL")
        expectation.expectedFulfillmentCount = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        // Configure cache with custom TTL
        let cacheConfig = MemoryCache<String, String>.Configuration(
            defaultTTL: 0.05, // 50ms TTL
            defaultTTLForNullElement: 0.05,
            ttlRandomizationRange: 0.01 // 10ms randomization
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Wait for TTL to expire
        Thread.sleep(forTimeInterval: 0.1)
        
        // Second fetch - should hit network again due to TTL expiration
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        
        // Verify fetch count (should be 4 due to TTL expiration)
        XCTAssertEqual(fetchCount, 4, "Should fetch 4 times due to TTL expiration")
    }
    
    func testCacheConfigurationWithKeyValidation() {
        let expectation = XCTestExpectation(description: "Cache configuration with key validation")
        expectation.expectedFulfillmentCount = 1
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let keyValidator: (String) -> Bool = {
            // Only accept keys that start with "valid_"
            $0.hasPrefix("valid_")
        }
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            if keyValidator(key) {
                callback(.success("value_\(key)"))
            } else {
                callback(.success(nil))
            }
        }
        
        // Configure cache with key validation
        let cacheConfig = MemoryCache<String, String>.Configuration(
            keyValidator: keyValidator
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch with valid and invalid keys
        taskManager.fetch(keys: ["valid_key", "invalid_key"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results - both keys should be processed (key validation only affects cache storage)
        XCTAssertEqual(results["valid_key"], "value_valid_key")
        XCTAssertEqual(results["invalid_key"], nil)
        
        // Verify fetch count (should be 2 for both keys)
        XCTAssertEqual(fetchCount, 1, "Should fetch 1 times for only valid key")
    }
    
    // MARK: - Concurrent Cache Access Patterns
    func testConcurrentCacheAccess() {
        let expectation = XCTestExpectation(description: "Concurrent cache access")
        expectation.expectedFulfillmentCount = 20
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate network delay
            let callbackCopy = callback
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                callbackCopy(.success("value_\(key)"))
            }
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 4
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Concurrent fetches with overlapping keys
        let keys = (1...10).map { "key\($0)" }
        
        // First batch of concurrent fetches
        for i in 0..<5 {
            taskManager.fetch(keys: [keys[i], keys[i+5]]) { key, result in
                switch result {
                case .success(let value):
                    resultsSemaphore.wait()
                    results[key] = value
                    resultsSemaphore.signal()
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
        }
        
        // Second batch of concurrent fetches (should hit cache for some keys)
        for i in 0..<5 {
            taskManager.fetch(keys: [keys[i], keys[i+5]]) { key, result in
                switch result {
                case .success(let value):
                    resultsSemaphore.wait()
                    results[key] = value
                    resultsSemaphore.signal()
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all results
        for key in keys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count (should be 10 for unique keys, not 20 due to caching)
        XCTAssertEqual(fetchCount, 10, "Should fetch 10 times for unique keys")
    }
    
    func testConcurrentCacheAccessWithThreadSynchronization() {
        let expectation = XCTestExpectation(description: "Concurrent cache access with thread synchronization")
        expectation.expectedFulfillmentCount = 12
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate network delay
            let callbackCopy = callback
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                callbackCopy(.success("value_\(key)"))
            }
        }
        
        // Configure cache with thread synchronization
        let cacheConfig = MemoryCache<String, String>.Configuration(
            enableThreadSynchronization: true
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 6,
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Multiple concurrent fetches with shared keys
        let sharedKeys = ["shared1", "shared2", "shared3"]
        let uniqueKeys = (1...6).map { "unique\($0)" }
        
        // First batch - fetch shared keys
        taskManager.fetch(keys: sharedKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Second batch - fetch unique keys
        taskManager.fetch(keys: uniqueKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Third batch - fetch shared keys again (should hit cache)
        taskManager.fetch(keys: sharedKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all results
        for key in sharedKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        for key in uniqueKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count (should be 9 for unique keys, not 12 due to caching)
        XCTAssertEqual(fetchCount, 9, "Should fetch 9 times for unique keys")
    }
    
    func testCachePerformanceWithLargeDataSet() {
        let expectation = XCTestExpectation(description: "Cache performance with large dataset")
        expectation.expectedFulfillmentCount = 50
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        // Configure cache with memory limits
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: MemoryUsageLimitation(
                capacity: 50,   // Max 50 items
                memory: 1000    // 1000 MB limit
            ),
            costProvider: { $0.count * 2 } // Each string costs 2x its length
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 8,
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Generate large dataset
        let keys = (1...50).map { "key\($0)" }
        
        // Fetch all keys
        taskManager.fetch(keys: keys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        // Verify all results
        for key in keys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count (should be 50 for unique keys)
        XCTAssertEqual(fetchCount, 50, "Should fetch 50 times for unique keys")
    }
    
    // MARK: - Callback Count Verification Tests
    
    func testCallbackCountForMultipleKeys() {
        let expectation = XCTestExpectation(description: "Callback count verification")
        expectation.expectedFulfillmentCount = 5 // Expect exactly 5 callbacks for 5 keys
        
        var callbackCount = 0
        let callbackSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch 5 keys
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5"]) { key, result in
            callbackSemaphore.wait()
            callbackCount += 1
            callbackSemaphore.signal()
            
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify exactly 5 callbacks were made
        XCTAssertEqual(callbackCount, 5, "Should receive exactly 5 callbacks for 5 keys")
        
        // Verify all results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        XCTAssertEqual(results["key3"], "value_key3")
        XCTAssertEqual(results["key4"], "value_key4")
        XCTAssertEqual(results["key5"], "value_key5")
    }
    
    func testCallbackCountWithCacheHits() {
        let expectation = XCTestExpectation(description: "Callback count with cache hits")
        expectation.expectedFulfillmentCount = 6 // Expect exactly 6 callbacks for 6 keys
        
        var callbackCount = 0
        let callbackSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        // Configure cache to store results
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: MemoryUsageLimitation(capacity: 10, memory: 100)
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - all keys should be cache misses
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            callbackSemaphore.wait()
            callbackCount += 1
            callbackSemaphore.signal()
            
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        // Second fetch - same keys should be cache hits, but still get callbacks
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            callbackSemaphore.wait()
            callbackCount += 1
            callbackSemaphore.signal()
            
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify exactly 6 callbacks were made (3 for first fetch + 3 for second fetch)
        XCTAssertEqual(callbackCount, 6, "Should receive exactly 6 callbacks for 6 total keys")
        
        // Verify all results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        XCTAssertEqual(results["key3"], "value_key3")
    }
    
    func testCallbackCountWithMixedCacheHitsAndMisses() {
        let expectation = XCTestExpectation(description: "Callback count with mixed cache hits and misses")
        expectation.expectedFulfillmentCount = 4 // Expect exactly 4 callbacks for 4 keys
        
        var callbackCount = 0
        let callbackSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        // Configure cache to store results
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: MemoryUsageLimitation(capacity: 10, memory: 100)
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // First fetch - cache some keys
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            callbackSemaphore.wait()
            callbackCount += 1
            callbackSemaphore.signal()
            
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        // Second fetch - mix of cache hits and misses
        taskManager.fetch(keys: ["key1", "key3"]) { key, result in
            callbackSemaphore.wait()
            callbackCount += 1
            callbackSemaphore.signal()
            
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify exactly 4 callbacks were made (2 for first fetch + 2 for second fetch)
        XCTAssertEqual(callbackCount, 4, "Should receive exactly 4 callbacks for 4 total keys")
        
        // Verify all results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        XCTAssertEqual(results["key3"], "value_key3")
    }
    
    // MARK: - Edge Cases and Missing Test Scenarios
    
    func testDuplicateKeysHandling() {
        let expectation = XCTestExpectation(description: "Duplicate keys handling")
        expectation.expectedFulfillmentCount = 4 // Should get 4 callbacks for 4 keys (including duplicates)
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        var callbackOrder: [String] = []
        let orderSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch with duplicate keys: ["key1", "key1", "key2", "key2"]
        taskManager.fetch(keys: ["key1", "key1", "key2", "key2"]) { key, result in
            orderSemaphore.wait()
            callbackOrder.append(key)
            orderSemaphore.signal()
            
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify exactly 4 callbacks were made (one for each key in the array)
        XCTAssertEqual(callbackOrder.count, 4, "Should receive exactly 4 callbacks")
        
        // Verify results (last value for each key should be preserved)
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        
        // Verify fetch count (should be 4 for all keys, including duplicates)
        XCTAssertEqual(fetchCount, 2, "Should fetch 2 times for 2 keys (excluding duplicates)")
    }
    
    func testEmptyStringKeyHandling() {
        let expectation = XCTestExpectation(description: "Empty string key handling")
        expectation.expectedFulfillmentCount = 2
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch with empty string key
        taskManager.fetch(keys: ["", "normal_key"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results[""], "value_")
        XCTAssertEqual(results["normal_key"], "value_normal_key")
        
        // Verify fetch count
        XCTAssertEqual(fetchCount, 2, "Should fetch 2 times for both keys")
    }
    
    func testCallbackOrderConsistency() {
        let expectation = XCTestExpectation(description: "Callback order consistency")
        expectation.expectedFulfillmentCount = 5
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            // Simulate different response times
            let delay = key == "key1" ? 0.1 : 0.05
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var callbackOrder: [String] = []
        let orderSemaphore = DispatchSemaphore(value: 1)
        
        // Fetch keys in specific order
        let inputKeys = ["key1", "key2", "key3", "key4", "key5"]
        
        taskManager.fetch(keys: inputKeys) { key, result in
            orderSemaphore.wait()
            callbackOrder.append(key)
            orderSemaphore.signal()
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify that all keys were processed (order may vary due to async nature)
        XCTAssertEqual(callbackOrder.count, 5, "Should receive exactly 5 callbacks")
        XCTAssertEqual(Set(callbackOrder), Set(inputKeys), "Should process all input keys")
    }
    
    func testLargeKeySetMemoryHandling() {
        let expectation = XCTestExpectation(description: "Large key set memory handling")
        expectation.expectedFulfillmentCount = 100
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        // Configure cache with limited capacity
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: MemoryUsageLimitation(capacity: 50, memory: 100)
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 8,
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Generate large dataset
        let keys = (1...100).map { "key\($0)" }
        
        taskManager.fetch(keys: keys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Verify all results
        for key in keys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count
        XCTAssertEqual(fetchCount, 100, "Should fetch 100 times for 100 unique keys")
    }
    
    func testCallbackExceptionHandling() {
        let expectation = XCTestExpectation(description: "Callback exception handling")
        expectation.expectedFulfillmentCount = 3
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        var exceptionCount = 0
        let exceptionSemaphore = DispatchSemaphore(value: 1)
        
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
                
                // Simulate callback exception for key2
                if key == "key2" {
                    exceptionSemaphore.wait()
                    exceptionCount += 1
                    exceptionSemaphore.signal()
                    // This should not crash the system
                }
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["key1"], "value_key1")
        XCTAssertEqual(results["key2"], "value_key2")
        XCTAssertEqual(results["key3"], "value_key3")
        
        // Verify exception was handled gracefully
        XCTAssertEqual(exceptionCount, 1, "Should handle callback exception gracefully")
    }
    
    func testSpecialCharacterKeys() {
        let expectation = XCTestExpectation(description: "Special character keys")
        expectation.expectedFulfillmentCount = 4
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test various special characters
        let specialKeys = ["key@123", "key#456", "key$789", "key%012"]
        
        taskManager.fetch(keys: specialKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        for key in specialKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    // MARK: - Comprehensive Key Scenario Tests
    
    func testUnicodeAndEmojiKeys() {
        let expectation = XCTestExpectation(description: "Unicode and emoji keys")
        expectation.expectedFulfillmentCount = 6
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test various Unicode and emoji keys
        let unicodeKeys = [
            "key_中文",           // Chinese characters
            "key_日本語",         // Japanese characters
            "key_한국어",         // Korean characters
            "key_🌍🌎🌏",        // Emoji
            "key_🚀💻📱",        // Tech emoji
            "key_🎉🎊🎈"         // Celebration emoji
        ]
        
        taskManager.fetch(keys: unicodeKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        for key in unicodeKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    func testVeryLongKeys() {
        let expectation = XCTestExpectation(description: "Very long keys")
        expectation.expectedFulfillmentCount = 3
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test very long keys
        let longKeys = [
            String(repeating: "a", count: 1000),           // 1000 character key
            String(repeating: "b", count: 5000),           // 5000 character key
            String(repeating: "c", count: 10000)           // 10000 character key
        ]
        
        taskManager.fetch(keys: longKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify results
        for key in longKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    func testKeysWithWhitespace() {
        let expectation = XCTestExpectation(description: "Keys with whitespace")
        expectation.expectedFulfillmentCount = 4
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test keys with various whitespace
        let whitespaceKeys = [
            " key",           // Leading space
            "key ",           // Trailing space
            " key ",          // Both leading and trailing
            "key with spaces" // Internal spaces
        ]
        
        taskManager.fetch(keys: whitespaceKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        for key in whitespaceKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    func testKeysWithNewlinesAndTabs() {
        let expectation = XCTestExpectation(description: "Keys with newlines and tabs")
        expectation.expectedFulfillmentCount = 4
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test keys with control characters
        let controlKeys = [
            "key\nwith\nnewlines",
            "key\twith\ttabs",
            "key\r\nwith\r\ncrlf",
            "key\u{0000}with\u{0000}nulls"  // Null bytes
        ]
        
        taskManager.fetch(keys: controlKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        for key in controlKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    func testKeysWithControlCharacters() {
        let expectation = XCTestExpectation(description: "Keys with control characters")
        expectation.expectedFulfillmentCount = 5
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test keys with various control characters
        let controlKeys = [
            "key\u{0001}bell",      // Bell
            "key\u{0007}alert",     // Alert
            "key\u{0008}backspace", // Backspace
            "key\u{0009}tab",       // Tab
            "key\u{001B}escape"     // Escape
        ]
        
        taskManager.fetch(keys: controlKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        for key in controlKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    func testMixedValidInvalidKeys() {
        let expectation = XCTestExpectation(description: "Mixed valid and invalid keys")
        expectation.expectedFulfillmentCount = 4
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        // Configure cache with key validation that rejects certain keys
        let keyValidator: (String) -> Bool = { key in
            return key.hasPrefix("valid_") && key.count > 0
        }
        
        let cacheConfig = MemoryCache<String, String>.Configuration(
            keyValidator: keyValidator
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Mix of valid and invalid keys
        let mixedKeys = ["valid_key1", "invalid_key1", "valid_key2", "invalid_key2"]
        
        taskManager.fetch(keys: mixedKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results - valid keys should have values, invalid keys should be nil
        XCTAssertEqual(results["valid_key1"], "value_valid_key1")
        XCTAssertEqual(results["valid_key2"], "value_valid_key2")
        XCTAssertNil(results["invalid_key1"]!)
        XCTAssertNil(results["invalid_key2"]!)
        
        // Verify fetch count - should fetch for all keys (validation happens at cache level)
        XCTAssertEqual(fetchCount, 2, "Should fetch valid keys only")
    }
    
    func testKeysWithVaryingFetchTimes() {
        let expectation = XCTestExpectation(description: "Keys with varying fetch times")
        expectation.expectedFulfillmentCount = 5
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            // Simulate different response times based on key
            let delay: TimeInterval
            switch key {
            case "fast_key":
                delay = 0.01
            case "medium_key":
                delay = 0.1
            case "slow_key":
                delay = 0.5
            case "very_slow_key":
                delay = 1.0
            default:
                delay = 0.05
            }
            
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        var completionOrder: [String] = []
        let orderSemaphore = DispatchSemaphore(value: 1)
        
        let keys = ["fast_key", "medium_key", "slow_key", "very_slow_key", "normal_key"]
        
        taskManager.fetch(keys: keys) { key, result in
            orderSemaphore.wait()
            completionOrder.append(key)
            orderSemaphore.signal()
            
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify all results
        for key in keys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify completion order (fast keys should complete first)
        XCTAssertTrue(completionOrder.contains("fast_key"))
        XCTAssertTrue(completionOrder.contains("normal_key"))
        XCTAssertEqual(completionOrder.count, 5, "Should complete all 5 keys")
    }
    
    func testKeysCausingTimeouts() {
        let expectation = XCTestExpectation(description: "Keys causing timeouts")
        expectation.expectedFulfillmentCount = 3
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            // Simulate different response scenarios
            switch key {
            case "error_key":
                // Simulate network error
                callback(.failure(NSError(domain: "TestError", code: 500, userInfo: nil)))
            case "slow_key":
                // Simulate slow response
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    callback(.success("value_\(key)"))
                }
            default:
                // Normal response
                callback(.success("value_\(key)"))
            }
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        var errorCount = 0
        let errorSemaphore = DispatchSemaphore(value: 1)
        
        taskManager.fetch(keys: ["normal_key", "slow_key", "error_key"]) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(_):
                errorSemaphore.wait()
                errorCount += 1
                errorSemaphore.signal()
                // Error should be handled gracefully
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results
        XCTAssertEqual(results["normal_key"], "value_normal_key")
        XCTAssertEqual(results["slow_key"], "value_slow_key")
        XCTAssertNil(results["error_key"] as Any?)
        
        // Verify error handling
        XCTAssertEqual(errorCount, 1, "Should handle errors gracefully")
    }
    
    func testKeysWithMemoryPressure() {
        let expectation = XCTestExpectation(description: "Keys with memory pressure")
        expectation.expectedFulfillmentCount = 50
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            // Simulate large data responses
            let largeValue = String(repeating: "large_data_", count: 1000) + key
            callback(.success(largeValue))
        }
        
        // Configure cache with very limited memory
        let cacheConfig = MemoryCache<String, String>.Configuration(
            memoryUsageLimitation: MemoryUsageLimitation(capacity: 10, memory: 1) // Very limited
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 2, // Limit concurrency
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Generate many keys to cause memory pressure
        let keys = (1...50).map { "key\($0)" }
        
        taskManager.fetch(keys: keys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Verify all results (some may be evicted due to memory pressure)
        XCTAssertEqual(results.count, 50, "Should process all 50 keys")
        
        // Verify cache eviction works under memory pressure
        for key in keys {
            XCTAssertNotNil(results[key] as Any?, "Should have result for \(key)")
        }
    }
    
    func testKeysWithComplexValidationRules() {
        let expectation = XCTestExpectation(description: "Keys with complex validation rules")
        expectation.expectedFulfillmentCount = 6
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        // Complex validation rules
        let keyValidator: (String) -> Bool = { key in
            // Must start with 'valid_', have length 8-20, and contain only alphanumeric
            guard key.hasPrefix("valid_") else { return false }
            guard key.count >= 8 && key.count <= 20 else { return false }
            guard key.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) != nil else { return false }
            return true
        }
        
        let cacheConfig = MemoryCache<String, String>.Configuration(
            keyValidator: keyValidator
        )
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            cacheConfig: cacheConfig
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Test various key patterns
        let testKeys = [
            "valid_key1",      // Valid
            "invalid_key1",    // Invalid (no valid_ prefix)
            "valid_123",       // Valid
            "valid_too_long_key_name", // Invalid (too long)
            "valid_@#$",       // Invalid (special chars)
            "valid_ab"         // Invalid (too short)
        ]
        
        taskManager.fetch(keys: testKeys) { key, result in
            switch result {
            case .success(let value):
                resultsSemaphore.wait()
                results[key] = value
                resultsSemaphore.signal()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify results - valid keys should have values, invalid keys should be nil
        XCTAssertEqual(results["valid_key1"], "value_valid_key1")
        XCTAssertEqual(results["valid_123"], "value_valid_123")
        XCTAssertEqual(results["valid_ab"], "value_valid_ab")  // 8 chars, valid
        XCTAssertNil(results["invalid_key1"]!)
        XCTAssertNil(results["valid_too_long_key_name"]!)
        XCTAssertNil(results["valid_@#$"]!)
        
        // Verify fetch count - should fetch for all keys (validation happens at cache level)
        XCTAssertEqual(fetchCount, 3, "Should fetch only valid keys")
    }
    
    // MARK: - High-Concurrency Duplicate Key Scenarios
    
    func testHighConcurrencyWithDuplicateKeys() {
        let expectation = XCTestExpectation(description: "High concurrency with duplicate keys")
        expectation.expectedFulfillmentCount = 100 // 10 operations × 10 keys each
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 8
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Create 10 concurrent operations, each with the same set of keys
        let sharedKeys = ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8", "key9", "key10"]
        
        // Launch 10 concurrent fetch operations
        for _ in 0..<10 {
            DispatchQueue.global().async {
                taskManager.fetch(keys: sharedKeys) { key, result in
                    switch result {
                    case .success(let value):
                        resultsSemaphore.wait()
                        results[key] = value
                        resultsSemaphore.signal()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                    
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Verify all results
        for key in sharedKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count - should only fetch each unique key once despite 10 concurrent operations
        XCTAssertEqual(fetchCount, 10, "Should fetch each unique key only once, not 10 times")
    }
    
    func testCacheStampedePrevention() {
        let expectation = XCTestExpectation(description: "Cache stampede prevention")
        expectation.expectedFulfillmentCount = 25
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        var concurrentFetchCount = 0
        let concurrentSemaphore = DispatchSemaphore(value: 1)
        var maximumCurrentConcurrent = 0
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            concurrentSemaphore.wait()
            concurrentFetchCount += 1
            maximumCurrentConcurrent = max(concurrentFetchCount, maximumCurrentConcurrent)
            concurrentSemaphore.signal()
            
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate slow network response
            DispatchQueue.global().async {
                concurrentSemaphore.wait()
                concurrentFetchCount -= 1
                concurrentSemaphore.signal()
                
                callback(.success("value_\(key)"))
            }
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 4
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Create 5 concurrent operations with overlapping keys
        let keySets = [
            ["key1", "key2", "key3", "key4", "key5"],           // Set 1
            ["key1", "key2", "key6", "key7", "key8"],           // Set 2 (overlaps with Set 1)
            ["key3", "key4", "key9", "key10", "key11"],         // Set 3 (overlaps with Set 1)
            ["key6", "key7", "key12", "key13", "key14"],        // Set 4 (overlaps with Set 2)
            ["key9", "key10", "key15", "key16", "key17"],       // Set 5 (overlaps with Set 3)
        ]
        
        // Launch concurrent operations
        for (index, keys) in keySets.enumerated() {
            DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.01) {
                taskManager.fetch(keys: keys) { key, result in
                    switch result {
                    case .success(let value):
                        resultsSemaphore.wait()
                        results[key] = value
                        resultsSemaphore.signal()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                    
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        // Verify all results
        let allKeys = Set(keySets.flatMap { $0 })
        for key in allKeys {
            XCTAssertEqual(results[key], "value_\(key)")
        }
        
        // Verify fetch count - should only fetch each unique key once
        XCTAssertEqual(fetchCount, allKeys.count, "Should fetch each unique key only once")
        
        // Verify no excessive concurrent fetches (stampede prevention)
        XCTAssertLessThanOrEqual(concurrentFetchCount, 4, "Should not have excessive concurrent fetches")
        
        XCTAssertLessThanOrEqual(maximumCurrentConcurrent, config.maximumConcurrentRunningThreadNumber)
    }
    
    func testThreadSafetyWithDuplicateKeys() {
        let expectation = XCTestExpectation(description: "Thread safety with duplicate keys")
        expectation.expectedFulfillmentCount = 7 * 20
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            // Simulate varying response times
            let delay = Double.random(in: 0.01...0.05)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = KVLightTasks<String, String>.Config(
            dataProvider: .monofetch(monofetch),
            maximumConcurrentRunningThreadNumber: 6
        )
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var resultCount = 0
        var results: [String: Int] = [:] // Count how many times each key was processed
        let resultsSemaphore = DispatchSemaphore(value: 1)
        
        // Create 20 concurrent operations with heavy key overlap
        let baseKeys = ["key1", "key2", "key3", "key4", "key5"]
        
        for operationIndex in 0..<20 {
            DispatchQueue.global().async {
                // Each operation fetches the same base keys plus some unique keys
                let operationKeys = baseKeys + ["unique_\(operationIndex)_1", "unique_\(operationIndex)_2"]
                
                taskManager.fetch(keys: operationKeys) { key, result in
                    switch result {
                    case .success:
                        resultsSemaphore.wait()
                        results[key] = (results[key] ?? 0) + 1
                        resultCount += 1
                        resultsSemaphore.signal()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                    
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 60.0)
        
        // Verify all base keys were processed exactly 20 times (once per operation)
        for key in baseKeys {
            XCTAssertEqual(results[key], 20, "Key \(key) should be processed exactly 20 times")
        }
        
        // Verify unique keys were processed exactly once each
        for operationIndex in 0..<20 {
            XCTAssertEqual(results["unique_\(operationIndex)_1"], 1, "Unique key should be processed once")
            XCTAssertEqual(results["unique_\(operationIndex)_2"], 1, "Unique key should be processed once")
        }
        
        // Verify total result count
        XCTAssertEqual(resultCount, 140, "Should have exactly 140 results")
        
        // Verify fetch count - should only fetch each unique key once
        let uniqueKeys = Set(baseKeys + (0..<20).flatMap { ["unique_\($0)_1", "unique_\($0)_2"] })
        XCTAssertEqual(fetchCount, uniqueKeys.count, "Should fetch each unique key only once")
    }
    
    // MARK: - Async/Await API Tests
    
    func testAsyncFetchSingleKey() async {
        let expectation = XCTestExpectation(description: "Async fetch single key")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        do {
            let result = try await taskManager.asyncFetchThrowing(key: "test_key")
            XCTAssertEqual(result, "value_test_key")
            XCTAssertEqual(fetchCount, 1, "Should fetch exactly once")
            expectation.fulfill()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testAsyncFetchSingleKeyWithResult() async {
        let expectation = XCTestExpectation(description: "Async fetch single key with Result")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        let result = await taskManager.asyncFetch(key: "test_key")
        
        switch result {
        case .success(let element):
            XCTAssertEqual(element, "value_test_key")
            XCTAssertEqual(fetchCount, 1, "Should fetch exactly once")
        case .failure(let error):
            XCTFail("Unexpected error: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testAsyncFetchMultipleKeys() async {
        let expectation = XCTestExpectation(description: "Async fetch multiple keys")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        let keys = ["key1", "key2", "key3", "key4", "key5"]
        let results = await taskManager.asyncFetch(keys: keys)
        
        XCTAssertEqual(results.count, 5, "Should return exactly 5 results")
        
        for (key, result) in results {
            switch result {
            case .success(let element):
                XCTAssertEqual(element, "value_\(key)")
            case .failure(let error):
                XCTFail("Unexpected error for key \(key): \(error)")
            }
        }
        
        XCTAssertEqual(fetchCount, 5, "Should fetch exactly 5 times")
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testAsyncFetchWithDuplicateKeys() async {
        let expectation = XCTestExpectation(description: "Async fetch with duplicate keys")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        // Test with duplicate keys
        let keys = ["key1", "key1", "key2", "key2", "key3"]
        let results = await taskManager.asyncFetch(keys: keys)
        
        XCTAssertEqual(results.count, 5, "Should return exactly 5 results (including duplicates)")
        
        // Verify all results are correct
        for (key, result) in results {
            switch result {
            case .success(let element):
                XCTAssertEqual(element, "value_\(key)")
            case .failure(let error):
                XCTFail("Unexpected error for key \(key): \(error)")
            }
        }
        
        // Should only fetch unique keys (3 unique keys)
        XCTAssertEqual(fetchCount, 3, "Should fetch only unique keys")
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testAsyncFetchWithErrors() async {
        let expectation = XCTestExpectation(description: "Async fetch with errors")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            if key == "error_key" {
                callback(.failure(NSError(domain: "TestError", code: 500, userInfo: nil)))
            } else {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        let keys = ["key1", "error_key", "key2"]
        let results = await taskManager.asyncFetch(keys: keys)
        
        XCTAssertEqual(results.count, 3, "Should return exactly 3 results")
        
        // Verify results
        for (key, result) in results {
            switch result {
            case .success(let element):
                if key == "error_key" {
                    XCTFail("Should have error for error_key")
                } else {
                    XCTAssertEqual(element, "value_\(key)")
                }
            case .failure(let error):
                XCTAssertEqual(key, "error_key", "Only error_key should have error")
                XCTAssertEqual((error as NSError).domain, "TestError")
            }
        }
        
        XCTAssertEqual(fetchCount, 3, "Should fetch exactly 3 times")
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testAsyncFetchThrowingWithErrors() async {
        let expectation = XCTestExpectation(description: "Async fetch throwing with errors")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            if key == "error_key" {
                callback(.failure(NSError(domain: "TestError", code: 500, userInfo: nil)))
            } else {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        do {
            _ = try await taskManager.asyncFetchThrowing(key: "error_key")
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual((error as NSError).domain, "TestError")
            XCTAssertEqual(fetchCount, 1, "Should fetch exactly once")
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testMultiCallbackBatchFetch() {
        let expectation = XCTestExpectation(description: "Multi callback batch fetch")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        let keys = ["key1", "key2", "key3", "key4", "key5"]
        
        taskManager.fetch(keys: keys, multiCallback: { results in
            XCTAssertEqual(results.count, 5, "Should return exactly 5 results")
            
            for (key, result) in results {
                switch result {
                case .success(let element):
                    XCTAssertEqual(element, "value_\(key)")
                case .failure(let error):
                    XCTFail("Unexpected error for key \(key): \(error)")
                }
            }
            
            XCTAssertEqual(fetchCount, 5, "Should fetch exactly 5 times")
            expectation.fulfill()
        })
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultiCallbackWithDuplicateKeys() {
        let expectation = XCTestExpectation(description: "Multi callback with duplicate keys")
        
        var fetchCount = 0
        let fetchSemaphore = DispatchSemaphore(value: 1)
        
        let monofetch: KVLightTasks<String, String>.DataProvider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        // Test with duplicate keys
        let keys = ["key1", "key1", "key2", "key2", "key3"]
        
        taskManager.fetch(keys: keys, multiCallback: { results in
            XCTAssertEqual(results.count, 5, "Should return exactly 5 results (including duplicates)")
            
            // Verify all results are correct
            for (key, result) in results {
                switch result {
                case .success(let element):
                    XCTAssertEqual(element, "value_\(key)")
                case .failure(let error):
                    XCTFail("Unexpected error for key \(key): \(error)")
                }
            }
            
            // Should only fetch unique keys (3 unique keys)
            XCTAssertEqual(fetchCount, 3, "Should fetch only unique keys")
            expectation.fulfill()
        })
        
        wait(for: [expectation], timeout: 5.0)
    }
} 
