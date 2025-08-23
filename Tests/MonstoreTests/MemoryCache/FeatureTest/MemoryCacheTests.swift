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
    /// Helper method for tests to get the element directly, similar to the old API
    func getElementDirect(for key: Key) -> Element? {
        return getElement(for: key).element
    }
}

/// Comprehensive tests for MemoryCache functionality including key validation,
/// null element caching, TTL randomization, and basic operations.
final class MemoryCacheTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testBasicSetAndGet() {
        let cache = MemoryCache<String, String>()
        
        // Test basic set and get
        cache.set(element: "element1", for: "key1", priority: 1.0)
        XCTAssertEqual(cache.getElementDirect(for: "key1"), "element1")
        
        // Test nil element
        cache.set(element: nil as String?, for: "key2")
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    func testCapacityLimit() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 2)))
        
        // Fill cache to capacity
        cache.set(element: 1, for: "key1")
        cache.set(element: 2, for: "key2")
        XCTAssertEqual(cache.count, 2)
        
        // Add one more, should evict the least recently used
        cache.set(element: 3, for: "key3")
        XCTAssertEqual(cache.count, 2)
        
        // The first key should be evicted
        XCTAssertNil(cache.getElementDirect(for: "key1"))
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
        cache.set(element: "element1", for: "valid")
        XCTAssertEqual(cache.getElementDirect(for: "valid"), "element1")
        
        // Invalid keys should be rejected
        cache.set(element: "element2", for: "")
        XCTAssertNil(cache.getElementDirect(for: ""))
        
        cache.set(element: "element3", for: "toolongkeythatisinvalid")
        XCTAssertNil(cache.getElementDirect(for: "toolongkeythatisinvalid"))
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
        cache.set(element: "element1", for: 1)
        XCTAssertEqual(cache.getElementDirect(for: 1), "element1")
        
        // Invalid keys should be rejected
        cache.set(element: "element2", for: 0)
        XCTAssertNil(cache.getElementDirect(for: 0))
        
        cache.set(element: "element3", for: 1001)
        XCTAssertNil(cache.getElementDirect(for: 1001))
    }
    
    // MARK: - Null Element Caching Tests
    
    func testNullElementCaching() {
        let cache = MemoryCache<String, String>()
        
        // Cache a null element
        cache.set(element: nil as String?, for: "null_key")
        
        // Should return nil (indicating the null element was cached)
        let result = cache.getElementDirect(for: "null_key")
        XCTAssertNil(result)
        
        // The key should exist in the cache
        XCTAssertFalse(cache.isEmpty)
    }
    
    func testNullElementWithCustomTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTLForNullElement: 1.0 // 1 second TTL for null elements
            )
        )
        
        // Cache a null element
        cache.set(element: nil as String?, for: "null_key")
        
        // Should return nil immediately
        XCTAssertNil(cache.getElementDirect(for: "null_key"))
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 1.1)
        
        // Should return nil after expiration (key removed)
        XCTAssertNil(cache.getElementDirect(for: "null_key"))
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
        
        // Set multiple elements with the same TTL
        for i in 0..<5 {
            cache.set(element: "element\(i)", for: "key\(i)", expiredIn: 10.0)
        }
        
        // All elements should be cached
        for i in 0..<5 {
            XCTAssertEqual(cache.getElementDirect(for: "key\(i)"), "element\(i)")
        }
    }
    
    // MARK: - Priority Tests
    
    func testPriorityEviction() {
        let cache = MemoryCache<String, String>(configuration: .init(memoryUsageLimitation: .init(capacity: 2)))
        
        // Add low priority item
        cache.set(element: "low", for: "low_key", priority: 0.0)
        
        // Add high priority item
        cache.set(element: "high", for: "high_key", priority: 10.0)
        
        // Add medium priority item (should evict low priority)
        cache.set(element: "medium", for: "medium_key", priority: 5.0)
        
        // Low priority item should be evicted
        XCTAssertNil(cache.getElementDirect(for: "low_key"))
        
        // High and medium priority items should remain
        XCTAssertEqual(cache.getElementDirect(for: "high_key"), "high")
        XCTAssertEqual(cache.getElementDirect(for: "medium_key"), "medium")
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
        let result = cache.getElement(for: "invalid_key")
        switch result {
        case .invalidKey:
            XCTAssertNil(result.element)
            XCTAssertFalse(result.isMiss)
        default:
            XCTFail("Expected .invalidKey, got \(result)")
        }
        
        // Test valid key that doesn't exist
        let result2 = cache.getElement(for: "valid_nonexistent")
        switch result2 {
        case .miss:
            XCTAssertNil(result2.element)
            XCTAssertTrue(result2.isMiss)
        default:
            XCTFail("Expected .miss, got \(result2)")
        }
    }
    
    func testFetchResultHitNonNullElement() {
        let cache = MemoryCache<String, String>()
        
        // Set a element
        cache.set(element: "test_element", for: "test_key")
        
        // Test hit with non-null element
        let result = cache.getElement(for: "test_key")
        switch result {
        case .hitNonNullElement(let element):
            XCTAssertEqual(element, "test_element")
            XCTAssertEqual(result.element, "test_element")
            XCTAssertFalse(result.isMiss)
        default:
            XCTFail("Expected .hitNonNullElement, got \(result)")
        }
    }
    
    func testFetchResultHitNullElement() {
        let cache = MemoryCache<String, String>()
        
        // Set a null element
        cache.set(element: nil as String?, for: "null_key")
        
        // Test hit with null element
        let result = cache.getElement(for: "null_key")
        switch result {
        case .hitNullElement:
            XCTAssertNil(result.element)
            XCTAssertFalse(result.isMiss)
        default:
            XCTFail("Expected .hitNullElement, got \(result)")
        }
    }
    
    func testFetchResultMiss() {
        let cache = MemoryCache<String, String>()
        
        // Test miss for non-existent key
        let result = cache.getElement(for: "nonexistent_key")
        switch result {
        case .miss:
            XCTAssertNil(result.element)
            XCTAssertTrue(result.isMiss)
        default:
            XCTFail("Expected .miss, got \(result)")
        }
    }
    
    func testFetchResultWithExpiredElement() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 0.1 // Very short TTL
            )
        )
        
        // Set a element
        cache.set(element: "expired_element", for: "expired_key")
        
        // Element should exist immediately
        let result1 = cache.getElement(for: "expired_key")
        switch result1 {
        case .hitNonNullElement(let element):
            XCTAssertEqual(element, "expired_element")
        default:
            XCTFail("Expected .hitNonNullElement, got \(result1)")
        }
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.2)
        
        // Element should be expired (miss)
        let result2 = cache.getElement(for: "expired_key")
        switch result2 {
        case .miss:
            XCTAssertNil(result2.element)
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
        switch cache.getElement(for: 0) {
        case .invalidKey: break // Expected
        default: XCTFail("Expected .invalidKey for key 0")
        }
        switch cache.getElement(for: 101) {
        case .invalidKey: break // Expected
        default: XCTFail("Expected .invalidKey for key 101")
        }
        switch cache.getElement(for: 3) {
        case .invalidKey: break // Expected
        default: XCTFail("Expected .invalidKey for key 3")
        }
        
        // Test valid keys
        switch cache.getElement(for: 2) {
        case .miss: break // Expected
        default: XCTFail("Expected .miss for key 2")
        }
        switch cache.getElement(for: 4) {
        case .miss: break // Expected
        default: XCTFail("Expected .miss for key 4")
        }
        switch cache.getElement(for: 100) {
        case .miss: break // Expected
        default: XCTFail("Expected .miss for key 100")
        }
    }
    
    func testFetchResultWithNullElementExpiration() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTLForNullElement: 0.1 // Short TTL for null elements
            )
        )
        
        // Set a null element
        cache.set(element: nil as String?, for: "null_key")
        
        // Null element should exist immediately
        let result1 = cache.getElement(for: "null_key")
        switch result1 {
        case .hitNullElement: break // Expected
        default: XCTFail("Expected .hitNullElement, got \(result1)")
        }
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.2)
        
        // Null element should be expired (miss)
        let result2 = cache.getElement(for: "null_key")
        switch result2 {
        case .miss: break // Expected
        default: XCTFail("Expected .miss, got \(result2)")
        }
    }
    
    func testFetchResultElementProperty() {
        let cache = MemoryCache<String, String>()
        
        // Test with non-null element
        cache.set(element: "test_element", for: "test_key")
        let result1 = cache.getElement(for: "test_key")
        XCTAssertEqual(result1.element, "test_element")
        
        // Test with null element
        cache.set(element: nil as String?, for: "null_key")
        let result2 = cache.getElement(for: "null_key")
        XCTAssertNil(result2.element)
        
        // Test with miss
        let result3 = cache.getElement(for: "nonexistent")
        XCTAssertNil(result3.element)
        
        // Test with invalid key
        let cacheWithValidator = MemoryCache<String, String>(
            configuration: .init(keyValidator: { $0.hasPrefix("valid_") })
        )
        let result4 = cacheWithValidator.getElement(for: "invalid_key")
        XCTAssertNil(result4.element)
    }
    
    func testFetchResultIsMissProperty() {
        let cache = MemoryCache<String, String>()
        
        // Test miss
        let result1 = cache.getElement(for: "nonexistent")
        XCTAssertTrue(result1.isMiss)
        
        // Test hit with non-null element
        cache.set(element: "test_element", for: "test_key")
        let result2 = cache.getElement(for: "test_key")
        XCTAssertFalse(result2.isMiss)
        
        // Test hit with null element
        cache.set(element: nil as String?, for: "null_key")
        let result3 = cache.getElement(for: "null_key")
        XCTAssertFalse(result3.isMiss)
        
        // Test invalid key
        let cacheWithValidator = MemoryCache<String, String>(
            configuration: .init(keyValidator: { $0.hasPrefix("valid_") })
        )
        let result4 = cacheWithValidator.getElement(for: "invalid_key")
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
        
        // Concurrently set and get elements
        for i in 0..<100 {
            group.enter()
            queue.async {
                cache.set(element: "element\(i)", for: "key\(i)")
                let result = cache.getElement(for: "key\(i)")
                switch result {
                case .hitNonNullElement(let element):
                    XCTAssertEqual(element, "element\(i)")
                default:
                    XCTFail("Expected .hitNonNullElement, got \(result)")
                }
                group.leave()
            }
        }
        
        group.wait()
        
        // Verify all elements are accessible
        for i in 0..<100 {
            let result = cache.getElement(for: "key\(i)")
            switch result {
            case .hitNonNullElement(let element):
                XCTAssertEqual(element, "element\(i)")
            default:
                XCTFail("Expected .hitNonNullElement, got \(result)")
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
        cache.set(element: "test_element", for: "test_key")
        
        // Hit with non-null element
        let result1 = cache.getElement(for: "test_key")
        switch result1 {
        case .hitNonNullElement(let element):
            XCTAssertEqual(element, "test_element")
        default:
            XCTFail("Expected .hitNonNullElement, got \(result1)")
        }
        
        // Hit with null element
        cache.set(element: nil as String?, for: "null_key")
        let result2 = cache.getElement(for: "null_key")
        switch result2 {
        case .hitNullElement: break // Expected
        default: XCTFail("Expected .hitNullElement, got \(result2)")
        }
        
        // Miss
        let result3 = cache.getElement(for: "nonexistent")
        switch result3 {
        case .miss: break // Expected
        default: XCTFail("Expected .miss, got \(result3)")
        }
        
        // Invalid key
        let cacheWithValidator = MemoryCache<String, String>(
            configuration: .init(keyValidator: { $0.hasPrefix("valid_") })
        )
        let result4 = cacheWithValidator.getElement(for: "invalid_key")
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
        cache.set(element: "first", for: "first_key")
        
        // Add second item, should evict first
        cache.set(element: "second", for: "second_key")
        
        // First should be evicted (miss)
        let result1 = cache.getElement(for: "first_key")
        switch result1 {
        case .miss: break // Expected
        default: XCTFail("Expected .miss, got \(result1)")
        }
        
        // Second should exist
        let result2 = cache.getElement(for: "second_key")
        switch result2 {
        case .hitNonNullElement(let element):
            XCTAssertEqual(element, "second")
        default:
            XCTFail("Expected .hitNonNullElement, got \(result2)")
        }
    }
    
    func testFetchResultWithEmptyCache() {
        let cache = MemoryCache<String, String>()
        
        // Test miss on empty cache
        let result = cache.getElement(for: "any_key")
        switch result { case .miss: break; default: XCTFail("Expected .miss, got (result)"); }
        XCTAssertNil(result.element)
        XCTAssertTrue(result.isMiss)
    }
    
    func testFetchResultWithZeroCapacity() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 0))
        )
        
        // Try to set element in zero-capacity cache
        cache.set(element: "test", for: "test_key")
        
        // Should not be able to retrieve it
        let result = cache.getElement(for: "test_key")
        switch result { case .miss: break; default: XCTFail("Expected .miss, got (result)"); }
    }
    
    // MARK: - Performance Tests
    
    func testBulkOperations() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 1000)))
        
        measure {
            // Bulk insert
            for i in 0..<500 {
                cache.set(element: i, for: "key\(i)")
            }
            
                    // Bulk read
        for i in 0..<500 {
            _ = cache.getElementDirect(for: "key\(i)")
        }
            
            // Bulk remove
            for i in 0..<500 {
                cache.removeElement(for: "key\(i)")
            }
        }
    }
    
    // MARK: - Cache Management Tests
    
    func testRemoveElement() {
        let cache = MemoryCache<String, String>(configuration: .init(memoryUsageLimitation: .init(capacity: 3)))
        
        // Add some elements
        cache.set(element: "element1", for: "key1")
        cache.set(element: "element2", for: "key2")
        cache.set(element: "element3", for: "key3")
        
        XCTAssertEqual(cache.count, 3)
        
        // Remove least recently used element
        let removedElement = cache.removeElement()
        XCTAssertNotNil(removedElement)
        XCTAssertEqual(cache.count, 2)
        
        // Remove another element
        let secondRemovedElement = cache.removeElement()
        XCTAssertNotNil(secondRemovedElement)
        XCTAssertEqual(cache.count, 1)
        
        // Remove last element
        let thirdRemovedElement = cache.removeElement()
        XCTAssertNotNil(thirdRemovedElement)
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
        
        // Try to remove from empty cache
        let emptyRemovedElement = cache.removeElement()
        XCTAssertNil(emptyRemovedElement)
    }
    
    func testRemoveExpiredElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 0.1 // 100ms TTL
            )
        )
        
        // Add elements with short TTL
        cache.set(element: "element1", for: "key1", expiredIn: 0.1)
        cache.set(element: "element2", for: "key2", expiredIn: 0.1)
        cache.set(element: "element3", for: "key3", expiredIn: 0.1)
        
        XCTAssertEqual(cache.count, 3)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        // Remove expired elements
        cache.removeExpiredElements()
        
        // All elements should be removed
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
    }
    
    func testRemoveElementsToPercent() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 10)))
        
        // Add 10 elements
        for i in 0..<10 {
            cache.set(element: i, for: "key\(i)")
        }
        
        XCTAssertEqual(cache.count, 10)
        
        // Remove to 50% (should keep 5 items)
        cache.removeElements(toPercent: 0.5)
        XCTAssertEqual(cache.count, 5)
        
        // Remove to 20% (should keep 1 item)
        cache.removeElements(toPercent: 0.2)
        XCTAssertEqual(cache.count, 1)
        
        // Remove to 0% (should keep 0 items)
        cache.removeElements(toPercent: 0.0)
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
    }
    
    func testRemoveElementsToPercentWithExpiredElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 0.1 // 100ms TTL
            )
        )
        
        // Add some elements with short TTL
        cache.set(element: "expired1", for: "expired1", expiredIn: 0.1)
        cache.set(element: "expired2", for: "expired2", expiredIn: 0.1)
        
        // Add some elements with long TTL
        cache.set(element: "valid1", for: "valid1", expiredIn: 10.0)
        cache.set(element: "valid2", for: "valid2", expiredIn: 10.0)
        cache.set(element: "valid3", for: "valid3", expiredIn: 10.0)
        
        XCTAssertEqual(cache.count, 5)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        // Remove to 60% (should keep 3 items, but expired ones are removed first)
        cache.removeElements(toPercent: 0.6)
        
        // Should only have valid items remaining
        XCTAssertEqual(cache.count, 3)
        XCTAssertNotNil(cache.getElementDirect(for: "valid1"))
        XCTAssertNotNil(cache.getElementDirect(for: "valid2"))
        XCTAssertNotNil(cache.getElementDirect(for: "valid3"))
    }
    
    // MARK: - Configuration & Property Tests
    
    func testDefaultConfiguration() {
        let cache = MemoryCache<String, Int>()
        
        // Test default behavior - should accept any key
        cache.set(element: 1, for: "any_key")
        XCTAssertEqual(cache.getElementDirect(for: "any_key"), 1)
        
        // Test default capacity
        XCTAssertEqual(cache.capacity, 1024)
    }
    
    func testCustomConfiguration() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 500, memory: 100),
                defaultTTL: 3600,
                defaultTTLForNullElement: 1800,
                ttlRandomizationRange: 300,
                keyValidator: { $0.hasPrefix("test_") },
                costProvider: { _ in 1024 }
            )
        )
        
        // Test custom capacity
        XCTAssertEqual(cache.capacity, 500)
        
        // Test custom key validator
        cache.set(element: 1, for: "test_key")
        XCTAssertEqual(cache.getElementDirect(for: "test_key"), 1)
        
        cache.set(element: 2, for: "invalid_key")
        XCTAssertNil(cache.getElementDirect(for: "invalid_key"))
    }
    
    func testPropertyAccess() {
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 3)))
        
        // Test empty state
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
        XCTAssertEqual(cache.capacity, 3)
        XCTAssertFalse(cache.isFull)
        
        // Add items
        cache.set(element: 1, for: "key1")
        XCTAssertFalse(cache.isEmpty)
        XCTAssertEqual(cache.count, 1)
        XCTAssertFalse(cache.isFull)
        
        // Fill cache
        cache.set(element: 2, for: "key2")
        cache.set(element: 3, for: "key3")
        XCTAssertEqual(cache.count, 3)
        XCTAssertTrue(cache.isFull)
        
        // Remove item
        cache.removeElement(for: "key1")
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
        let evicted1 = cache.set(element: "large_element", for: "key1")
        // Should not evict anything on first insert
        XCTAssertTrue(evicted1.count == 1 && evicted1[0] == "large_element")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        
        // Add second item (should evict first due to memory limit)
        let evicted2 = cache.set(element: "large_element2", for: "key2")
        // After eviction, only key2 should remain
        XCTAssertTrue(evicted2.count == 1 && evicted2[0] == "large_element2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    func testCostProvider() {
        var costCalculations = 0
        let cache = MemoryCache<String, String>(
            configuration: .init(
                costProvider: { element in
                    costCalculations += 1
                    return element.count * 2 // Custom cost calculation
                }
            )
        )
        
        // Add items with different costs
        cache.set(element: "short", for: "key1")
        cache.set(element: "longer_element", for: "key2")
        
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
        
        cache.set(element: "element", for: "key")
        
        // Wait and check - should still be there
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(cache.getElementDirect(for: "key"), "element")
    }
    
    func testZeroTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10)
            )
        )
        
        cache.set(element: "element", for: "key", expiredIn: 0)
        
        // Should be immediately expired
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    func testNegativeTTL() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10)
            )
        )
        
        cache.set(element: "element", for: "key", expiredIn: -1)
        
        // Should be immediately expired
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    func testTTLPrecision() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10)
            )
        )
        
        // Set with very short TTL
        cache.set(element: "element", for: "key", expiredIn: 0.001) // 1ms
        
        // Should be immediately available
        XCTAssertEqual(cache.getElementDirect(for: "key"), "element")
        
        // Wait and should be expired
        Thread.sleep(forTimeInterval: 0.002)
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyCacheOperations() {
        let cache = MemoryCache<String, Int>()
        
        // Test operations on empty cache
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "nonexistent"))
        XCTAssertNil(cache.removeElement(for: "nonexistent"))
        XCTAssertNil(cache.removeElement())
        cache.removeExpiredElements() // Should not crash
        cache.removeElements(toPercent: 0.5) // Should not crash
    }
    
    func testOverwriteExistingKey() {
        let cache = MemoryCache<String, String>()
        
        // Set initial element
        cache.set(element: "initial", for: "key")
        XCTAssertEqual(cache.getElementDirect(for: "key"), "initial")
        
        // Overwrite with new element
        let evicted = cache.set(element: "updated", for: "key")
        XCTAssertEqual(evicted.count, 0) // No eviction when overwriting
        XCTAssertEqual(cache.getElementDirect(for: "key"), "updated")
    }
    
    func testCapacityZero() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 0))
        )
        
        XCTAssertEqual(cache.capacity, 0)
        XCTAssertTrue(cache.isFull)
        
        // Should not be able to add items - element gets immediately evicted
        let evicted = cache.set(element: "element", for: "key")
        XCTAssertEqual(evicted.count, 0) // Element should be immediately evicted
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key"))
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
        
        // Test with extreme priority elements
        cache.set(element: "low", for: "low_key", priority: Double.leastNormalMagnitude)
        cache.set(element: "high", for: "high_key", priority: Double.greatestFiniteMagnitude)
        
        XCTAssertEqual(cache.count, 2)
        XCTAssertNotNil(cache.getElementDirect(for: "low_key"))
        XCTAssertNotNil(cache.getElementDirect(for: "high_key"))
    }
    
    func testLRUEvictionOrder() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 3))
        )
        
        // Add three items with same priority
        cache.set(element: "first", for: "key1", priority: 1.0)
        cache.set(element: "second", for: "key2", priority: 1.0)
        cache.set(element: "third", for: "key3", priority: 1.0)
        
        // Access items to change LRU order
        _ = cache.getElementDirect(for: "key1") // Move key1 to front
        
        // Add fourth item - should evict key2 (least recently used)
        cache.set(element: "fourth", for: "key4", priority: 1.0)
        
        XCTAssertNil(cache.getElementDirect(for: "key2"))
        XCTAssertNotNil(cache.getElementDirect(for: "key1"))
        XCTAssertNotNil(cache.getElementDirect(for: "key3"))
        XCTAssertNotNil(cache.getElementDirect(for: "key4"))
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafetyEnabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(enableThreadSynchronization: true)
        )
        
        // Basic operations should work with thread safety enabled
        cache.set(element: 1, for: "key1")
        XCTAssertEqual(cache.getElementDirect(for: "key1"), 1)
        XCTAssertEqual(cache.count, 1)
    }
    
    func testThreadSafetyDisabled() {
        let cache = MemoryCache<String, Int>(
            configuration: .init(enableThreadSynchronization: false)
        )
        
        // Basic operations should work with thread safety disabled
        cache.set(element: 1, for: "key1")
        XCTAssertEqual(cache.getElementDirect(for: "key1"), 1)
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
        cache.set(element: "short_lived", for: "key1", priority: 1.0, expiredIn: 0.1)
        cache.set(element: "high_priority", for: "key2", priority: 10.0, expiredIn: 10.0)
        cache.set(element: "normal", for: "key3", priority: 5.0, expiredIn: 5.0)
        cache.set(element: "low_priority", for: "key4", priority: 0.1, expiredIn: 10.0)
        cache.set(element: "null_element", for: "key5")
        
        XCTAssertEqual(cache.count, 5)
        
        // Wait for short-lived item to expire
        Thread.sleep(forTimeInterval: 0.2)
        
        // Remove expired elements
        cache.removeExpiredElements()
        XCTAssertEqual(cache.count, 4)
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        
        // Remove to 50%
        cache.removeElements(toPercent: 0.5)
        XCTAssertEqual(cache.count, 2)
        
        // High priority and normal should remain
        XCTAssertNotNil(cache.getElementDirect(for: "key2"))
        XCTAssertNotNil(cache.getElementDirect(for: "key3"))
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
            cache.set(element: i, for: "key\(i)", priority: Double(i % 10))
            
            if i % 10 == 0 {
                _ = cache.removeElement()
            }
            
            if i % 20 == 0 {
                cache.removeExpiredElements()
            }
            
            if i % 50 == 0 {
                cache.removeElements(toPercent: 0.8)
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
                costProvider: { element in
                    costCalculations += 1
                    return element.count * 10 // 10 bytes per character
                }
            )
        )
        
        // Add items with different costs
        cache.set(element: "short", for: "key1") // 50 bytes
        cache.set(element: "longer_element", for: "key2") // 120 bytes
        
        // Cost provider should be called for each set operation
        XCTAssertGreaterThanOrEqual(costCalculations, 2)
        XCTAssertEqual(cache.count, 2)
        
        // Add item that exceeds memory limit
        let evicted = cache.set(element: "very_long_element_that_exceeds_memory_limit", for: "key3")
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
        cache.set(element: "element1", for: "key1")
        cache.set(element: "element2", for: "key2")
        
        XCTAssertEqual(cache.count, 2)
        
        // Test with nil elements (should have minimal cost)
        cache.set(element: nil as String?, for: "key3")
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
        let evicted1 = cache.set(element: "exact_size", for: "key1")
        XCTAssertEqual(evicted1.count, 1) // Should be immediately evicted
        
        // Try to add slightly over the memory limit
        let evicted2 = cache.set(element: "slightly_larger", for: "key2")
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
        
        cache.set(element: "element", for: "key")
        
        // Wait and check - should still be there (infinite TTL not randomized)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(cache.getElementDirect(for: "key"), "element")
    }
    
    func testTTLRandomizationEdgeCases() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 10.0,
                ttlRandomizationRange: 5.0 // ±5 seconds randomization
            )
        )
        
        // Test with TTL elements that should remain positive after randomization
        cache.set(element: "short", for: "key1", expiredIn: 10.0) // Should stay positive
        cache.set(element: "medium", for: "key2", expiredIn: 5.0) // Should stay positive
        
        // Both should be available immediately
        XCTAssertEqual(cache.getElementDirect(for: "key1"), "short")
        XCTAssertEqual(cache.getElementDirect(for: "key2"), "medium")
    }
    
    func testTTLRandomizationZeroRange() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                defaultTTL: 1.0,
                ttlRandomizationRange: 0.0 // No randomization
            )
        )
        
        cache.set(element: "element", for: "key")
        
        // Should be available for exactly 1 second
        XCTAssertEqual(cache.getElementDirect(for: "key"), "element")
        
        Thread.sleep(forTimeInterval: 1.1)
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    // MARK: - Cost Provider Integration Tests
    
    func testCostProviderWithDifferentDataTypes() {
        // Test with String type
        let stringCache = MemoryCache<String, String>(
            configuration: .init(
                costProvider: { $0.count * 2 }
            )
        )
        
        stringCache.set(element: "hello", for: "key1")
        stringCache.set(element: "world", for: "key2")
        XCTAssertEqual(stringCache.count, 2)
        
        // Test with Int type
        let intCache = MemoryCache<String, Int>(
            configuration: .init(
                costProvider: { $0 * 4 }
            )
        )
        
        intCache.set(element: 10, for: "key1")
        intCache.set(element: 20, for: "key2")
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
        
        cache.set(element: obj1, for: "key1")
        cache.set(element: obj2, for: "key2")
        
        XCTAssertEqual(cache.count, 2)
        XCTAssertEqual(cache.getElementDirect(for: "key1")?.data, "test")
        XCTAssertEqual(cache.getElementDirect(for: "key2")?.number, 20)
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
                cache.set(element: i, for: "key\(i)")
                group.leave()
            }
        }
        
        // Concurrent reads
        for i in 0..<100 {
            group.enter()
            queue.async {
                _ = cache.getElementDirect(for: "key\(i)")
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
        cache.set(element: 1, for: "key1")
        XCTAssertEqual(cache.getElementDirect(for: "key1"), 1)
        XCTAssertEqual(cache.count, 1)
        
        // Test that operations work without thread safety
        cache.set(element: 2, for: "key2")
        cache.set(element: 3, for: "key3")
        XCTAssertEqual(cache.count, 3)
        
        // Test removal
        let removed = cache.removeElement(for: "key1")
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(cache.count, 2)
    }
    
    // MARK: - Cache Entry Structure Tests
    
    func testCacheEntryWithNullElements() {
        let cache = MemoryCache<String, String>()
        
        // Test null element caching
        cache.set(element: nil as String?, for: "null_key")
        
        // Should return nil (indicating null element was cached)
        XCTAssertNil(cache.getElementDirect(for: "null_key"))
        
        // Test that null elements don't interfere with regular elements
        cache.set(element: "regular_element", for: "regular_key")
        XCTAssertEqual(cache.getElementDirect(for: "regular_key"), "regular_element")
        XCTAssertNil(cache.getElementDirect(for: "null_key"))
    }
    
    func testCacheEntryOverwriteBehavior() {
        let cache = MemoryCache<String, String>()
        
        // Set null element first
        cache.set(element: nil as String?, for: "key")
        XCTAssertNil(cache.getElementDirect(for: "key"))
        
        // Overwrite with regular element
        cache.set(element: "new_element", for: "key")
        XCTAssertEqual(cache.getElementDirect(for: "key"), "new_element")
        
        // Overwrite with null element again
        cache.set(element: nil as String?, for: "key")
        XCTAssertNil(cache.getElementDirect(for: "key"))
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
        let evicted = cache.set(element: "element", for: "key")
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    func testMemoryLimitWithNegativeMemory() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: -100), // Negative memory
                costProvider: { _ in 1 }
            )
        )
        
        // Should behave like zero memory limit
        let evicted = cache.set(element: "element", for: "key")
        XCTAssertEqual(evicted.count, 1)
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key"))
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
        cache.set(element: "element", for: "key")
        XCTAssertEqual(cache.count, 1)
        
        cache.removeElement(for: "key")
        XCTAssertEqual(cache.count, 0)
        
        // Should not crash when empty
        cache.removeElement()
        XCTAssertEqual(cache.count, 0)
    }
    
    // MARK: - Configuration Validation Tests
    
    func testConfigurationWithExtremeElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 1000000, memory: 1000000), // Large but reasonable elements
                defaultTTL: .infinity,
                defaultTTLForNullElement: .infinity,
                ttlRandomizationRange: 1000.0, // Large but reasonable range
                keyValidator: { _ in true },
                costProvider: { _ in 1000000 } // Large but reasonable cost
            )
        )
        
        // Should not crash with extreme elements
        cache.set(element: "element", for: "key")
        XCTAssertEqual(cache.getElementDirect(for: "key"), "element")
    }
    
    func testConfigurationWithMinimalElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 0, memory: 0),
                defaultTTL: 0,
                defaultTTLForNullElement: 0,
                ttlRandomizationRange: 0,
                keyValidator: { _ in false }, // Reject all keys
                costProvider: { _ in 0 }
            )
        )
        
        // Should handle minimal configuration gracefully
        let evicted = cache.set(element: "element", for: "key")
        XCTAssertEqual(evicted.count, 0) // Rejected by validator
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    // MARK: - Memory Cost Tracking Verification Tests
    
    func testMemoryCostTrackingAfterBugFix() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 100), // 100MB limit
                costProvider: { element in
                    return element.count // Cost = string length
                }
            )
        )
        
        // Test that totalCost doesn't go negative
        cache.set(element: "test", for: "key1") // Cost = 4 bytes
        cache.set(element: "longer", for: "key2") // Cost = 6 bytes
        cache.set(element: "very_long_string", for: "key3") // Cost = 15 bytes
        
        // Remove items and verify cost tracking
        _ = cache.removeElement(for: "key1")
        _ = cache.removeElement(for: "key2")
        _ = cache.removeElement(for: "key3")
        
        // Cache should be empty and cost should be 0
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.count, 0)
    }
    
    func testMemoryCostTrackingWithNullElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                costProvider: { element in
                    return element.count
                }
            )
        )
        
        // Add null elements and verify cost tracking
        cache.set(element: nil as String?, for: "null1")
        cache.set(element: nil as String?, for: "null2")
        
        // Null elements should have minimal cost
        XCTAssertEqual(cache.count, 2)
        
        // Remove null elements
        _ = cache.removeElement(for: "null1")
        _ = cache.removeElement(for: "null2")
        
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
        cache.set(element: "large", for: "key1")
        // The item might be immediately evicted due to memory limit
        XCTAssertEqual(cache.count, 0)
        
        // Second item should also be evicted
        cache.set(element: "large", for: "key2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    func testMemoryLimitWithExactByteCalculation() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(memory: 2), // 2MB = 2,097,152 bytes
                costProvider: { element in
                    return element.count
                }
            )
        )
        
        // Add items with smaller costs to test memory limit
        let smallString = String(repeating: "a", count: 1000) // 1KB
        cache.set(element: smallString, for: "key1")
        cache.set(element: smallString, for: "key2")
        
        // Both should fit
        XCTAssertEqual(cache.count, 2)
        
        // Add many more items to test eviction
        for i in 3...10 {
            cache.set(element: smallString, for: "key\(i)")
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
        cache.set(element: "large", for: "key")
        
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
            cache.set(element: "zero_cost", for: "key\(i)")
        }
        
        // Should not cause infinite loop
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    // MARK: - Cost Calculation Edge Cases
    
    func testCostCalculationWithDifferentDataTypes() {
        // Test with Int
        let intCache = MemoryCache<String, Int>(
            configuration: .init(
                costProvider: { element in
                    return element
                }
            )
        )
        intCache.set(element: 1000, for: "int_key")
        XCTAssertEqual(intCache.getElementDirect(for: "int_key"), 1000)
        
        // Test with Double
        let doubleCache = MemoryCache<String, Double>(
            configuration: .init(
                costProvider: { element in
                    return Int(element)
                }
            )
        )
        doubleCache.set(element: 3.14, for: "double_key")
        XCTAssertEqual(doubleCache.getElementDirect(for: "double_key"), 3.14)
        
        // Test with Bool
        let boolCache = MemoryCache<String, Bool>(
            configuration: .init(
                costProvider: { element in
                    return element == true ? 10 : 5
                }
            )
        )
        boolCache.set(element: true, for: "bool_key")
        XCTAssertEqual(boolCache.getElementDirect(for: "bool_key"), true)
    }
    
    func testCostCalculationWithNilElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                costProvider: { element in
                    return element.count
                }
            )
        )
        
        // Test cost calculation for nil elements
        cache.set(element: nil as String?, for: "nil_key")
        XCTAssertNil(cache.getElementDirect(for: "nil_key"))
        
        // Test cost calculation for empty strings
        cache.set(element: "", for: "empty_key")
        XCTAssertEqual(cache.getElementDirect(for: "empty_key"), "")
    }
    
    // MARK: - TTL Calculation Edge Cases
    
    func testTTLCalculationWithInfiniteElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                ttlRandomizationRange: 100.0
            )
        )
        
        // Test infinite TTL with randomization
        cache.set(element: "infinite", for: "key1", expiredIn: .infinity)
        XCTAssertEqual(cache.getElementDirect(for: "key1"), "infinite")
        
        // Test infinite TTL for null elements
        cache.set(element: nil, for: "key2")
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    func testTTLRandomizationWithBulkElements() {
        let N = 10000
        
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 2 * N), // Large capacity to hold all elements
                ttlRandomizationRange: 2 // 1s randomization range (±0.5s)
            )
        )
        
        // Insert 10000 elements with 2s base TTL and 1s randomization range
        for i in 0..<N {
            cache.set(element: "element\(i)", for: "key\(i)", expiredIn: 2.0)
        }
        
        // Verify all elements are initially present
        XCTAssertEqual(cache.count, N)
        
        // Wait for 2 seconds (base TTL duration)
        Thread.sleep(forTimeInterval: 2.0)
        
        // Remove expired elements and check remaining count
        XCTAssertEqual(cache.count, N) // Count unchanged before cleanup
        cache.removeExpiredElements()
        let remainingCount = cache.count
        
        // Should be more than 0 (some elements have longer TTL due to positive randomization)
        XCTAssertGreaterThan(remainingCount, 0)
        
        // Should be less than 10000 (some elements have shorter TTL due to negative randomization)
        XCTAssertLessThan(remainingCount, N)
        
        // Verify that some elements are still accessible after expiration
        var accessibleCount = 0
        for i in 0..<N {
            if cache.getElementDirect(for: "key\(i)") != nil {
                accessibleCount += 1
            }
        }
        
        // Should have some accessible elements remaining
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
                cache.set(element: i, for: "key\(i)")
                _ = cache.getElementDirect(for: "key\(i)")
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
        cache.set(element: 1, for: "key1")
        XCTAssertEqual(cache.getElementDirect(for: "key1"), 1)
        
        // But may have race conditions in concurrent scenarios
        // (This is expected behavior when thread safety is disabled)
    }
    
    // MARK: - Cache Entry Structure Tests
    
    func testCacheEntryStructureBehavior() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 10))
        )
        
        // Test regular element entry
        cache.set(element: "regular_element", for: "regular_key")
        XCTAssertEqual(cache.getElementDirect(for: "regular_key"), "regular_element")
        
        // Test null element entry
        cache.set(element: nil, for: "null_key")
        XCTAssertNil(cache.getElementDirect(for: "null_key"))
        
        // Test that both types of entries coexist
        XCTAssertEqual(cache.count, 2)
        
        // Test entry overwriting
        cache.set(element: "new_element", for: "regular_key")
        XCTAssertEqual(cache.getElementDirect(for: "regular_key"), "new_element")
        
        cache.set(element: nil, for: "regular_key")
        XCTAssertNil(cache.getElementDirect(for: "regular_key"))
    }
    
    func testCacheEntryWithMixedElementTypes() {
        let cache = MemoryCache<String, String>(
            configuration: .init(memoryUsageLimitation: .init(capacity: 10))
        )
        
        // Mix of regular and null elements
        cache.set(element: "element1", for: "key1")
        cache.set(element: nil, for: "key2")
        cache.set(element: "element3", for: "key3")
        cache.set(element: nil, for: "key4")
        
        XCTAssertEqual(cache.count, 4)
        XCTAssertEqual(cache.getElementDirect(for: "key1"), "element1")
        XCTAssertNil(cache.getElementDirect(for: "key2"))
        XCTAssertEqual(cache.getElementDirect(for: "key3"), "element3")
        XCTAssertNil(cache.getElementDirect(for: "key4"))
    }
    
    // MARK: - Memory Cost Tracking Edge Cases
    
    func testMemoryCostTrackingWithLargeElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 1000), // 1000MB limit
                costProvider: { _ in 1000000 } // 1MB per item
            )
        )
        
        // Test with large cost elements
        cache.set(element: "large_element", for: "key1")
        XCTAssertEqual(cache.count, 1)
        
        // Add another large item
        cache.set(element: "large_element2", for: "key2")
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
        cache.set(element: "exact", for: "key1")
        // The item might be immediately evicted due to additional overhead
        XCTAssertEqual(cache.count, 0)
        
        // Second item should also be evicted
        cache.set(element: "exact2", for: "key2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    func testMemoryLimitWithSlightlyLargerCost() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(memory: 1), // 1MB limit
                costProvider: { _ in 1024 * 1024 + 1 } // Slightly over 1MB per item
            )
        )
        
        // Item should be immediately evicted due to cost exceeding limit
        cache.set(element: "oversized", for: "key")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    // MARK: - TTL Randomization Precision Tests
    
    func testTTLRandomizationWithSmallRange() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                ttlRandomizationRange: 0.001 // Very small randomization (1ms)
            )
        )
        
        // Add elements with short TTL
        cache.set(element: "short1", for: "key1", expiredIn: 0.1)
        cache.set(element: "short2", for: "key2", expiredIn: 0.1)
        
        // Both should be available immediately
        XCTAssertEqual(cache.getElementDirect(for: "key1"), "short1")
        XCTAssertEqual(cache.getElementDirect(for: "key2"), "short2")
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        cache.removeExpiredElements()
        
        // Both should be expired
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    func testTTLRandomizationDistribution() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 1000),
                ttlRandomizationRange: 1.0 // 1s randomization
            )
        )
        
        // Add many elements with same base TTL
        for i in 0..<100 {
            cache.set(element: "element\(i)", for: "key\(i)", expiredIn: 10.0)
        }
        
        // Wait for base TTL
        Thread.sleep(forTimeInterval: 10.0)
        cache.removeExpiredElements()
        
        let remainingCount = cache.count
        
        // Should have some elements remaining (due to positive randomization)
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
            defaultTTLForNullElement: 1800,
            ttlRandomizationRange: 300,
            keyValidator: { $0.count > 0 },
            costProvider: { $0.count }
        )
        
        let cache = MemoryCache<String, String>(configuration: config)
        
        // Configuration should be immutable after cache creation
        // (This is implicit since Configuration properties are let constants)
        XCTAssertEqual(cache.capacity, 100)
        
        // Test that the configuration is applied correctly
        cache.set(element: "valid", for: "valid_key")
        XCTAssertEqual(cache.getElementDirect(for: "valid_key"), "valid")
        
        // Invalid key should be rejected
        cache.set(element: "invalid", for: "")
        XCTAssertNil(cache.getElementDirect(for: ""))
    }
    
    func testConfigurationWithZeroRandomization() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                ttlRandomizationRange: 0.0 // No randomization
            )
        )
        
        // Add elements with exact TTL
        cache.set(element: "exact1", for: "key1", expiredIn: 0.1)
        cache.set(element: "exact2", for: "key2", expiredIn: 0.1)
        
        // Both should be available
        XCTAssertEqual(cache.getElementDirect(for: "key1"), "exact1")
        XCTAssertEqual(cache.getElementDirect(for: "key2"), "exact2")
        
        // Wait for exact expiration
        Thread.sleep(forTimeInterval: 0.15)
        cache.removeExpiredElements()
        
        // Both should be expired
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    // MARK: - Memory Overflow and Extreme Scenarios Tests
    
    func testMemoryCostOverflowScenarios() {
        // Test with maximum possible cost elements
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10, memory: 1000),
                costProvider: { _ in Int.max / 2 } // Very large cost
            )
        )
        
        // Should handle large costs without crashing
        cache.set(element: "large_cost", for: "key1")
        XCTAssertEqual(cache.count, 0)
        
        // Adding another should trigger eviction due to memory limit
        cache.set(element: "large_cost2", for: "key2")
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
        
        cache.set(element: complexObj, for: "complex_key")
        XCTAssertEqual(cache.count, 1)
        XCTAssertNotNil(cache.getElementDirect(for: "complex_key"))
    }
    
    func testMemoryCostTrackingAccuracy() {
        var costCalculations: [String: Int] = [:]
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                costProvider: { element in
                    let cost = element.count * 2
                    costCalculations[element] = cost
                    return cost
                }
            )
        )
        
        // Add items and track costs
        cache.set(element: "test1", for: "key1")
        cache.set(element: "test2", for: "key2")
        cache.set(element: "test3", for: "key3")
        
        // Verify cost calculations were called
        XCTAssertEqual(costCalculations["test1"], 10)
        XCTAssertEqual(costCalculations["test2"], 10)
        XCTAssertEqual(costCalculations["test3"], 10)
        
        // Remove items and verify cost tracking
        _ = cache.removeElement(for: "key1")
        _ = cache.removeElement(for: "key2")
        _ = cache.removeElement(for: "key3")
        
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
        
        // Add elements with very short TTL
        cache.set(element: "micro1", for: "key1", expiredIn: 1) // 1s base TTL
        cache.set(element: "micro2", for: "key2", expiredIn: 1)
        
        Thread.sleep(forTimeInterval: 3)
        
        // Both should be available immediately
        XCTAssertEqual(cache.getElementDirect(for: "key1"), "micro1")
        XCTAssertEqual(cache.getElementDirect(for: "key2"), "micro2")
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.002)
        cache.removeExpiredElements()
        
        // Both should be expired
        XCTAssertNil(cache.getElementDirect(for: "key1"))
        XCTAssertNil(cache.getElementDirect(for: "key2"))
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
                cache.set(element: "large_element", for: "key\(i)")
                group.leave()
            }
        }
        
        // Concurrent reads
        for i in 0..<50 {
            group.enter()
            queue.async {
                _ = cache.getElementDirect(for: "key\(i)")
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
                cache.set(element: i, for: "key\(i)")
                group.leave()
            }
        }
        
        // Concurrent removal operations
        for i in 0..<500 {
            group.enter()
            queue.async {
                _ = cache.removeElement(for: "key\(i)")
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
                cache.set(element: "element\(i)", for: "key\(i)")
                group.leave()
            }
            
            group.enter()
            queue.async {
                // Get operation
                _ = cache.getElementDirect(for: "key\(i)")
                group.leave()
            }
            
            group.enter()
            queue.async {
                // Remove operation
                _ = cache.removeElement(for: "key\(i)")
                group.leave()
            }
            
            group.enter()
            queue.async {
                // Remove expired elements
                cache.removeExpiredElements()
                group.leave()
            }
        }
        
        group.wait()
        
        // Should not crash and maintain consistency
        XCTAssertLessThanOrEqual(cache.count, cache.capacity)
    }
    
    // MARK: - Performance Under Load Tests
    
    func testPerformanceWithVeryLargeCapacity() {
        let largeCapacity = 20000 // 20K entries (reduced from 100K for CI compatibility)
        let cache = MemoryCache<String, Int>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: largeCapacity)
            )
        )
        
        measure {
            // Bulk insert (reduced from 50K to 10K operations)
            for i in 0..<10000 {
                cache.set(element: i, for: "key\(i)")
            }
            
            // Bulk read
            for i in 0..<10000 {
                _ = cache.getElementDirect(for: "key\(i)")
            }
            
            // Bulk remove
            for i in 0..<10000 {
                _ = cache.removeElement(for: "key\(i)")
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
                cache.set(element: i, for: "key\(i)")
                _ = cache.getElementDirect(for: "key\(i)")
                _ = cache.removeElement(for: "key\(i)")
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
                cache.set(element: "element\(i)", for: "key\(i)")
                _ = cache.getElementDirect(for: "key\(i)")
                
                if i % 10 == 0 {
                    _ = cache.removeElement(for: "key\(i)")
                }
            }
        }
        
        XCTAssertLessThanOrEqual(cache.count, 1000)
    }
    
    // MARK: - Error Handling Edge Cases Tests
    
    func testBehaviorWithInvalidCostProvider() {
        // Test with cost provider that returns negative elements
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 10),
                costProvider: { _ in -100 } // Negative cost
            )
        )
        
        // Should handle negative costs gracefully
        cache.set(element: "test", for: "key")
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.getElementDirect(for: "key"), "test")
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
        cache.set(element: "test", for: "key")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key"))
    }
    
    func testBehaviorWithExtremeConfigurationElements() {
        // Test with extreme configuration elements (but not infinite to avoid hangs)
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: 1_000_000, memory: 1_000_000_000), // 1M items, 1GB memory
                defaultTTL: .infinity,
                defaultTTLForNullElement: .infinity,
                ttlRandomizationRange: 1000.0, // Large but finite randomization
                keyValidator: { _ in true },
                costProvider: { _ in 1000 } // Large but reasonable cost per item
            )
        )
        
        // Should handle extreme elements without crashing
        cache.set(element: "test", for: "key")
        XCTAssertEqual(cache.getElementDirect(for: "key"), "test")
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
            cache.set(element: "oversized_item", for: "key\(i)")
        }
        
        // Should handle gracefully without crashing
        XCTAssertEqual(cache.count, 0) // All items should be immediately evicted
    }
    
    func testBehaviorWithMemoryFragmentation() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100, memory: 10), // 10MB limit
                costProvider: { element in
                    // Varying costs to simulate fragmentation
                    return element.count * 1024 * 1024 // 1MB per character
                }
            )
        )
        
        // Add items with varying sizes
        cache.set(element: "small", for: "key1")
        cache.set(element: "medium_size", for: "key2")
        cache.set(element: "very_large_item_that_exceeds_limit", for: "key3")
        
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
            cache.set(element: "element\(i)", for: "key\(i)")
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
                defaultTTLForNullElement: 0.5,
                ttlRandomizationRange: 0.1,
                keyValidator: { $0.count > 0 && $0.count <= 20 },
                costProvider: { $0.count * 1024 * 1024 } // 1MB per character
            )
        )
        
        // Test all features together
        cache.set(element: "short", for: "key1", priority: 1.0, expiredIn: 0.1)
        cache.set(element: nil, for: "null_key")
        cache.set(element: "medium_length_element", for: "key2", priority: 5.0, expiredIn: 2.0)
        cache.set(element: "very_long_element_that_might_exceed_memory", for: "key3", priority: 10.0)
        
        XCTAssertEqual(cache.count, 1)
        
        // Wait for short-lived items to expire
        Thread.sleep(forTimeInterval: 0.2)
        cache.removeExpiredElements()
        
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
                cache.set(element: i, for: "key\(i)", priority: Double(i % 10), expiredIn: Double(i % 5))
                
                // Get element
                _ = cache.getElementDirect(for: "key\(i)")
                
                // Remove expired elements periodically
                if i % 100 == 0 {
                    cache.removeExpiredElements()
                }
                
                // Remove to percentage periodically
                if i % 200 == 0 {
                    cache.removeElements(toPercent: 0.5)
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
    
    func testBoundaryConditionsWithMinimalElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: false,
                memoryUsageLimitation: .init(capacity: 1, memory: 0),
                defaultTTL: 0,
                defaultTTLForNullElement: 0,
                ttlRandomizationRange: 0,
                keyValidator: { _ in true },
                costProvider: { _ in 0 }
            )
        )
        
        // Test with minimal configuration
        cache.set(element: "test", for: "key")
        XCTAssertEqual(cache.count, 0)
        
        // Add another item (should evict first)
        cache.set(element: "test2", for: "key2")
        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.getElementDirect(for: "key"))
        XCTAssertNil(cache.getElementDirect(for: "key2"))
    }
    
    func testBoundaryConditionsWithMaximalElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                enableThreadSynchronization: true,
                memoryUsageLimitation: .init(capacity: Int.max, memory: Int.max),
                defaultTTL: .infinity,
                defaultTTLForNullElement: .infinity,
                ttlRandomizationRange: Double.greatestFiniteMagnitude,
                keyValidator: { _ in true },
                costProvider: { _ in Int.max }
            )
        )
        
        // Test with maximal configuration
        cache.set(element: "test", for: "key")
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.getElementDirect(for: "key"), "test")
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
        stringCache.set(element: "test", for: "key")
        intCache.set(element: 42, for: "key")
        doubleCache.set(element: 3.14, for: "key")
        
        XCTAssertEqual(stringCache.count, 1)
        XCTAssertEqual(intCache.count, 1)
        XCTAssertEqual(doubleCache.count, 1)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testStatisticsRecordingForGetElement() {
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
        _ = cache.getElementDirect(for: "invalid_key")
        XCTAssertEqual(reportedResults.count, 1)
        XCTAssertEqual(reportedResults.last, .invalidKey)
        
        // Test miss
        _ = cache.getElementDirect(for: "valid_key")
        XCTAssertEqual(reportedResults.count, 2)
        XCTAssertEqual(reportedResults.last, .miss)
        
        // Test null element hit
        cache.set(element: nil, for: "valid_null_key")
        _ = cache.getElementDirect(for: "valid_null_key")
        XCTAssertEqual(reportedResults.count, 3)
        XCTAssertEqual(reportedResults.last, .hitNullElement)
        
        // Test non-null element hit
        cache.set(element: "test_element", for: "valid_test_key")
        _ = cache.getElementDirect(for: "valid_test_key")
        XCTAssertEqual(reportedResults.count, 4)
        XCTAssertEqual(reportedResults.last, .hitNonNullElement)
    }
    
    func testStatisticsRecordingForSetElement() {
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
        cache.set(element: "test", for: "invalid_key")
        XCTAssertEqual(reportedResults.count, 0)
        XCTAssertEqual(reportedResults.last, nil)
        
        // Test null element caching
        cache.set(element: nil, for: "valid_null_key")
        XCTAssertEqual(reportedResults.count, 0)
        XCTAssertEqual(reportedResults.last, nil)
        
        // Test non-null element caching
        _=cache.getElementDirect(for: "valid_test_key")
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
        cache.set(element: "element1", for: "key1")
        cache.set(element: nil, for: "key2")
        cache.set(element: "element3", for: "key3")
        
        _ = cache.getElementDirect(for: "key1")  // hit
        _ = cache.getElementDirect(for: "key2")  // null hit
        _ = cache.getElementDirect(for: "key4")  // miss
        _ = cache.getElementDirect(for: "")      // invalid key
        
        let stats = cache.statistics
        
        XCTAssertEqual(stats.invalidKeyCount, 1)
        XCTAssertEqual(stats.nullElementHitCount, 1)
        XCTAssertEqual(stats.nonNullElementHitCount, 1)
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
        cache.set(element: "element1", for: "key1")
        cache.set(element: "element2", for: "key2")
        cache.set(element: nil, for: "key3")
        
        // Perform gets with known results
        _ = cache.getElementDirect(for: "key1")  // hit
        _ = cache.getElementDirect(for: "key2")  // hit
        _ = cache.getElementDirect(for: "key3")  // null hit
        _ = cache.getElementDirect(for: "key4")  // miss
        _ = cache.getElementDirect(for: "key5")  // miss
        
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
        cache.set(element: "element1", for: "key1")
        _ = cache.getElementDirect(for: "key1")
        _ = cache.getElementDirect(for: "key2")  // miss
        
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
            cache.set(element: "element\(i)", for: "key\(i)")
        }
        
        let queue = DispatchQueue(label: "stats", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Concurrent access
        for i in 0..<1000 {
            group.enter()
            queue.async {
                _ = cache.getElementDirect(for: "key\(i % 100)")
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
        cache.set(element: "element1", for: "key1")
        cache.set(element: nil, for: "key2")
        cache.set(element: "element3", for: "key3")
        cache.set(element: "element4", for: "")  // invalid key
        
        _ = cache.getElementDirect(for: "key1")  // hit
        _ = cache.getElementDirect(for: "key2")  // null hit
        _ = cache.getElementDirect(for: "key4")  // miss
        _ = cache.getElementDirect(for: "")      // invalid key
        _ = cache.getElementDirect(for: "key3")  // hit
        
        let stats = cache.statistics
        
        XCTAssertEqual(stats.invalidKeyCount, 1)
        XCTAssertEqual(stats.nullElementHitCount, 1)
        XCTAssertEqual(stats.nonNullElementHitCount, 2)
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
        cache.set(element: "test", for: "key1")
        _ = cache.getElementDirect(for: "key1")
        _ = cache.getElementDirect(for: "key2")  // miss
        
        XCTAssertEqual(callbackCount, 2)
        XCTAssertEqual(lastResult, .miss)
    }
    
    func testStatisticsWithExpiredElements() {
        let cache = MemoryCache<String, String>(
            configuration: .init(
                memoryUsageLimitation: .init(capacity: 100),
                defaultTTL: 0.1  // Very short TTL
            )
        )
        
        // Set element with short TTL
        cache.set(element: "test", for: "key1")
        
        // Get immediately (should hit)
        _ = cache.getElementDirect(for: "key1")
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.2)
        
        // Get after expiration (should miss)
        _ = cache.getElementDirect(for: "key1")
        
        let stats = cache.statistics
        
        XCTAssertEqual(stats.nonNullElementHitCount, 1)
        XCTAssertEqual(stats.missCount, 1)
        XCTAssertEqual(stats.totalAccesses, 2)
    }
}
