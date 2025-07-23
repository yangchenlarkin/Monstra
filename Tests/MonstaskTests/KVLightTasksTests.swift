//
//  KVLightTasksTests.swift
//  MonstaskTests
//
//  Created by Test Generator on 2025/1/27.
//

import XCTest
@testable import Monstask
@testable import MonstraBase

final class KVLightTasksTests: XCTestCase {
    
    // MARK: - Test Configuration
    private func createConfig(
        dataProvider: KVLightTasks<String, String>.DataPovider
    ) -> KVLightTasks<String, String>.Config {
        return KVLightTasks<String, String>.Config(dataProvider: dataProvider)
    }
}

// MARK: - Monofetch Tests
extension KVLightTasksTests {
    func testMonofetchBasicFunctionality() {
        let expectation = XCTestExpectation(description: "Monofetch basic functionality")
        expectation.expectedFulfillmentCount = 3
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        taskManager.fetch(keys: ["key1", "key2", "key3"]) { key, result in
            switch result {
            case .success(let value):
                results[key] = value
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
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
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
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            if key == "error_key" {
                callback(.failure(testError))
            } else {
                callback(.success("value_\(key)"))
            }
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: Result<String?, Error>] = [:]
        
        taskManager.fetch(keys: ["key1", "error_key"]) { key, result in
            results[key] = result
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
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
            fetchSemaphore.wait()
            fetchCount += 1
            fetchSemaphore.signal()
            
            callback(.success("value_\(key)"))
        }
        
        let config = createConfig(dataProvider: .monofetch(monofetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var firstFetchResults: [String: String?] = [:]
        var secondFetchResults: [String: String?] = [:]
        
        // First fetch - should hit network
        taskManager.fetch(keys: ["key1", "key2"]) { key, result in
            switch result {
            case .success(let value):
                firstFetchResults[key] = value
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
            
            // Start second fetch after first fetch completes
            if firstFetchResults.count == 2 {
                // Second fetch - should hit cache
                taskManager.fetch(keys: ["key1", "key2"]) { key, result in
                    switch result {
                    case .success(let value):
                        secondFetchResults[key] = value
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
        
        let monofetch: KVLightTasks<String, String>.DataPovider.Monofetch = { key, callback in
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

// MARK: - Multifetch Tests
extension KVLightTasksTests {
    func testMultifetchBasicFunctionality() {
        let expectation = XCTestExpectation(description: "Multifetch basic functionality")
        expectation.expectedFulfillmentCount = 6
        
        let multifetch: KVLightTasks<String, String>.DataPovider.Multifetch = { keys, callback in
            var results: [String: String?] = [:]
            for key in keys {
                results[key] = "value_\(key)"
            }
            callback(.success(results))
        }
        
        let config = createConfig(dataProvider: .multifetch(maxmumBatchCount: 3, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6"]) { key, result in
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
        for key in ["key1", "key2", "key3", "key4", "key5", "key6"] {
            XCTAssertEqual(results[key], "value_\(key)")
        }
    }
    
    func testMultifetchBatchProcessingModNonZero() {
        let expectation = XCTestExpectation(description: "Multifetch batch processing")
        expectation.expectedFulfillmentCount = 8
        
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
        
        let config = createConfig(dataProvider: .multifetch(maxmumBatchCount: 3, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // Fetch 8 keys, should be processed in 3 batches (3, 3, 2)
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"]) { key, result in
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
        
        let config = createConfig(dataProvider: .multifetch(maxmumBatchCount: 3, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // Fetch 8 keys, should be processed in 3 batches (3, 3, 2)
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8", "key9"]) { key, result in
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
        
        let config = createConfig(dataProvider: .multifetch(maxmumBatchCount: 100, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: String?] = [:]
        
        // Fetch 8 keys, should be processed in 3 batches (3, 3, 2)
        taskManager.fetch(keys: ["key1", "key2", "key3", "key4", "key5", "key6", "key7", "key8"]) { key, result in
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
        
        let multifetch: KVLightTasks<String, String>.DataPovider.Multifetch = { keys, callback in
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
        
        let config = createConfig(dataProvider: .multifetch(maxmumBatchCount: 2, multifetch))
        let taskManager = KVLightTasks<String, String>(config: config)
        
        var results: [String: Result<String?, Error>] = [:]
        
        // Test with keys that will be in different batches
        taskManager.fetch(keys: ["key1", "error_key"]) { key, result in
            results[key] = result
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
        
        let multifetch: KVLightTasks<String, String>.DataPovider.Multifetch = { keys, callback in
            XCTFail("Should not be called with empty key set")
        }
        
        let config = createConfig(dataProvider: .multifetch(maxmumBatchCount: 3, multifetch))
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
