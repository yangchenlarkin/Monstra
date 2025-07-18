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
} 
