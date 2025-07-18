//
//  MemoryCacheTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/5/21.
//

import XCTest
@testable import Monstore

/// Comprehensive tests for MemoryCache functionality including key validation,
/// null value caching, TTL randomization, and basic operations.
final class MemoryCacheTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testBasicSetAndGet() {
        let cache = MemoryCache<String, String>()
        
        // Test basic set and get
        cache.set(value: "value1", for: "key1", priority: 1.0)
        XCTAssertEqual(cache.getValue(for: "key1"), "value1")
        
        // Test nil value
        cache.set(value: nil as String?, for: "key2")
        XCTAssertNil(cache.getValue(for: "key2"))
    }
    
    func testCapacityLimit() {
        let cache = MemoryCache<String, Int>(configuration: .init(usageLimitation: .init(capacity: 2)))
        
        // Fill cache to capacity
        cache.set(value: 1, for: "key1")
        cache.set(value: 2, for: "key2")
        XCTAssertEqual(cache.count, 2)
        
        // Add one more, should evict the least recently used
        cache.set(value: 3, for: "key3")
        XCTAssertEqual(cache.count, 2)
        
        // The first key should be evicted
        XCTAssertNil(cache.getValue(for: "key1"))
    }
    
    // MARK: - Key Validation Tests
    
    func testCustomKeyValidator() {
        // Create cache with custom key validator that only accepts non-empty strings
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10),
                keyValidator: { key in
                    return !key.isEmpty && key.count <= 10
                }
            )
        )
        
        // Valid keys should work
        cache.set(value: "value1", for: "valid")
        XCTAssertEqual(cache.getValue(for: "valid"), "value1")
        
        // Invalid keys should be rejected
        cache.set(value: "value2", for: "")
        XCTAssertNil(cache.getValue(for: ""))
        
        cache.set(value: "value3", for: "toolongkeythatisinvalid")
        XCTAssertNil(cache.getValue(for: "toolongkeythatisinvalid"))
    }
    
    func testNumericKeyValidator() {
        // Create cache with numeric key validator
        let cache = MemoryCache<Int, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10),
                keyValidator: { key in
                    return key > 0 && key <= 1000
                }
            )
        )
        
        // Valid keys should work
        cache.set(value: "value1", for: 1)
        XCTAssertEqual(cache.getValue(for: 1), "value1")
        
        // Invalid keys should be rejected
        cache.set(value: "value2", for: 0)
        XCTAssertNil(cache.getValue(for: 0))
        
        cache.set(value: "value3", for: 1001)
        XCTAssertNil(cache.getValue(for: 1001))
    }
    
    // MARK: - Null Value Caching Tests
    
    func testNullValueCaching() {
        let cache = MemoryCache<String, String>()
        
        // Cache a null value
        cache.set(value: nil as String?, for: "null_key")
        
        // Should return nil (indicating the null value was cached)
        let result = cache.getValue(for: "null_key")
        XCTAssertNil(result)
        
        // The key should exist in the cache
        XCTAssertFalse(cache.isEmpty)
    }
    
    func testNullValueWithCustomTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10),
                defaultTTLForNullValue: 1.0 // 1 second TTL for null values
            )
        )
        
        // Cache a null value
        cache.set(value: nil as String?, for: "null_key")
        
        // Should return nil immediately
        XCTAssertNil(cache.getValue(for: "null_key"))
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 1.1)
        
        // Should return nil after expiration (key removed)
        XCTAssertNil(cache.getValue(for: "null_key"))
    }
    
    // MARK: - TTL Randomization Tests
    
    func testTTLRandomization() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10),
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
            XCTAssertEqual(cache.getValue(for: "key\(i)"), "value\(i)")
        }
    }
    
    // MARK: - Priority Tests
    
    func testPriorityEviction() {
        let cache = MemoryCache<String, String>(configuration: .init(usageLimitation: .init(capacity: 2)))
        
        // Add low priority item
        cache.set(value: "low", for: "low_key", priority: 0.0)
        
        // Add high priority item
        cache.set(value: "high", for: "high_key", priority: 10.0)
        
        // Add medium priority item (should evict low priority)
        cache.set(value: "medium", for: "medium_key", priority: 5.0)
        
        // Low priority item should be evicted
        XCTAssertNil(cache.getValue(for: "low_key"))
        
        // High and medium priority items should remain
        XCTAssertEqual(cache.getValue(for: "high_key"), "high")
        XCTAssertEqual(cache.getValue(for: "medium_key"), "medium")
    }
    
    // MARK: - Performance Tests
    
    func testBulkOperations() {
        let cache = MemoryCache<String, Int>(configuration: .init(usageLimitation: .init(capacity: 1000)))
        
        measure {
            // Bulk insert
            for i in 0..<500 {
                cache.set(value: i, for: "key\(i)")
            }
            
            // Bulk read
            for i in 0..<500 {
                _ = cache.getValue(for: "key\(i)")
            }
            
            // Bulk remove
            for i in 0..<500 {
                cache.removeValue(for: "key\(i)")
            }
        }
    }
    
    // MARK: - Cache Management Tests
    
    func testRemoveValue() {
        let cache = MemoryCache<String, String>(configuration: .init(usageLimitation: .init(capacity: 3)))
        
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
                usageLimitation: .init(capacity: 10),
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
        let cache = MemoryCache<String, Int>(configuration: .init(usageLimitation: .init(capacity: 10)))
        
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
                usageLimitation: .init(capacity: 10),
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
        XCTAssertNotNil(cache.getValue(for: "valid1"))
        XCTAssertNotNil(cache.getValue(for: "valid2"))
        XCTAssertNotNil(cache.getValue(for: "valid3"))
    }
} 
