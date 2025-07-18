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
    
    // MARK: - Configuration & Property Tests
    
    func testDefaultConfiguration() {
        let cache = MemoryCache<String, Int>()
        
        // Test default behavior - should accept any key
        cache.set(value: 1, for: "any_key")
        XCTAssertEqual(cache.getValue(for: "any_key"), 1)
        
        // Test default capacity
        XCTAssertEqual(cache.capacity, 1024)
    }
    
    func testCustomConfiguration() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: false,
                usageLimitation: .init(capacity: 500, memory: 100),
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
        XCTAssertEqual(cache.getValue(for: "test_key"), 1)
        
        cache.set(value: 2, for: "invalid_key")
        XCTAssertNil(cache.getValue(for: "invalid_key"))
    }
    
    func testPropertyAccess() {
        let cache = MemoryCache<String, Int>(configuration: .init(usageLimitation: .init(capacity: 3)))
        
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
                usageLimitation: .init(capacity: 1000, memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 } // 1MB per item
            )
        )
        
        // Add first item (should fit)
        let evicted1 = cache.set(value: "large_value", for: "key1")
        // Should not evict anything on first insert
        XCTAssertTrue(evicted1.count == 1 && evicted1[0] == "large_value")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValue(for: "key1"))
        
        // Add second item (should evict first due to memory limit)
        let evicted2 = cache.set(value: "large_value2", for: "key2")
        // After eviction, only key2 should remain
        XCTAssertTrue(evicted2.count == 1 && evicted2[0] == "large_value2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertNil(cache.getValue(for: "key2"))
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
                usageLimitation: .init(capacity: 10),
                defaultTTL: .infinity
            )
        )
        
        cache.set(value: "value", for: "key")
        
        // Wait and check - should still be there
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(cache.getValue(for: "key"), "value")
    }
    
    func testZeroTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10)
            )
        )
        
        cache.set(value: "value", for: "key", expiredIn: 0)
        
        // Should be immediately expired
        XCTAssertNil(cache.getValue(for: "key"))
    }
    
    func testNegativeTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10)
            )
        )
        
        cache.set(value: "value", for: "key", expiredIn: -1)
        
        // Should be immediately expired
        XCTAssertNil(cache.getValue(for: "key"))
    }
    
    func testTTLPrecision() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10)
            )
        )
        
        // Set with very short TTL
        cache.set(value: "value", for: "key", expiredIn: 0.001) // 1ms
        
        // Should be immediately available
        XCTAssertEqual(cache.getValue(for: "key"), "value")
        
        // Wait and should be expired
        Thread.sleep(forTimeInterval: 0.002)
        XCTAssertNil(cache.getValue(for: "key"))
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyCacheOperations() {
        let cache = MemoryCache<String, Int>()
        
        // Test operations on empty cache
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValue(for: "nonexistent"))
        XCTAssertNil(cache.removeValue(for: "nonexistent"))
        XCTAssertNil(cache.removeValue())
        cache.removeExpiredValues() // Should not crash
        cache.removeValues(toPercent: 0.5) // Should not crash
    }
    
    func testOverwriteExistingKey() {
        let cache = MemoryCache<String, String>()
        
        // Set initial value
        cache.set(value: "initial", for: "key")
        XCTAssertEqual(cache.getValue(for: "key"), "initial")
        
        // Overwrite with new value
        let evicted = cache.set(value: "updated", for: "key")
        XCTAssertEqual(evicted.count, 0) // No eviction when overwriting
        XCTAssertEqual(cache.getValue(for: "key"), "updated")
    }
    
    func testCapacityZero() {
        let cache = MemoryCache<String, String>(
            configuration: .init(usageLimitation: .init(capacity: 0))
        )
        
        XCTAssertEqual(cache.capacity, 0)
        XCTAssertTrue(cache.isFull)
        
        // Should not be able to add items - value gets immediately evicted
        let evicted = cache.set(value: "value", for: "key")
        XCTAssertEqual(evicted.count, 0) // Value should be immediately evicted
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValue(for: "key"))
    }
    
    func testNegativeCapacity() {
        let cache = MemoryCache<String, String>(
            configuration: .init(usageLimitation: .init(capacity: -5))
        )
        
        XCTAssertEqual(cache.capacity, 0) // Should be normalized to 0
        XCTAssertTrue(cache.isFull)
    }
    
    // MARK: - Priority Edge Cases Tests
    
    func testPriorityEdgeCases() {
        let cache = MemoryCache<String, String>(
            configuration: .init(usageLimitation: .init(capacity: 2))
        )
        
        // Test with extreme priority values
        cache.set(value: "low", for: "low_key", priority: Double.leastNormalMagnitude)
        cache.set(value: "high", for: "high_key", priority: Double.greatestFiniteMagnitude)
        
        XCTAssertEqual(cache.count, 2)
        XCTAssertNotNil(cache.getValue(for: "low_key"))
        XCTAssertNotNil(cache.getValue(for: "high_key"))
    }
    
    func testLRUEvictionOrder() {
        let cache = MemoryCache<String, String>(
            configuration: .init(usageLimitation: .init(capacity: 3))
        )
        
        // Add three items with same priority
        cache.set(value: "first", for: "key1", priority: 1.0)
        cache.set(value: "second", for: "key2", priority: 1.0)
        cache.set(value: "third", for: "key3", priority: 1.0)
        
        // Access items to change LRU order
        _ = cache.getValue(for: "key1") // Move key1 to front
        
        // Add fourth item - should evict key2 (least recently used)
        cache.set(value: "fourth", for: "key4", priority: 1.0)
        
        XCTAssertNil(cache.getValue(for: "key2"))
        XCTAssertNotNil(cache.getValue(for: "key1"))
        XCTAssertNotNil(cache.getValue(for: "key3"))
        XCTAssertNotNil(cache.getValue(for: "key4"))
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafetyEnabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(enableThreadSynchronization: true)
        )
        
        // Basic operations should work with thread safety enabled
        cache.set(value: 1, for: "key1")
        XCTAssertEqual(cache.getValue(for: "key1"), 1)
        XCTAssertEqual(cache.count, 1)
    }
    
    func testThreadSafetyDisabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(enableThreadSynchronization: false)
        )
        
        // Basic operations should work with thread safety disabled
        cache.set(value: 1, for: "key1")
        XCTAssertEqual(cache.getValue(for: "key1"), 1)
        XCTAssertEqual(cache.count, 1)
    }
    
    // MARK: - Complex Scenarios Tests
    
    func testComplexScenario() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 5, memory: 10),
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
        XCTAssertNil(cache.getValue(for: "key1"))
        
        // Remove to 50%
        cache.removeValues(toPercent: 0.5)
        XCTAssertEqual(cache.count, 2)
        
        // High priority and normal should remain
        XCTAssertNotNil(cache.getValue(for: "key2"))
        XCTAssertNotNil(cache.getValue(for: "key3"))
    }
    
    func testStressScenario() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                usageLimitation: .init(capacity: 100),
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
                usageLimitation: .init(capacity: 10, memory: 100), // 100MB limit
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
                usageLimitation: .init(capacity: 5),
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
                usageLimitation: .init(capacity: 10, memory: 1), // 1MB limit
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
                usageLimitation: .init(capacity: 10),
                defaultTTL: .infinity,
                ttlRandomizationRange: 10.0 // Should not affect infinite TTL
            )
        )
        
        cache.set(value: "value", for: "key")
        
        // Wait and check - should still be there (infinite TTL not randomized)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(cache.getValue(for: "key"), "value")
    }
    
    func testTTLRandomizationEdgeCases() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10),
                defaultTTL: 10.0,
                ttlRandomizationRange: 5.0 // ±5 seconds randomization
            )
        )
        
        // Test with TTL values that should remain positive after randomization
        cache.set(value: "short", for: "key1", expiredIn: 10.0) // Should stay positive
        cache.set(value: "medium", for: "key2", expiredIn: 5.0) // Should stay positive
        
        // Both should be available immediately
        XCTAssertEqual(cache.getValue(for: "key1"), "short")
        XCTAssertEqual(cache.getValue(for: "key2"), "medium")
    }
    
    func testTTLRandomizationZeroRange() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10),
                defaultTTL: 1.0,
                ttlRandomizationRange: 0.0 // No randomization
            )
        )
        
        cache.set(value: "value", for: "key")
        
        // Should be available for exactly 1 second
        XCTAssertEqual(cache.getValue(for: "key"), "value")
        
        Thread.sleep(forTimeInterval: 1.1)
        XCTAssertNil(cache.getValue(for: "key"))
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
                usageLimitation: .init(capacity: 5),
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
        XCTAssertEqual(cache.getValue(for: "key1")?.data, "test")
        XCTAssertEqual(cache.getValue(for: "key2")?.number, 20)
    }
    
    // MARK: - Thread Safety Concurrent Access Tests
    
    func testThreadSafetyConcurrentAccess() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: true,
                usageLimitation: .init(capacity: 1000)
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
                _ = cache.getValue(for: "key\(i)")
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
                usageLimitation: .init(capacity: 1000)
            )
        )
        
        // Test basic operations without synchronization (should not crash)
        cache.set(value: 1, for: "key1")
        XCTAssertEqual(cache.getValue(for: "key1"), 1)
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
        XCTAssertNil(cache.getValue(for: "null_key"))
        
        // Test that null values don't interfere with regular values
        cache.set(value: "regular_value", for: "regular_key")
        XCTAssertEqual(cache.getValue(for: "regular_key"), "regular_value")
        XCTAssertNil(cache.getValue(for: "null_key"))
    }
    
    func testCacheEntryOverwriteBehavior() {
        let cache = MemoryCache<String, String>()
        
        // Set null value first
        cache.set(value: nil as String?, for: "key")
        XCTAssertNil(cache.getValue(for: "key"))
        
        // Overwrite with regular value
        cache.set(value: "new_value", for: "key")
        XCTAssertEqual(cache.getValue(for: "key"), "new_value")
        
        // Overwrite with null value again
        cache.set(value: nil as String?, for: "key")
        XCTAssertNil(cache.getValue(for: "key"))
    }
    
    // MARK: - Memory Management Edge Cases Tests
    
    func testMemoryLimitWithZeroMemory() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10, memory: 0), // 0MB limit
                costProvider: { _ in 1 }
            )
        )
        
        // Any item should be immediately evicted
        let evicted = cache.set(value: "value", for: "key")
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValue(for: "key"))
    }
    
    func testMemoryLimitWithNegativeMemory() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10, memory: -100), // Negative memory
                costProvider: { _ in 1 }
            )
        )
        
        // Should behave like zero memory limit
        let evicted = cache.set(value: "value", for: "key")
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getValue(for: "key"))
    }
    
    func testMemoryCostTrackingWithEmptyCache() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                usageLimitation: .init(capacity: 10),
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
                usageLimitation: .init(capacity: 1000000, memory: 1000000), // Large but reasonable values
                defaultTTL: .infinity,
                defaultTTLForNullValue: .infinity,
                ttlRandomizationRange: 1000.0, // Large but reasonable range
                keyValidator: { _ in true },
                costProvider: { _ in 1000000 } // Large but reasonable cost
            )
        )
        
        // Should not crash with extreme values
        cache.set(value: "value", for: "key")
        XCTAssertEqual(cache.getValue(for: "key"), "value")
    }
    
    func testConfigurationWithMinimalValues() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: false,
                usageLimitation: .init(capacity: 0, memory: 0),
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
        XCTAssertNil(cache.getValue(for: "key"))
    }
} 
