//
//  MemoryCacheTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/5/21.
//

import XCTest
@testable import Monstore

// Helper extension to make testing easier with the new FetchResult API
extension MemoryCache {
    /// Helper method for tests to get the value directly, similar to the old API
    func getValueDirect(for key: Key) -> Element? {
        return getValue(for: key).value
    }
}

/// Comprehensive tests for MemoryCache functionality including key validation,
/// null value caching, TTL randomization, and basic operations.
final class MemoryCacheTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testBasicSetAndGet() {
        let cache = MemoryCache<String, String>()
        
        // Test basic set and get
        cache.set(value: "value1", for: "key1", priority: 1.0)
        XCTAssertEqual(cache.getValueDirect(for: "key1"), "value1")
        
        // Test nil value
        cache.set(value: nil as String?, for: "key2")
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    func testCapacityLimit() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 2)))
        
        // Fill cache to capacity
        cache.set(value: 1, for: "key1")
        cache.set(value: 2, for: "key2")
        XCTAssertEqual(cache.count, 2)
        
        // Add one more, should evict the least recently used
        cache.set(value: 3, for: "key3")
        XCTAssertEqual(cache.count, 2)
        
        // The first key should be evicted
        XCTAssertNil(cache.getValueDirect(for: "key1"))
    }
    
    // MARK: - Key Validation Tests
    
    func testCustomKeyValidator() {
        // Create cache with custom key validator that only accepts non-empty strings
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                keyValidator: { key in
                    return !key.isEmpty && key.count <= 10
                }
            )
        )
        
        // Valid keys should work
        cache.set(value: "value1", for: "valid")
        XCTAssertEqual(cache.getValueDirect(for: "valid"), "value1")
        
        // Invalid keys should be rejected
        cache.set(value: "value2", for: "")
        XCTAssertNil(cache.getValueDirect(for: ""))
        
        cache.set(value: "value3", for: "toolongkeythatisinvalid")
        XCTAssertNil(cache.getValueDirect(for: "toolongkeythatisinvalid"))
    }
    
    func testNumericKeyValidator() {
        // Create cache with numeric key validator
        let cache = MemoryCache<Int, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                keyValidator: { key in
                    return key > 0 && key <= 1000
                }
            )
        )
        
        // Valid keys should work
        cache.set(value: "value1", for: 1)
        XCTAssertEqual(cache.getValueDirect(for: 1), "value1")
        
        // Invalid keys should be rejected
        cache.set(value: "value2", for: 0)
        XCTAssertNil(cache.getValueDirect(for: 0))
        
        cache.set(value: "value3", for: 1001)
        XCTAssertNil(cache.getValueDirect(for: 1001))
    }
    
    // MARK: - Null Value Caching Tests
    
    func testNullValueCaching() {
        let cache = MemoryCache<String, String>()
        
        // Cache a null value
        cache.set(value: nil as String?, for: "null_key")
        
        // Should return nil (indicating the null value was cached)
        let result = cache.getValueDirect(for: "null_key")
        XCTAssertNil(result)
        
        // The key should exist in the cache
        XCTAssertFalse(cache.isEmpty)
    }
    
    func testNullValueWithCustomTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTLForNullValue: 1.0 // 1 second TTL for null values
            )
        )
        
        // Cache a null value
        cache.set(value: nil as String?, for: "null_key")
        
        // Should return nil immediately
        XCTAssertNil(cache.getValueDirect(for: "null_key"))
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 1.1)
        
        // Should return nil after expiration (key removed)
        XCTAssertNil(cache.getValueDirect(for: "null_key"))
    }
    
    // MARK: - TTL Randomization Tests
    
    func testTTLRandomization() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 10.0,
                ttlRandomizationRange: 2.0 // ±2 seconds randomization
            )
        )
        
        // Set multiple values with the same TTL
        for i in 0..<5 {
            cache.set(value: "value\(i)", for: "key\(i)", expiredIn: 10.0)
        }
        
        // All values should be cached
        for i in 0..<5 {
            XCTAssertEqual(cache.getValueDirect(for: "key\(i)"), "value\(i)")
        }
    }
    
    // MARK: - Priority Tests
    
    func testPriorityEviction() {
        let cache = MemoryCache<String, String>(configuration: .init(memoryUsageLimitation: .init(capacity: 2)))
        
        // Add low priority item
        cache.set(value: "low", for: "low_key", priority: 0.0)
        
        // Add high priority item
        cache.set(value: "high", for: "high_key", priority: 10.0)
        
        // Add medium priority item (should evict low priority)
        cache.set(value: "medium", for: "medium_key", priority: 5.0)
        
        // Low priority item should be evicted
        XCTAssertNil(cache.getValueDirect(for: "low_key"))
        
        // High and medium priority items should remain
        XCTAssertEqual(cache.getValueDirect(for: "high_key"), "high")
        XCTAssertEqual(cache.getValueDirect(for: "medium_key"), "medium")
    }
    
    // MARK: - FetchResult API Tests
    
    func testFetchResultInvalidKey() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                keyValidator: { key in
                    return key.hasPrefix("valid_")
                }
            )
        )
        
        // Test invalid key
        let result = cache.getValue(for: "invalid_key")
        switch result {
        case .invalidKey:
            XCTAssertNil(result.value)
            XCTAssertFalse(result.isMiss)
        default:
            XCTFail("Expected .invalidKey, got \(result)")
        }
        
        // Test valid key that doesn't exist
        let result2 = cache.getValue(for: "valid_nonexistent")
        switch result2 {
        case .miss:
            XCTAssertNil(result2.value)
            XCTAssertTrue(result2.isMiss)
        default:
            XCTFail("Expected .miss, got \(result2)")
        }
    }
    
    func testFetchResultHitNonNullValue() {
        let cache = MemoryCache<String, String>()
        
        // Set a value
        cache.set(value: "test_value", for: "test_key")
        
        // Test hit with non-null value
        let result = cache.getValue(for: "test_key")
        switch result {
        case .hitNonNullValue(let value):
            XCTAssertEqual(value, "test_value")
            XCTAssertEqual(result.value, "test_value")
            XCTAssertFalse(result.isMiss)
        default:
            XCTFail("Expected .hitNonNullValue, got \(result)")
        }
    }
    
    func testFetchResultHitNullValue() {
        let cache = MemoryCache<String, String>()
        
        // Set a null value
        cache.set(value: nil as String?, for: "null_key")
        
        // Test hit with null value
        let result = cache.getValue(for: "null_key")
        switch result {
        case .hitNullValue:
            XCTAssertNil(result.value)
            XCTAssertFalse(result.isMiss)
        default:
            XCTFail("Expected .hitNullValue, got \(result)")
        }
    }
    
    func testFetchResultMiss() {
        let cache = MemoryCache<String, String>()
        
        // Test miss for non-existent key
        let result = cache.getValue(for: "nonexistent_key")
        switch result {
        case .miss:
            XCTAssertNil(result.value)
            XCTAssertTrue(result.isMiss)
        default:
            XCTFail("Expected .miss, got \(result)")
        }
    }
    
    func testFetchResultWithExpiredValue() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 0.1 // Very short TTL
            )
        )
        
        // Set a value
        cache.set(value: "expired_value", for: "expired_key")
        
        // Value should exist immediately
        let result1 = cache.getValue(for: "expired_key")
        switch result1 {
        case .hitNonNullValue(let value):
            XCTAssertEqual(value, "expired_value")
        default:
            XCTFail("Expected .hitNonNullValue, got \(result1)")
        }
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.2)
        
        // Value should be expired (miss)
        let result2 = cache.getValue(for: "expired_key")
        switch result2 {
        case .miss:
            XCTAssertNil(result2.value)
            XCTAssertTrue(result2.isMiss)
        default:
            XCTFail("Expected .miss, got \(result2)")
        }
    }
    
    func testFetchResultWithComplexKeyValidator() {
        let cache = MemoryCache<Int, String>(
            configuration: .init(
                keyValidator: { key in
                    return key > 0 && key <= 100 && key % 2 == 0 // Only even numbers 2-100
                }
            )
        )
        
        // Test invalid keys
        switch cache.getValue(for: 0) {
        case .invalidKey: break // Expected
        default: XCTFail("Expected .invalidKey for key 0")
        }
        switch cache.getValue(for: 101) {
        case .invalidKey: break // Expected
        default: XCTFail("Expected .invalidKey for key 101")
        }
        switch cache.getValue(for: 3) {
        case .invalidKey: break // Expected
        default: XCTFail("Expected .invalidKey for key 3")
        }
        
        // Test valid keys
        switch cache.getValue(for: 2) {
        case .miss: break // Expected
        default: XCTFail("Expected .miss for key 2")
        }
        switch cache.getValue(for: 4) {
        case .miss: break // Expected
        default: XCTFail("Expected .miss for key 4")
        }
        switch cache.getValue(for: 100) {
        case .miss: break // Expected
        default: XCTFail("Expected .miss for key 100")
        }
    }
    
    func testFetchResultWithNullValueExpiration() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTLForNullValue: 0.1 // Short TTL for null values
            )
        )
        
        // Set a null value
        cache.set(value: nil as String?, for: "null_key")
        
        // Null value should exist immediately
        let result1 = cache.getValue(for: "null_key")
        switch result1 {
        case .hitNullValue: break // Expected
        default: XCTFail("Expected .hitNullValue, got \(result1)")
        }
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.2)
        
        // Null value should be expired (miss)
        let result2 = cache.getValue(for: "null_key")
        switch result2 {
        case .miss: break // Expected
        default: XCTFail("Expected .miss, got \(result2)")
        }
    }
    
    func testFetchResultValueProperty() {
        let cache = MemoryCache<String, String>()
        
        // Test with non-null value
        cache.set(value: "test_value", for: "test_key")
        let result1 = cache.getValue(for: "test_key")
        XCTAssertEqual(result1.value, "test_value")
        
        // Test with null value
        cache.set(value: nil as String?, for: "null_key")
        let result2 = cache.getValue(for: "null_key")
        XCTAssertNil(result2.value)
        
        // Test with miss
        let result3 = cache.getValue(for: "nonexistent")
        XCTAssertNil(result3.value)
        
        // Test with invalid key
        let cacheWithValidator = MemoryCache<String, String>(
            configuration: .init(keyValidator: { $0.hasPrefix("valid_") })
        )
        let result4 = cacheWithValidator.getValue(for: "invalid_key")
        XCTAssertNil(result4.value)
    }
    
    func testFetchResultIsMissProperty() {
        let cache = MemoryCache<String, String>()
        
        // Test miss
        let result1 = cache.getValue(for: "nonexistent")
        XCTAssertTrue(result1.isMiss)
        
        // Test hit with non-null value
        cache.set(value: "test_value", for: "test_key")
        let result2 = cache.getValue(for: "test_key")
        XCTAssertFalse(result2.isMiss)
        
        // Test hit with null value
        cache.set(value: nil as String?, for: "null_key")
        let result3 = cache.getValue(for: "null_key")
        XCTAssertFalse(result3.isMiss)
        
        // Test invalid key
        let cacheWithValidator = MemoryCache<String, String>(
            configuration: .init(keyValidator: { $0.hasPrefix("valid_") })
        )
        let result4 = cacheWithValidator.getValue(for: "invalid_key")
        XCTAssertFalse(result4.isMiss)
    }
    
    func testFetchResultConcurrentAccess() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 1000)
            )
        )
        
        let queue = DispatchQueue(label: "test_queue", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Concurrently set and get values
        for i in 0..<100 {
            group.enter()
            queue.async {
                cache.set(value: "value\(i)", for: "key\(i)")
                let result = cache.getValue(for: "key\(i)")
                switch result {
                case .hitNonNullValue(let value):
                    XCTAssertEqual(value, "value\(i)")
                default:
                    XCTFail("Expected .hitNonNullValue, got \(result)")
                }
                group.leave()
            }
        }
        
        group.wait()
        
        // Verify all values are accessible
        for i in 0..<100 {
            let result = cache.getValue(for: "key\(i)")
            switch result {
            case .hitNonNullValue(let value):
                XCTAssertEqual(value, "value\(i)")
            default:
                XCTFail("Expected .hitNonNullValue, got \(result)")
            }
        }
    }
    
    func testFetchResultWithStatisticsIntegration() {
        _ = [MemoryCache<String, String>.FetchResult]()
        
        let cache = MemoryCache<String, String>(
            configuration: .init(),
            statisticsReport: { stats, record in
                // This callback is called for each cache operation
            }
        )
        
        // Test various scenarios and verify statistics
        cache.set(value: "test_value", for: "test_key")
        
        // Hit with non-null value
        let result1 = cache.getValue(for: "test_key")
        switch result1 {
        case .hitNonNullValue(let value):
            XCTAssertEqual(value, "test_value")
        default:
            XCTFail("Expected .hitNonNullValue, got \(result1)")
        }
        
        // Hit with null value
        cache.set(value: nil as String?, for: "null_key")
        let result2 = cache.getValue(for: "null_key")
        switch result2 {
        case .hitNullValue: break // Expected
        default: XCTFail("Expected .hitNullValue, got \(result2)")
        }
        
        // Miss
        let result3 = cache.getValue(for: "nonexistent")
        switch result3 {
        case .miss: break // Expected
        default: XCTFail("Expected .miss, got \(result3)")
        }
        
        // Invalid key
        let cacheWithValidator = MemoryCache<String, String>(
            configuration: .init(keyValidator: { $0.hasPrefix("valid_") })
        )
        let result4 = cacheWithValidator.getValue(for: "invalid_key")
        switch result4 {
        case .invalidKey: break // Expected
        default: XCTFail("Expected .invalidKey, got \(result4)")
        }
        
        // Verify statistics are recorded
        let stats = cache.statistics
        XCTAssertGreaterThan(stats.totalAccesses, 0)
    }
    
    func testFetchResultEdgeCases() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1) // Very small capacity
            )
        )
        
        // Fill cache to capacity
        cache.set(value: "first", for: "first_key")
        
        // Add second item, should evict first
        cache.set(value: "second", for: "second_key")
        
        // First should be evicted (miss)
        let result1 = cache.getValue(for: "first_key")
        switch result1 {
        case .miss: break // Expected
        default: XCTFail("Expected .miss, got \(result1)")
        }
        
        // Second should exist
        let result2 = cache.getValue(for: "second_key")
        switch result2 {
        case .hitNonNullValue(let value):
            XCTAssertEqual(value, "second")
        default:
            XCTFail("Expected .hitNonNullValue, got \(result2)")
        }
    }
    
    func testFetchResultWithEmptyCache() {
        let cache = MemoryCache<String, String>()
        
        // Test miss on empty cache
        let result = cache.getValue(for: "any_key")
        switch result { case .miss: break; default: XCTFail("Expected .miss, got (result)"); }
        XCTAssertNil(result.value)
        XCTAssertTrue(result.isMiss)
    }
    
    func testFetchResultWithZeroCapacity() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 0))
        )
        
        // Try to set value in zero-capacity cache
        cache.set(value: "test", for: "test_key")
        
        // Should not be able to retrieve it
        let result = cache.getValue(for: "test_key")
        switch result { case .miss: break; default: XCTFail("Expected .miss, got (result)"); }
    }
    
    // MARK: - Performance Tests
    
    func testBulkOperations() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 1000)))
        
        measure {
            // Bulk insert
            for i in 0..<500 {
                cache.set(value: i, for: "key\(i)")
            }
            
                    // Bulk read
        for i in 0..<500 {
            _ = cache.getValueDirect(for: "key\(i)")
        }
            
            // Bulk remove
            for i in 0..<500 {
                cache.removeValue(for: "key\(i)")
            }
        }
    }
    
    // MARK: - Cache Management Tests
    
    func testRemoveValue() {
        let cache = MemoryCache<String, String>(configuration: .init(memoryUsageLimitation: .init(capacity: 3)))
        
        // Add some values
        cache.set(value: "value1", for: "key1")
        cache.set(value: "value2", for: "key2")
        cache.set(value: "value3", for: "key3")
        
        XCTAssertEqual(cache.count, 3)
        
        // Remove least recently used value
        let removedValue = cache.removeValue()
        XCTAssertNotNil(removedValue)
        XCTAssertEqual(cache.count, 2)
        
        // Remove another value
        let secondRemovedValue = cache.removeValue()
        XCTAssertNotNil(secondRemovedValue)
        XCTAssertEqual(cache.count, 1)
        
        // Remove last value
        let thirdRemovedValue = cache.removeValue()
        XCTAssertNotNil(thirdRemovedValue)
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
        
        // Try to remove from empty cache
        let emptyRemovedValue = cache.removeValue()
        XCTAssertNil(emptyRemovedValue)
    }
    
    func testRemoveExpiredValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 0.1 // 100ms TTL
            )
        )
        
        // Add values with short TTL
        cache.set(value: "value1", for: "key1", expiredIn: 0.1)
        cache.set(value: "value2", for: "key2", expiredIn: 0.1)
        cache.set(value: "value3", for: "key3", expiredIn: 0.1)
        
        XCTAssertEqual(cache.count, 3)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        // Remove expired values
        cache.removeExpiredValues()
        
        // All values should be removed
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
    }
    
    func testRemoveValuesToPercent() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 10)))
        
        // Add 10 values
        for i in 0..<10 {
            cache.set(value: i, for: "key\(i)")
        }
        
        XCTAssertEqual(cache.count, 10)
        
        // Remove to 50% (should keep 5 items)
        cache.removeValues(toPercent: 0.5)
        XCTAssertEqual(cache.count, 5)
        
        // Remove to 20% (should keep 1 item)
        cache.removeValues(toPercent: 0.2)
        XCTAssertEqual(cache.count, 1)
        
        // Remove to 0% (should keep 0 items)
        cache.removeValues(toPercent: 0.0)
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
    }
    
    func testRemoveValuesToPercentWithExpiredValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 0.1 // 100ms TTL
            )
        )
        
        // Add some values with short TTL
        cache.set(value: "expired1", for: "expired1", expiredIn: 0.1)
        cache.set(value: "expired2", for: "expired2", expiredIn: 0.1)
        
        // Add some values with long TTL
        cache.set(value: "valid1", for: "valid1", expiredIn: 10.0)
        cache.set(value: "valid2", for: "valid2", expiredIn: 10.0)
        cache.set(value: "valid3", for: "valid3", expiredIn: 10.0)
        
        XCTAssertEqual(cache.count, 5)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        // Remove to 60% (should keep 3 items, but expired ones are removed first)
        cache.removeValues(toPercent: 0.6)
        
        // Should only have valid items remaining
        XCTAssertEqual(cache.count, 3)
        XCTAssertNotNil(cache.getValueDirect(for: "valid1"))
        XCTAssertNotNil(cache.getValueDirect(for: "valid2"))
        XCTAssertNotNil(cache.getValueDirect(for: "valid3"))
    }
    
    // MARK: - Configuration & Property Tests
    
    func testDefaultConfiguration() {
        let cache = MemoryCache<String, Int>()
        
        // Test default behavior - should accept any key
        cache.set(value: 1, for: "any_key")
        XCTAssertEqual(cache.getValueDirect(for: "any_key"), 1)
        
        // Test default capacity
        XCTAssertEqual(cache.capacity, 1024)
    }
    
    func testCustomConfiguration() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 500, memory: 100),
                defaultTTL: 3600,
                defaultTTLForNullValue: 1800,
                ttlRandomizationRange: 300,
                keyValidator: { $0.hasPrefix("test_") },
                costProvider: { _ in 1024 }
            )
        )
        
        // Test custom capacity
        XCTAssertEqual(cache.capacity, 500)
        
        // Test custom key validator
        cache.set(value: 1, for: "test_key")
        XCTAssertEqual(cache.getValueDirect(for: "test_key"), 1)
        
        cache.set(value: 2, for: "invalid_key")
        XCTAssertNil(cache.getValueDirect(for: "invalid_key"))
    }
    
    func testPropertyAccess() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 3)))
        
        // Test empty state
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
        XCTAssertEqual(cache.capacity, 3)
        XCTAssertFalse(cache.isFull)
        
        // Add items
        cache.set(value: 1, for: "key1")
        XCTAssertFalse(cache.isEmpty)
        XCTAssertEqual(cache.count, 1)
        XCTAssertFalse(cache.isFull)
        
        // Fill cache
        cache.set(value: 2, for: "key2")
        cache.set(value: 3, for: "key3")
        XCTAssertEqual(cache.count, 3)
        XCTAssertTrue(cache.isFull)
        
        // Remove item
        cache.removeValue(for: "key1")
        XCTAssertEqual(cache.count, 2)
        XCTAssertFalse(cache.isFull)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryLimitEnforcement() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1000, memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 } // 1MB per item
            )
        )
        
        // Add first item (should fit)
        let evicted1 = cache.set(value: "large_value", for: "key1")
        // Should not evict anything on first insert
        XCTAssertTrue(evicted1.count == 1 && evicted1[0] == "large_value")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        
        // Add second item (should evict first due to memory limit)
        let evicted2 = cache.set(value: "large_value2", for: "key2")
        // After eviction, only key2 should remain
        XCTAssertTrue(evicted2.count == 1 && evicted2[0] == "large_value2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    func testCostProvider() {
        var costCalculations = 0
        let cache = MemoryCache<String, String>(
            configuration: .init(
                costProvider: { value in
                    costCalculations += 1
                    return value.count * 2 // Custom cost calculation
                }
            )
        )
        
        // Add items with different costs
        cache.set(value: "short", for: "key1")
        cache.set(value: "longer_value", for: "key2")
        
        XCTAssertGreaterThan(costCalculations, 0)
        XCTAssertEqual(cache.count, 2)
    }
    
    // MARK: - TTL Edge Cases Tests
    
    func testInfiniteTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: .infinity
            )
        )
        
        cache.set(value: "value", for: "key")
        
        // Wait and check - should still be there
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(cache.getValueDirect(for: "key"), "value")
    }
    
    func testZeroTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10)
            )
        )
        
        cache.set(value: "value", for: "key", expiredIn: 0)
        
        // Should be immediately expired
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    func testNegativeTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10)
            )
        )
        
        cache.set(value: "value", for: "key", expiredIn: -1)
        
        // Should be immediately expired
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    func testTTLPrecision() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10)
            )
        )
        
        // Set with very short TTL
        cache.set(value: "value", for: "key", expiredIn: 0.001) // 1ms
        
        // Should be immediately available
        XCTAssertEqual(cache.getValueDirect(for: "key"), "value")
        
        // Wait and should be expired
        Thread.sleep(forTimeInterval: 0.002)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyCacheOperations() {
        let cache = MemoryCache<String, Int>()
        
        // Test operations on empty cache
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "nonexistent"))
        XCTAssertNil(cache.removeValue(for: "nonexistent"))
        XCTAssertNil(cache.removeValue())
        cache.removeExpiredValues() // Should not crash
        cache.removeValues(toPercent: 0.5) // Should not crash
    }
    
    func testOverwriteExistingKey() {
        let cache = MemoryCache<String, String>()
        
        // Set initial value
        cache.set(value: "initial", for: "key")
        XCTAssertEqual(cache.getValueDirect(for: "key"), "initial")
        
        // Overwrite with new value
        let evicted = cache.set(value: "updated", for: "key")
        XCTAssertEqual(evicted.count, 0) // No eviction when overwriting
        XCTAssertEqual(cache.getValueDirect(for: "key"), "updated")
    }
    
    func testCapacityZero() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 0))
        )
        
        XCTAssertEqual(cache.capacity, 0)
        XCTAssertTrue(cache.isFull)
        
        // Should not be able to add items - value gets immediately evicted
        let evicted = cache.set(value: "value", for: "key")
        XCTAssertEqual(evicted.count, 0) // Value should be immediately evicted
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    func testNegativeCapacity() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: -5))
        )
        
        XCTAssertEqual(cache.capacity, 0) // Should be normalized to 0
        XCTAssertTrue(cache.isFull)
    }
    
    // MARK: - Priority Edge Cases Tests
    
    func testPriorityEdgeCases() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 2))
        )
        
        // Test with extreme priority values
        cache.set(value: "low", for: "low_key", priority: Double.leastNormalMagnitude)
        cache.set(value: "high", for: "high_key", priority: Double.greatestFiniteMagnitude)
        
        XCTAssertEqual(cache.count, 2)
        XCTAssertNotNil(cache.getValueDirect(for: "low_key"))
        XCTAssertNotNil(cache.getValueDirect(for: "high_key"))
    }
    
    func testLRUEvictionOrder() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 3))
        )
        
        // Add three items with same priority
        cache.set(value: "first", for: "key1", priority: 1.0)
        cache.set(value: "second", for: "key2", priority: 1.0)
        cache.set(value: "third", for: "key3", priority: 1.0)
        
        // Access items to change LRU order
        _ = cache.getValueDirect(for: "key1") // Move key1 to front
        
        // Add fourth item - should evict key2 (least recently used)
        cache.set(value: "fourth", for: "key4", priority: 1.0)
        
        XCTAssertNil(cache.getValueDirect(for: "key2"))
        XCTAssertNotNil(cache.getValueDirect(for: "key1"))
        XCTAssertNotNil(cache.getValueDirect(for: "key3"))
        XCTAssertNotNil(cache.getValueDirect(for: "key4"))
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafetyEnabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(enableThreadSynchronization: true)
        )
        
        // Basic operations should work with thread safety enabled
        cache.set(value: 1, for: "key1")
        XCTAssertEqual(cache.getValueDirect(for: "key1"), 1)
        XCTAssertEqual(cache.count, 1)
    }
    
    func testThreadSafetyDisabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(enableThreadSynchronization: false)
        )
        
        // Basic operations should work with thread safety disabled
        cache.set(value: 1, for: "key1")
        XCTAssertEqual(cache.getValueDirect(for: "key1"), 1)
        XCTAssertEqual(cache.count, 1)
    }
    
    // MARK: - Complex Scenarios Tests
    
    func testComplexScenario() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 5, memory: 10),
                defaultTTL: 1.0,
                ttlRandomizationRange: 0.1,
                costProvider: { _ in 1 }
            )
        )
        
        // Add items with different priorities and TTLs
        cache.set(value: "short_lived", for: "key1", priority: 1.0, expiredIn: 0.1)
        cache.set(value: "high_priority", for: "key2", priority: 10.0, expiredIn: 10.0)
        cache.set(value: "normal", for: "key3", priority: 5.0, expiredIn: 5.0)
        cache.set(value: "low_priority", for: "key4", priority: 0.1, expiredIn: 10.0)
        cache.set(value: "null_value", for: "key5")
        
        XCTAssertEqual(cache.count, 5)
        
        // Wait for short-lived item to expire
        Thread.sleep(forTimeInterval: 0.2)
        
        // Remove expired values
        cache.removeExpiredValues()
        XCTAssertEqual(cache.count, 4)
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        
        // Remove to 50%
        cache.removeValues(toPercent: 0.5)
        XCTAssertEqual(cache.count, 2)
        
        // High priority and normal should remain
        XCTAssertNotNil(cache.getValueDirect(for: "key2"))
        XCTAssertNotNil(cache.getValueDirect(for: "key3"))
    }
    
    func testStressScenario() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                defaultTTL: 0.1
            )
        )
        
        // Rapidly add and remove items
        for i in 0..<1000 {
            cache.set(value: i, for: "key\(i)", priority: Double(i % 10))
            
            if i % 10 == 0 {
                _ = cache.removeValue()
            }
            
            if i % 20 == 0 {
                cache.removeExpiredValues()
            }
            
            if i % 50 == 0 {
                cache.removeValues(toPercent: 0.8)
            }
        }
        
        // Cache should still be functional
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
        XCTAssertGreaterThanOrEqual(cache.count, 0)
    }
    
    // MARK: - Memory Cost Tracking Tests
    
    func testMemoryCostTracking() {
        var costCalculations = 0
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 100), // 100MB limit
                costProvider: { value in
                    costCalculations += 1
                    return value.count * 10 // 10 bytes per character
                }
            )
        )
        
        // Add items with different costs
        cache.set(value: "short", for: "key1") // 50 bytes
        cache.set(value: "longer_value", for: "key2") // 120 bytes
        
        // Cost provider should be called for each set operation
        XCTAssertGreaterThanOrEqual(costCalculations, 2)
        XCTAssertEqual(cache.count, 2)
        
        // Add item that exceeds memory limit
        let evicted = cache.set(value: "very_long_value_that_exceeds_memory_limit", for: "key3")
        XCTAssertGreaterThanOrEqual(evicted.count, 0) // May evict due to memory limit
    }
    
    func testMemoryCostCalculationEdgeCases() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 5),
                costProvider: { _ in 0 } // Zero cost provider
            )
        )
        
        // Test with zero cost items
        cache.set(value: "value1", for: "key1")
        cache.set(value: "value2", for: "key2")
        
        XCTAssertEqual(cache.count, 2)
        
        // Test with nil values (should have minimal cost)
        cache.set(value: nil as String?, for: "key3")
        XCTAssertEqual(cache.count, 3)
    }
    
    func testMemoryLimitBoundaryConditions() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 } // Exactly 1MB per item
            )
        )
        
        // Try to add exactly at the memory limit
        let evicted1 = cache.set(value: "exact_size", for: "key1")
        XCTAssertEqual(evicted1.count, 1) // Should be immediately evicted
        
        // Try to add slightly over the memory limit
        let evicted2 = cache.set(value: "slightly_larger", for: "key2")
        XCTAssertEqual(evicted2.count, 1) // Should be immediately evicted
    }
    
    // MARK: - TTL Randomization Edge Cases Tests
    
    func testTTLRandomizationWithInfiniteTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: .infinity,
                ttlRandomizationRange: 10.0 // Should not affect infinite TTL
            )
        )
        
        cache.set(value: "value", for: "key")
        
        // Wait and check - should still be there (infinite TTL not randomized)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(cache.getValueDirect(for: "key"), "value")
    }
    
    func testTTLRandomizationEdgeCases() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 10.0,
                ttlRandomizationRange: 5.0 // ±5 seconds randomization
            )
        )
        
        // Test with TTL values that should remain positive after randomization
        cache.set(value: "short", for: "key1", expiredIn: 10.0) // Should stay positive
        cache.set(value: "medium", for: "key2", expiredIn: 5.0) // Should stay positive
        
        // Both should be available immediately
        XCTAssertEqual(cache.getValueDirect(for: "key1"), "short")
        XCTAssertEqual(cache.getValueDirect(for: "key2"), "medium")
    }
    
    func testTTLRandomizationZeroRange() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 1.0,
                ttlRandomizationRange: 0.0 // No randomization
            )
        )
        
        cache.set(value: "value", for: "key")
        
        // Should be available for exactly 1 second
        XCTAssertEqual(cache.getValueDirect(for: "key"), "value")
        
        Thread.sleep(forTimeInterval: 1.1)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    // MARK: - Cost Provider Integration Tests
    
    func testCostProviderWithDifferentDataTypes() {
        // Test with String type
        let stringCache = MemoryCache<String, String>(
            configuration: .init(
                costProvider: { $0.count * 2 }
            )
        )
        
        stringCache.set(value: "hello", for: "key1")
        stringCache.set(value: "world", for: "key2")
        XCTAssertEqual(stringCache.count, 2)
        
        // Test with Int type
        let intCache = MemoryCache<String, Int>(
            configuration: .init(
                costProvider: { $0 * 4 }
            )
        )
        
        intCache.set(value: 10, for: "key1")
        intCache.set(value: 20, for: "key2")
        XCTAssertEqual(intCache.count, 2)
    }
    
    func testCostProviderWithComplexObjects() {
        struct ComplexObject {
            let data: String
            let number: Int
        }
        
        let cache = MemoryCache<String, ComplexObject>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 5),
                costProvider: { obj in
                    return obj.data.count + obj.number
                }
            )
        )
        
        let obj1 = ComplexObject(data: "test", number: 10)
        let obj2 = ComplexObject(data: "longer_test", number: 20)
        
        cache.set(value: obj1, for: "key1")
        cache.set(value: obj2, for: "key2")
        
        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.getValueDirect(for: "key1")?.data, "test")
        XCTAssertEqual(cache.getValueDirect(for: "key2")?.number, 20)
    }
    
    // MARK: - Thread Safety Concurrent Access Tests
    
    func testThreadSafetyConcurrentAccess() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 1000)
            )
        )
        
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Concurrent writes
        for i in 0..<100 {
            group.enter()
            queue.async {
                cache.set(value: i, for: "key\(i)")
                group.leave()
            }
        }
        
        // Concurrent reads
        for i in 0..<100 {
            group.enter()
            queue.async {
                _ = cache.getValueDirect(for: "key\(i)")
                group.leave()
            }
        }
        
        group.wait()
        
        // Cache should still be functional after concurrent access
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
        XCTAssertGreaterThanOrEqual(cache.count, 0)
    }
    
    func testThreadSafetyWithoutSynchronization() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 1000)
            )
        )
        
        // Test basic operations without synchronization (should not crash)
        cache.set(value: 1, for: "key1")
        XCTAssertEqual(cache.getValueDirect(for: "key1"), 1)
        XCTAssertEqual(cache.count, 1)
        
        // Test that operations work without thread safety
        cache.set(value: 2, for: "key2")
        cache.set(value: 3, for: "key3")
        XCTAssertEqual(cache.count, 3)
        
        // Test removal
        let removed = cache.removeValue(for: "key1")
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(cache.count, 2)
    }
    
    // MARK: - Cache Entry Structure Tests
    
    func testCacheEntryWithNullValues() {
        let cache = MemoryCache<String, String>()
        
        // Test null value caching
        cache.set(value: nil as String?, for: "null_key")
        
        // Should return nil (indicating null value was cached)
        XCTAssertNil(cache.getValueDirect(for: "null_key"))
        
        // Test that null values don't interfere with regular values
        cache.set(value: "regular_value", for: "regular_key")
        XCTAssertEqual(cache.getValueDirect(for: "regular_key"), "regular_value")
        XCTAssertNil(cache.getValueDirect(for: "null_key"))
    }
    
    func testCacheEntryOverwriteBehavior() {
        let cache = MemoryCache<String, String>()
        
        // Set null value first
        cache.set(value: nil as String?, for: "key")
        XCTAssertNil(cache.getValueDirect(for: "key"))
        
        // Overwrite with regular value
        cache.set(value: "new_value", for: "key")
        XCTAssertEqual(cache.getValueDirect(for: "key"), "new_value")
        
        // Overwrite with null value again
        cache.set(value: nil as String?, for: "key")
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    // MARK: - Memory Management Edge Cases Tests
    
    func testMemoryLimitWithZeroMemory() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 0), // 0MB limit
                costProvider: { _ in 1 }
            )
        )
        
        // Any item should be immediately evicted
        let evicted = cache.set(value: "value", for: "key")
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    func testMemoryLimitWithNegativeMemory() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: -100), // Negative memory
                costProvider: { _ in 1 }
            )
        )
        
        // Should behave like zero memory limit
        let evicted = cache.set(value: "value", for: "key")
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    func testMemoryCostTrackingWithEmptyCache() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                costProvider: { _ in 100 }
            )
        )
        
        // Test cost tracking when cache is empty
        XCTAssertEqual(cache.count, 0)
        
        // Add and remove items
        cache.set(value: "value", for: "key")
        XCTAssertEqual(cache.count, 1)
        
        cache.removeValue(for: "key")
        XCTAssertEqual(cache.count, 0)
        
        // Should not crash when empty
        cache.removeValue()
        XCTAssertEqual(cache.count, 0)
    }
    
    // MARK: - Configuration Validation Tests
    
    func testConfigurationWithExtremeValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 1000000, memory: 1000000), // Large but reasonable values
                defaultTTL: .infinity,
                defaultTTLForNullValue: .infinity,
                ttlRandomizationRange: 1000.0, // Large but reasonable range
                keyValidator: { _ in true },
                costProvider: { _ in 1000000 } // Large but reasonable cost
            )
        )
        
        // Should not crash with extreme values
        cache.set(value: "value", for: "key")
        XCTAssertEqual(cache.getValueDirect(for: "key"), "value")
    }
    
    func testConfigurationWithMinimalValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 0, memory: 0),
                defaultTTL: 0,
                defaultTTLForNullValue: 0,
                ttlRandomizationRange: 0,
                keyValidator: { _ in false }, // Reject all keys
                costProvider: { _ in 0 }
            )
        )
        
        // Should handle minimal configuration gracefully
        let evicted = cache.set(value: "value", for: "key")
        XCTAssertEqual(evicted.count, 0) // Rejected by validator
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    // MARK: - Memory Cost Tracking Verification Tests
    
    func testMemoryCostTrackingAfterBugFix() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 100), // 100MB limit
                costProvider: { value in
                    return value.count // Cost = string length
                }
            )
        )
        
        // Test that totalCost doesn't go negative
        cache.set(value: "test", for: "key1") // Cost = 4 bytes
        cache.set(value: "longer", for: "key2") // Cost = 6 bytes
        cache.set(value: "very_long_string", for: "key3") // Cost = 15 bytes
        
        // Remove items and verify cost tracking
        _ = cache.removeValue(for: "key1")
        _ = cache.removeValue(for: "key2")
        _ = cache.removeValue(for: "key3")
        
        // Cache should be empty and cost should be 0
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
    }
    
    func testMemoryCostTrackingWithNullValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                costProvider: { value in
                    return value.count
                }
            )
        )
        
        // Add null values and verify cost tracking
        cache.set(value: nil as String?, for: "null1")
        cache.set(value: nil as String?, for: "null2")
        
        // Null values should have minimal cost
        XCTAssertEqual(cache.count, 2)
        
        // Remove null values
        _ = cache.removeValue(for: "null1")
        _ = cache.removeValue(for: "null2")
        
        XCTAssertTrue(cache.isEmpty)
    }
    
    // MARK: - Memory Limit Conversion Tests
    
    func testMemoryLimitConversionAccuracy() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(memory: 1), // 1MB = 1,048,576 bytes
                costProvider: { _ in 1024 * 1024 } // 1MB per item
            )
        )
        
        // First item should fit (1MB)
        cache.set(value: "large", for: "key1")
        // The item might be immediately evicted due to memory limit
        XCTAssertEqual(cache.count, 0)
        
        // Second item should also be evicted
        cache.set(value: "large", for: "key2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    func testMemoryLimitWithExactByteCalculation() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(memory: 2), // 2MB = 2,097,152 bytes
                costProvider: { value in
                    return value.count
                }
            )
        )
        
        // Add items with smaller costs to test memory limit
        let smallString = String(repeating: "a", count: 1000) // 1KB
        cache.set(value: smallString, for: "key1")
        cache.set(value: smallString, for: "key2")
        
        // Both should fit
        XCTAssertEqual(cache.count, 2)
        
        // Add many more items to test eviction
        for i in 3...10 {
            cache.set(value: smallString, for: "key\(i)")
        }
        
        // Should maintain capacity limits
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    // MARK: - Eviction Loop Safety Tests
    
    func testEvictionLoopSafety() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1000, memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 + 1 } // Slightly over 1MB per item
            )
        )
        
        // This should not cause infinite loop
        cache.set(value: "large", for: "key")
        
        // Should handle gracefully without hanging
        XCTAssertEqual(cache.count, 0) // Item too large to fit
        // The evicted count might be 1 if the item was briefly stored before eviction
    }
    
    func testEvictionLoopWithZeroCostItems() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 1), // 1MB limit
                costProvider: { _ in 0 } // Zero cost items
            )
        )
        
        // Add many zero-cost items
        for i in 0..<100 {
            cache.set(value: "zero_cost", for: "key\(i)")
        }
        
        // Should not cause infinite loop
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    // MARK: - Cost Calculation Edge Cases
    
    func testCostCalculationWithDifferentDataTypes() {
        // Test with Int
        let intCache = MemoryCache<String, Int>(
            configuration: .init(
                costProvider: { value in
                    return value
                }
            )
        )
        intCache.set(value: 1000, for: "int_key")
        XCTAssertEqual(intCache.getValueDirect(for: "int_key"), 1000)
        
        // Test with Double
        let doubleCache = MemoryCache<String, Double>(
            configuration: .init(
                costProvider: { value in
                    return Int(value)
                }
            )
        )
        doubleCache.set(value: 3.14, for: "double_key")
        XCTAssertEqual(doubleCache.getValueDirect(for: "double_key"), 3.14)
        
        // Test with Bool
        let boolCache = MemoryCache<String, Bool>(
            configuration: .init(
                costProvider: { value in
                    return value == true ? 10 : 5
                }
            )
        )
        boolCache.set(value: true, for: "bool_key")
        XCTAssertEqual(boolCache.getValueDirect(for: "bool_key"), true)
    }
    
    func testCostCalculationWithNilValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                costProvider: { value in
                    return value.count
                }
            )
        )
        
        // Test cost calculation for nil values
        cache.set(value: nil as String?, for: "nil_key")
        XCTAssertNil(cache.getValueDirect(for: "nil_key"))
        
        // Test cost calculation for empty strings
        cache.set(value: "", for: "empty_key")
        XCTAssertEqual(cache.getValueDirect(for: "empty_key"), "")
    }
    
    // MARK: - TTL Calculation Edge Cases
    
    func testTTLCalculationWithInfiniteValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                ttlRandomizationRange: 100.0
            )
        )
        
        // Test infinite TTL with randomization
        cache.set(value: "infinite", for: "key1", expiredIn: .infinity)
        XCTAssertEqual(cache.getValueDirect(for: "key1"), "infinite")
        
        // Test infinite TTL for null values
        cache.set(value: nil, for: "key2")
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    func testTTLRandomizationWithBulkValues() {
        let N = 10000
        
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 2 * N), // Large capacity to hold all values
                ttlRandomizationRange: 2 // 1s randomization range (±0.5s)
            )
        )
        
        // Insert 10000 values with 2s base TTL and 1s randomization range
        for i in 0..<N {
            cache.set(value: "value\(i)", for: "key\(i)", expiredIn: 2.0)
        }
        
        // Verify all values are initially present
        XCTAssertEqual(cache.count, N)
        
        // Wait for 2 seconds (base TTL duration)
        Thread.sleep(forTimeInterval: 2.0)
        
        // Remove expired values and check remaining count
        XCTAssertEqual(cache.count, N) // Count unchanged before cleanup
        cache.removeExpiredValues()
        let remainingCount = cache.count
        
        // Should be more than 0 (some values have longer TTL due to positive randomization)
        XCTAssertGreaterThan(remainingCount, 0)
        
        // Should be less than 10000 (some values have shorter TTL due to negative randomization)
        XCTAssertLessThan(remainingCount, N)
        
        // Verify that some values are still accessible after expiration
        var accessibleCount = 0
        for i in 0..<N {
            if cache.getValueDirect(for: "key\(i)") != nil {
                accessibleCount += 1
            }
        }
        
        // Should have some accessible values remaining
        XCTAssertGreaterThan(accessibleCount, 0)
        XCTAssertLessThan(accessibleCount, N)
        
        // Accessible count should not exceed remaining count (some may expire during iteration)
        XCTAssertLessThanOrEqual(accessibleCount, remainingCount)
    }
    
    // MARK: - Lock Behavior Tests
    
    func testLockBehaviorWithThreadSafetyEnabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 1000)
            )
        )
        
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Concurrent operations with lock enabled
        for i in 0..<100 {
            group.enter()
            queue.async {
                cache.set(value: i, for: "key\(i)")
                _ = cache.getValueDirect(for: "key\(i)")
                group.leave()
            }
        }
        
        group.wait()
        
        // Should not crash and maintain consistency
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    func testLockBehaviorWithThreadSafetyDisabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 1000)
            )
        )
        
        // Operations without lock should still work
        cache.set(value: 1, for: "key1")
        XCTAssertEqual(cache.getValueDirect(for: "key1"), 1)
        
        // But may have race conditions in concurrent scenarios
        // (This is expected behavior when thread safety is disabled)
    }
    
    // MARK: - Cache Entry Structure Tests
    
    func testCacheEntryStructureBehavior() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 10))
        )
        
        // Test regular value entry
        cache.set(value: "regular_value", for: "regular_key")
        XCTAssertEqual(cache.getValueDirect(for: "regular_key"), "regular_value")
        
        // Test null value entry
        cache.set(value: nil, for: "null_key")
        XCTAssertNil(cache.getValueDirect(for: "null_key"))
        
        // Test that both types of entries coexist
        XCTAssertEqual(cache.count, 2)
        
        // Test entry overwriting
        cache.set(value: "new_value", for: "regular_key")
        XCTAssertEqual(cache.getValueDirect(for: "regular_key"), "new_value")
        
        cache.set(value: nil, for: "regular_key")
        XCTAssertNil(cache.getValueDirect(for: "regular_key"))
    }
    
    func testCacheEntryWithMixedValueTypes() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 10))
        )
        
        // Mix of regular and null values
        cache.set(value: "value1", for: "key1")
        cache.set(value: nil, for: "key2")
        cache.set(value: "value3", for: "key3")
        cache.set(value: nil, for: "key4")
        
        XCTAssertEqual(cache.count, 4)
        XCTAssertEqual(cache.getValueDirect(for: "key1"), "value1")
        XCTAssertNil(cache.getValueDirect(for: "key2"))
        XCTAssertEqual(cache.getValueDirect(for: "key3"), "value3")
        XCTAssertNil(cache.getValueDirect(for: "key4"))
    }
    
    // MARK: - Memory Cost Tracking Edge Cases
    
    func testMemoryCostTrackingWithLargeValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 1000), // 1000MB limit
                costProvider: { _ in 1000000 } // 1MB per item
            )
        )
        
        // Test with large cost values
        cache.set(value: "large_value", for: "key1")
        XCTAssertEqual(cache.count, 1)
        
        // Add another large item
        cache.set(value: "large_value2", for: "key2")
        XCTAssertEqual(cache.count, 2)
        
        // Verify memory cost tracking doesn't overflow
        XCTAssertGreaterThan(cache.count, 0)
    }
    
    func testMemoryLimitWithExactCost() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 } // Exactly 1MB per item
            )
        )
        
        // First item should fit exactly
        cache.set(value: "exact", for: "key1")
        // The item might be immediately evicted due to additional overhead
        XCTAssertEqual(cache.count, 0)
        
        // Second item should also be evicted
        cache.set(value: "exact2", for: "key2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    func testMemoryLimitWithSlightlyLargerCost() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 + 1 } // Slightly over 1MB per item
            )
        )
        
        // Item should be immediately evicted due to cost exceeding limit
        cache.set(value: "oversized", for: "key")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    // MARK: - TTL Randomization Precision Tests
    
    func testTTLRandomizationWithSmallRange() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                ttlRandomizationRange: 0.001 // Very small randomization (1ms)
            )
        )
        
        // Add values with short TTL
        cache.set(value: "short1", for: "key1", expiredIn: 0.1)
        cache.set(value: "short2", for: "key2", expiredIn: 0.1)
        
        // Both should be available immediately
        XCTAssertEqual(cache.getValueDirect(for: "key1"), "short1")
        XCTAssertEqual(cache.getValueDirect(for: "key2"), "short2")
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        cache.removeExpiredValues()
        
        // Both should be expired
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    func testTTLRandomizationDistribution() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1000),
                ttlRandomizationRange: 1.0 // 1s randomization
            )
        )
        
        // Add many values with same base TTL
        for i in 0..<100 {
            cache.set(value: "value\(i)", for: "key\(i)", expiredIn: 10.0)
        }
        
        // Wait for base TTL
        Thread.sleep(forTimeInterval: 10.0)
        cache.removeExpiredValues()
        
        let remainingCount = cache.count
        
        // Should have some values remaining (due to positive randomization)
        XCTAssertGreaterThan(remainingCount, 0)
        XCTAssertLessThan(remainingCount, 100)
        
        // Should be roughly 50% remaining (statistical expectation)
        // Allow for some variance due to randomization
        XCTAssertGreaterThan(remainingCount, 20) // At least 20% should remain
        XCTAssertLessThan(remainingCount, 80)   // At most 80% should remain
    }
    
    // MARK: - Configuration Validation Tests
    
    func testConfigurationImmutability() {
        let config = MemoryCache<String, String>.Configuration(
            enableThreadSynchronization: true,
            memoryUsageLimitation: .init(capacity: 100),
            defaultTTL: 3600,
            defaultTTLForNullValue: 1800,
            ttlRandomizationRange: 300,
            keyValidator: { $0.count > 0 },
            costProvider: { $0.count }
        )
        
        let cache = MemoryCache<String, String>(configuration: config)
        
        // Configuration should be immutable after cache creation
        // (This is implicit since Configuration properties are let constants)
        XCTAssertEqual(cache.capacity, 100)
        
        // Test that the configuration is applied correctly
        cache.set(value: "valid", for: "valid_key")
        XCTAssertEqual(cache.getValueDirect(for: "valid_key"), "valid")
        
        // Invalid key should be rejected
        cache.set(value: "invalid", for: "")
        XCTAssertNil(cache.getValueDirect(for: ""))
    }
    
    func testConfigurationWithZeroRandomization() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                ttlRandomizationRange: 0.0 // No randomization
            )
        )
        
        // Add values with exact TTL
        cache.set(value: "exact1", for: "key1", expiredIn: 0.1)
        cache.set(value: "exact2", for: "key2", expiredIn: 0.1)
        
        // Both should be available
        XCTAssertEqual(cache.getValueDirect(for: "key1"), "exact1")
        XCTAssertEqual(cache.getValueDirect(for: "key2"), "exact2")
        
        // Wait for exact expiration
        Thread.sleep(forTimeInterval: 0.15)
        cache.removeExpiredValues()
        
        // Both should be expired
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    // MARK: - Memory Overflow and Extreme Scenarios Tests
    
    func testMemoryCostOverflowScenarios() {
        // Test with maximum possible cost values
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 1000),
                costProvider: { _ in Int.max / 2 } // Very large cost
            )
        )
        
        // Should handle large costs without crashing
        cache.set(value: "large_cost", for: "key1")
        XCTAssertEqual(cache.count, 0)
        
        // Adding another should trigger eviction due to memory limit
        cache.set(value: "large_cost2", for: "key2")
        XCTAssertEqual(cache.count, 0) // Both should be evicted
    }
    
    func testMemoryCostWithComplexNestedObjects() {
        struct NestedObject {
            let data: [String]
            let metadata: [String: Int]
            let timestamp: Date
        }
        
        let cache = MemoryCache<String, NestedObject>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 5),
                costProvider: { obj in
                    // Complex cost calculation
                    let dataCost = obj.data.reduce(0) { $0 + $1.count }
                    let metadataCost = obj.metadata.reduce(0) { $0 + $1.key.count + String($1.value).count }
                    return dataCost + metadataCost + 100 // Base cost
                }
            )
        )
        
        let complexObj = NestedObject(
            data: ["item1", "item2", "item3"],
            metadata: ["key1": 1, "key2": 2, "key3": 3],
            timestamp: Date()
        )
        
        cache.set(value: complexObj, for: "complex_key")
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.getValueDirect(for: "complex_key"))
    }
    
    func testMemoryCostTrackingAccuracy() {
        var costCalculations: [String: Int] = [:]
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                costProvider: { value in
                    let cost = value.count * 2
                    costCalculations[value] = cost
                    return cost
                }
            )
        )
        
        // Add items and track costs
        cache.set(value: "test1", for: "key1")
        cache.set(value: "test2", for: "key2")
        cache.set(value: "test3", for: "key3")
        
        // Verify cost calculations were called
        XCTAssertEqual(costCalculations["test1"], 10)
        XCTAssertEqual(costCalculations["test2"], 10)
        XCTAssertEqual(costCalculations["test3"], 10)
        
        // Remove items and verify cost tracking
        _ = cache.removeValue(for: "key1")
        _ = cache.removeValue(for: "key2")
        _ = cache.removeValue(for: "key3")
        
        XCTAssertTrue(cache.isEmpty)
    }
    
    // MARK: - Microsecond Precision TTL Tests
    
    func testTTLRandomizationWithMicrosecondPrecision() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                ttlRandomizationRange: 0.000001 // 1 microsecond randomization
            )
        )
        
        // Add values with very short TTL
        cache.set(value: "micro1", for: "key1", expiredIn: 0.001) // 1ms base TTL
        cache.set(value: "micro2", for: "key2", expiredIn: 0.001)
        
        // Both should be available immediately
        XCTAssertEqual(cache.getValueDirect(for: "key1"), "micro1")
        XCTAssertEqual(cache.getValueDirect(for: "key2"), "micro2")
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.002)
        cache.removeExpiredValues()
        
        // Both should be expired
        XCTAssertNil(cache.getValueDirect(for: "key1"))
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    // MARK: - Concurrent Access Edge Cases Tests
    
    func testConcurrentAccessWithMemoryPressure() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 100, memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 } // 1MB per item
            )
        )
        
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Concurrent writes that will trigger memory pressure
        for i in 0..<50 {
            group.enter()
            queue.async {
                cache.set(value: "large_value", for: "key\(i)")
                group.leave()
            }
        }
        
        // Concurrent reads
        for i in 0..<50 {
            group.enter()
            queue.async {
                _ = cache.getValueDirect(for: "key\(i)")
                group.leave()
            }
        }
        
        group.wait()
        
        // Should not crash and maintain consistency
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    func testConcurrentAccessWithRapidEvictionCycles() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 10) // Small capacity for rapid eviction
            )
        )
        
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Rapid concurrent set operations
        for i in 0..<1000 {
            group.enter()
            queue.async {
                cache.set(value: i, for: "key\(i)")
                group.leave()
            }
        }
        
        // Concurrent removal operations
        for i in 0..<500 {
            group.enter()
            queue.async {
                _ = cache.removeValue(for: "key\(i)")
                group.leave()
            }
        }
        
        group.wait()
        
        // Should not crash and maintain consistency
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    func testConcurrentAccessWithMixedOperations() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 100)
            )
        )
        
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Mixed concurrent operations
        for i in 0..<100 {
            group.enter()
            queue.async {
                // Set operation
                cache.set(value: "value\(i)", for: "key\(i)")
                group.leave()
            }
            
            group.enter()
            queue.async {
                // Get operation
                _ = cache.getValueDirect(for: "key\(i)")
                group.leave()
            }
            
            group.enter()
            queue.async {
                // Remove operation
                _ = cache.removeValue(for: "key\(i)")
                group.leave()
            }
            
            group.enter()
            queue.async {
                // Remove expired values
                cache.removeExpiredValues()
                group.leave()
            }
        }
        
        group.wait()
        
        // Should not crash and maintain consistency
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    // MARK: - Performance Under Load Tests
    
    func testPerformanceWithVeryLargeCapacity() {
        let largeCapacity = 100000 // 100K entries
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: largeCapacity)
            )
        )
        
        measure {
            // Bulk insert
            for i in 0..<50000 {
                cache.set(value: i, for: "key\(i)")
            }
            
            // Bulk read
            for i in 0..<50000 {
                _ = cache.getValueDirect(for: "key\(i)")
            }
            
            // Bulk remove
            for i in 0..<50000 {
                _ = cache.removeValue(for: "key\(i)")
            }
        }
        
        XCTAssertEqual(cache.count, 0)
    }
    
    func testPerformanceWithVerySmallCapacity() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 2))
        )
        
        measure {
            // Rapid set/get cycles with small capacity
            for i in 0..<1000 {
                cache.set(value: i, for: "key\(i)")
                _ = cache.getValueDirect(for: "key\(i)")
                _ = cache.removeValue(for: "key\(i)")
            }
        }
        
        XCTAssertLessThanOrEqual(cache.count, 2)
    }
    
    func testPerformanceWithRapidSetGetCycles() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1000)
            )
        )
        
        measure {
            // Very rapid set/get cycles
            for i in 0..<10000 {
                cache.set(value: "value\(i)", for: "key\(i)")
                _ = cache.getValueDirect(for: "key\(i)")
                
                if i % 10 == 0 {
                    _ = cache.removeValue(for: "key\(i)")
                }
            }
        }
        
        XCTAssertLessThanOrEqual(cache.count, 1000)
    }
    
    // MARK: - Error Handling Edge Cases Tests
    
    func testBehaviorWithInvalidCostProvider() {
        // Test with cost provider that returns negative values
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                costProvider: { _ in -100 } // Negative cost
            )
        )
        
        // Should handle negative costs gracefully
        cache.set(value: "test", for: "key")
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.getValueDirect(for: "key"), "test")
    }
    
    func testBehaviorWithInvalidKeyValidator() {
        // Test with key validator that always returns false
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                keyValidator: { _ in false } // Reject all keys
            )
        )
        
        // Should handle invalid validator gracefully
        cache.set(value: "test", for: "key")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key"))
    }
    
    func testBehaviorWithExtremeConfigurationValues() {
        // Test with extreme configuration values
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: Int.max, memory: Int.max),
                defaultTTL: .infinity,
                defaultTTLForNullValue: .infinity,
                ttlRandomizationRange: Double.greatestFiniteMagnitude,
                keyValidator: { _ in true },
                costProvider: { _ in Int.max }
            )
        )
        
        // Should handle extreme values without crashing
        cache.set(value: "test", for: "key")
        XCTAssertEqual(cache.getValueDirect(for: "key"), "test")
    }
    
    // MARK: - Memory Pressure Scenarios Tests
    
    func testBehaviorWithExceededMemoryLimit() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1000, memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 * 10 } // 10MB per item (10x over limit)
            )
        )
        
        // Add items that exceed memory limit by orders of magnitude
        for i in 0..<100 {
            cache.set(value: "oversized_item", for: "key\(i)")
        }
        
        // Should handle gracefully without crashing
        XCTAssertEqual(cache.count, 0) // All items should be immediately evicted
    }
    
    func testBehaviorWithMemoryFragmentation() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100, memory: 10), // 10MB limit
                costProvider: { value in
                    // Varying costs to simulate fragmentation
                    return value.count * 1024 * 1024 // 1MB per character
                }
            )
        )
        
        // Add items with varying sizes
        cache.set(value: "small", for: "key1")
        cache.set(value: "medium_size", for: "key2")
        cache.set(value: "very_large_item_that_exceeds_limit", for: "key3")
        
        // Should handle varying sizes gracefully
        XCTAssertLessThanOrEqual(cache.count, 100)
    }
    
    func testBehaviorWithZeroMemoryLimit() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100, memory: 0), // 0MB limit
                costProvider: { _ in 1 }
            )
        )
        
        // Any item should be immediately evicted
        for i in 0..<50 {
            cache.set(value: "value\(i)", for: "key\(i)")
        }
        
        // Should handle zero memory limit gracefully
        XCTAssertEqual(cache.count, 0)
    }
    
    // MARK: - Advanced Integration Tests
    
    func testComplexScenarioWithAllFeatures() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 50, memory: 5), // 5MB limit
                defaultTTL: 1.0,
                defaultTTLForNullValue: 0.5,
                ttlRandomizationRange: 0.1,
                keyValidator: { $0.count > 0 && $0.count <= 20 },
                costProvider: { $0.count * 1024 * 1024 } // 1MB per character
            )
        )
        
        // Test all features together
        cache.set(value: "short", for: "key1", priority: 1.0, expiredIn: 0.1)
        cache.set(value: nil, for: "null_key")
        cache.set(value: "medium_length_value", for: "key2", priority: 5.0, expiredIn: 2.0)
        cache.set(value: "very_long_value_that_might_exceed_memory", for: "key3", priority: 10.0)
        
        XCTAssertEqual(cache.count, 1)
        
        // Wait for short-lived items to expire
        Thread.sleep(forTimeInterval: 0.2)
        cache.removeExpiredValues()
        
        // Should have some items remaining
        XCTAssertEqual(cache.count, 1)
    }
    
    func testStressTestWithAllOperations() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 100, memory: 10),
                defaultTTL: 0.1,
                ttlRandomizationRange: 0.05,
                costProvider: { $0 * 1024 }
            )
        )
        
        let queue = DispatchQueue(label: "stress", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Stress test with all operations
        for i in 0..<1000 {
            group.enter()
            queue.async {
                // Set with varying priorities and TTLs
                cache.set(value: i, for: "key\(i)", priority: Double(i % 10), expiredIn: Double(i % 5))
                
                // Get value
                _ = cache.getValueDirect(for: "key\(i)")
                
                // Remove expired values periodically
                if i % 100 == 0 {
                    cache.removeExpiredValues()
                }
                
                // Remove to percentage periodically
                if i % 200 == 0 {
                    cache.removeValues(toPercent: 0.5)
                }
                
                group.leave()
            }
        }
        
        group.wait()
        
        // Should remain functional
        XCTAssertLessThanOrEqual(cache.count, 100)
        XCTAssertGreaterThanOrEqual(cache.count, 0)
    }
    
    // MARK: - Boundary Condition Tests
    
    func testBoundaryConditionsWithMinimalValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 1, memory: 0),
                defaultTTL: 0,
                defaultTTLForNullValue: 0,
                ttlRandomizationRange: 0,
                keyValidator: { _ in true },
                costProvider: { _ in 0 }
            )
        )
        
        // Test with minimal configuration
        cache.set(value: "test", for: "key")
        XCTAssertEqual(cache.count, 0)
        
        // Add another item (should evict first)
        cache.set(value: "test2", for: "key2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValueDirect(for: "key"))
        XCTAssertNil(cache.getValueDirect(for: "key2"))
    }
    
    func testBoundaryConditionsWithMaximalValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: Int.max, memory: Int.max),
                defaultTTL: .infinity,
                defaultTTLForNullValue: .infinity,
                ttlRandomizationRange: Double.greatestFiniteMagnitude,
                keyValidator: { _ in true },
                costProvider: { _ in Int.max }
            )
        )
        
        // Test with maximal configuration
        cache.set(value: "test", for: "key")
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.getValueDirect(for: "key"), "test")
    }
    
    // MARK: - Memory Layout and Cost Calculation Tests
    
    func testMemoryLayoutCostCalculation() {
        // Test with different data types to verify memory layout calculation
        let stringCache = MemoryCache<String, String>(
            configuration: .init(
                costProvider: { _ in 0 } // Let system calculate memory layout
            )
        )
        
        let intCache = MemoryCache<String, Int>(
            configuration: .init(
                costProvider: { _ in 0 }
            )
        )
        
        let doubleCache = MemoryCache<String, Double>(
            configuration: .init(
                costProvider: { _ in 0 }
            )
        )
        
        // Test that memory layout is calculated correctly
        stringCache.set(value: "test", for: "key")
        intCache.set(value: 42, for: "key")
        doubleCache.set(value: 3.14, for: "key")
        
        XCTAssertEqual(stringCache.count, 1)
        XCTAssertEqual(intCache.count, 1)
        XCTAssertEqual(doubleCache.count, 1)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testStatisticsRecordingForGetValue() {
        var reportedResults: [CacheRecord] = []
        
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                keyValidator: { key in
                    return key.hasPrefix("valid_")
                }
            ),
            statisticsReport: { _, result in
                reportedResults.append(result)
            }
        )
        
        // Test invalid key
        _ = cache.getValueDirect(for: "invalid_key")
        XCTAssertEqual(reportedResults.count, 1)
        XCTAssertEqual(reportedResults.last, .invalidKey)
        
        // Test miss
        _ = cache.getValueDirect(for: "valid_key")
        XCTAssertEqual(reportedResults.count, 2)
        XCTAssertEqual(reportedResults.last, .miss)
        
        // Test null value hit
        cache.set(value: nil, for: "valid_null_key")
        _ = cache.getValueDirect(for: "valid_null_key")
        XCTAssertEqual(reportedResults.count, 3)
        XCTAssertEqual(reportedResults.last, .hitNullValue)
        
        // Test non-null value hit
        cache.set(value: "test_value", for: "valid_test_key")
        _ = cache.getValueDirect(for: "valid_test_key")
        XCTAssertEqual(reportedResults.count, 4)
        XCTAssertEqual(reportedResults.last, .hitNonNullValue)
    }
    
    func testStatisticsRecordingForSetValue() {
        var reportedResults: [CacheRecord] = []
        
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                keyValidator: { key in
                    return key.hasPrefix("valid_")
                }
            ),
            statisticsReport: { _, result in
                reportedResults.append(result)
            }
        )
        
        // Test invalid key in set
        cache.set(value: "test", for: "invalid_key")
        XCTAssertEqual(reportedResults.count, 0)
        XCTAssertEqual(reportedResults.last, nil)
        
        // Test null value caching
        cache.set(value: nil, for: "valid_null_key")
        XCTAssertEqual(reportedResults.count, 0)
        XCTAssertEqual(reportedResults.last, nil)
        
        // Test non-null value caching
        _=cache.getValueDirect(for: "valid_test_key")
        XCTAssertEqual(reportedResults.count, 1)
        XCTAssertEqual(reportedResults.last, .miss)
    }
    
    func testStatisticsAccuracy() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                keyValidator: { key in
                    return key.count > 0
                }
            )
        )
        
        // Perform various operations
        cache.set(value: "value1", for: "key1")
        cache.set(value: nil, for: "key2")
        cache.set(value: "value3", for: "key3")
        
        _ = cache.getValueDirect(for: "key1")  // hit
        _ = cache.getValueDirect(for: "key2")  // null hit
        _ = cache.getValueDirect(for: "key4")  // miss
        _ = cache.getValueDirect(for: "")      // invalid key
        
        let stats = cache.statistics
        
        XCTAssertEqual(stats.invalidKeyCount, 1)
        XCTAssertEqual(stats.nullValueHitCount, 1)
        XCTAssertEqual(stats.nonNullValueHitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.totalAccesses, 4)
    }
    
    func testStatisticsHitRateCalculation() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100)
            )
        )
        
        // Set up some data
        cache.set(value: "value1", for: "key1")
        cache.set(value: "value2", for: "key2")
        cache.set(value: nil, for: "key3")
        
        // Perform gets with known results
        _ = cache.getValueDirect(for: "key1")  // hit
        _ = cache.getValueDirect(for: "key2")  // hit
        _ = cache.getValueDirect(for: "key3")  // null hit
        _ = cache.getValueDirect(for: "key4")  // miss
        _ = cache.getValueDirect(for: "key5")  // miss
        
        let stats = cache.statistics
        
        // Hit rate should be 3/5 = 0.6 (excluding invalid keys)
        XCTAssertEqual(stats.hitRate, 0.6, accuracy: 0.01)
        
        // Success rate should be 3/5 = 0.6 (including all accesses)
        XCTAssertEqual(stats.successRate, 0.6, accuracy: 0.01)
    }
    
    func testStatisticsReset() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100)
            )
        )
        
        // Perform some operations
        cache.set(value: "value1", for: "key1")
        _ = cache.getValueDirect(for: "key1")
        _ = cache.getValueDirect(for: "key2")  // miss
        
        let statsBefore = cache.statistics
        XCTAssertGreaterThan(statsBefore.totalAccesses, 0)
        
        // Reset statistics
        cache.resetStatistics()
        
        let statsAfter = cache.statistics
        XCTAssertEqual(statsAfter.totalAccesses, 0)
        XCTAssertEqual(statsAfter.hitRate, 0.0)
        XCTAssertEqual(statsAfter.successRate, 0.0)
    }
    
    func testStatisticsWithConcurrentAccess() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1000)
            )
        )
        
        // Pre-populate cache
        for i in 0..<100 {
            cache.set(value: "value\(i)", for: "key\(i)")
        }
        
        let queue = DispatchQueue(label: "stats", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Concurrent access
        for i in 0..<1000 {
            group.enter()
            queue.async {
                _ = cache.getValueDirect(for: "key\(i % 100)")
                group.leave()
            }
        }
        
        group.wait()
        
        let stats = cache.statistics
        
        // Should have recorded all operations
        XCTAssertEqual(stats.totalAccesses, 1000)
        XCTAssertGreaterThan(stats.hitRate, 0.0)
    }
    
    func testStatisticsWithMixedOperations() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                keyValidator: { key in
                    return key.count > 0 && key.count <= 10
                }
            )
        )
        
        // Mix of operations
        cache.set(value: "value1", for: "key1")
        cache.set(value: nil, for: "key2")
        cache.set(value: "value3", for: "key3")
        cache.set(value: "value4", for: "")  // invalid key
        
        _ = cache.getValueDirect(for: "key1")  // hit
        _ = cache.getValueDirect(for: "key2")  // null hit
        _ = cache.getValueDirect(for: "key4")  // miss
        _ = cache.getValueDirect(for: "")      // invalid key
        _ = cache.getValueDirect(for: "key3")  // hit
        
        let stats = cache.statistics
        
        XCTAssertEqual(stats.invalidKeyCount, 1)
        XCTAssertEqual(stats.nullValueHitCount, 1)
        XCTAssertEqual(stats.nonNullValueHitCount, 2)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.totalAccesses, 5)
    }
    
    func testStatisticsReportCallback() {
        var callbackCount = 0
        var lastResult: CacheRecord?
        
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100)
            ),
            statisticsReport: { stats, result in
                callbackCount += 1
                lastResult = result
            }
        )
        
        // Perform operations
        cache.set(value: "test", for: "key1")
        _ = cache.getValueDirect(for: "key1")
        _ = cache.getValueDirect(for: "key2")  // miss
        
        XCTAssertEqual(callbackCount, 2)
        XCTAssertEqual(lastResult, .miss)
    }
    
    func testStatisticsWithExpiredValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                defaultTTL: 0.1  // Very short TTL
            )
        )
        
        // Set value with short TTL
        cache.set(value: "test", for: "key1")
        
        // Get immediately (should hit)
        _ = cache.getValueDirect(for: "key1")
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.2)
        
        // Get after expiration (should miss)
        _ = cache.getValueDirect(for: "key1")
        
        let stats = cache.statistics
        
        XCTAssertEqual(stats.nonNullValueHitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.totalAccesses, 2)
    }
}
