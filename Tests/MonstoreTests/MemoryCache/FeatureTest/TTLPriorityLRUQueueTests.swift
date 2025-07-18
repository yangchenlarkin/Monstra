//
//  TTLPriorityLRUQueueTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/6/27.
//
//  Test suite for TTLPriorityLRUQueue: covers initialization, basic operations, TTL expiration,
//  priority-based eviction, LRU policy, combined scenarios, and edge/stress cases.
//  Ensures correctness of all algorithmic behaviors and edge cases for the cache.

import XCTest

@testable import Monstore

/// Tests for TTLPriorityLRUQueue, a cache combining TTL, priority, and LRU eviction policies.
/// Each test group covers a distinct aspect of the cache's behavior.
final class TTLPriorityLRUQueueTests: XCTestCase {}

// MARK: - Initialization Tests
/// Tests for correct initialization and capacity handling.
extension TTLPriorityLRUQueueTests {
    func testInitialization() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)
        XCTAssertEqual(cache.capacity, 5)
        let unlimitedCache = TTLPriorityLRUQueue<String, Int>(capacity: -1)
        XCTAssertEqual(unlimitedCache.capacity, 0)
    }
}

// MARK: - Basic Operations
/// Tests for insert, retrieve, remove, duplicate keys, and zero capacity.
extension TTLPriorityLRUQueueTests {
    func testInsertAndRetrieve() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 10, for: "key1", expiredIn: 10)
        _ = cache.set(value: 20, for: "key2", expiredIn: 20)
        XCTAssertEqual(cache.getValue(for: "key1"), 10)
        XCTAssertEqual(cache.getValue(for: "key2"), 20)
        XCTAssertNil(cache.getValue(for: "key3"))
    }
    func testOverwriteExistingKey() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 10, for: "key1", expiredIn: 10)
        _ = cache.set(value: 20, for: "key1", expiredIn: 20)
        XCTAssertEqual(cache.getValue(for: "key1"), 20)
    }
    func testRemoveValue() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 40, for: "key1", expiredIn: 10)
        _ = cache.set(value: 50, for: "key2", expiredIn: 20)
        XCTAssertEqual(cache.removeValue(for: "key1"), 40)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertNil(cache.removeValue(for: "key3"))
    }
    func testInsertDuplicates() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)
        _ = cache.set(value: 10, for: "key1", expiredIn: 10)
        _ = cache.set(value: 20, for: "key1", expiredIn: 20)
        XCTAssertEqual(cache.getValue(for: "key1"), 20)
    }
    func testCapacityZero() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 0)
        _ = cache.set(value: 10, for: "key1", expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "key1"))
    }
}

// MARK: - TTL Expiration
/// Tests for TTL expiration and retrieval of expired keys.
extension TTLPriorityLRUQueueTests {
    func testExpiration() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)
        _ = cache.set(value: 30, for: "key1", expiredIn: 1)
        sleep(2)
        XCTAssertNil(cache.getValue(for: "key1"))
    }
    func testMultipleExpiration() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)
        _ = cache.set(value: 10, for: "key1", expiredIn: 1)
        _ = cache.set(value: 20, for: "key2", expiredIn: 10)
        sleep(2)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertEqual(cache.getValue(for: "key2"), 20)
    }
    func testZeroOrNegativeTTLKey() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 10, for: "Key1", expiredIn: 0)
        _ = cache.set(value: 20, for: "Key2", expiredIn: -1)
        XCTAssertNil(cache.getValue(for: "Key1"))
        XCTAssertNil(cache.getValue(for: "Key2"))
    }
    func testRetrievingExpiredKeys() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 10, for: "key1", expiredIn: 1)
        _ = cache.set(value: 20, for: "key2", expiredIn: 10)
        sleep(2)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertEqual(cache.getValue(for: "key2"), 20)
    }
    func testRemoveExpiredKey() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 10, for: "Key1", expiredIn: 1)
        sleep(2)
        let removedValue = cache.removeValue(for: "Key1")
        XCTAssertEqual(removedValue, 10)
        XCTAssertNil(cache.getValue(for: "Key1"))
    }
    func testReSetAfterExpiration() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 10, for: "Key1", expiredIn: 1)
        sleep(2)
        _ = cache.set(value: 20, for: "Key1", expiredIn: 5)
        XCTAssertEqual(cache.getValue(for: "Key1"), 20)
    }
    func testMultipleKeysExpireSimultaneously() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        _ = cache.set(value: 10, for: "Key1", expiredIn: 2)
        _ = cache.set(value: 20, for: "Key2", expiredIn: 2)
        _ = cache.set(value: 30, for: "Key3", expiredIn: 5)
        sleep(3)
        XCTAssertNil(cache.getValue(for: "Key1"))
        XCTAssertNil(cache.getValue(for: "Key2"))
        XCTAssertEqual(cache.getValue(for: "Key3"), 30)
    }
    func testInfiniteTTL() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 1)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: .infinity)
        sleep(1)
        XCTAssertEqual(cache.getValue(for: "A"), 1)
    }
    func testShortTTLExpiresImmediately() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 1)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 0.001)
        usleep(2000)
        XCTAssertNil(cache.getValue(for: "A"))
    }
}

// MARK: - Priority
/// Tests for priority-based eviction and retrieval.
extension TTLPriorityLRUQueueTests {
    func testEvictionPrefersPriorityOverTTL() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 100)
        _ = cache.set(value: 2, for: "B", priority: 2, expiredIn: 100)
        _ = cache.set(value: 3, for: "C", priority: 3, expiredIn: 100)
        XCTAssertNil(cache.getValue(for: "A"))
        XCTAssertEqual(cache.getValue(for: "B"), 2)
        XCTAssertEqual(cache.getValue(for: "C"), 3)
    }
    func testMaxMinPriority() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "min", priority: -Double.greatestFiniteMagnitude, expiredIn: 100)
        _ = cache.set(value: 2, for: "max", priority: Double.greatestFiniteMagnitude, expiredIn: 100)
        _ = cache.set(value: 3, for: "mid", priority: 0, expiredIn: 100)
        XCTAssertNil(cache.getValue(for: "min"))
        XCTAssertEqual(cache.getValue(for: "max"), 2)
        XCTAssertEqual(cache.getValue(for: "mid"), 3)
    }
    func testInsertSameKeyLowerPriority() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 10, expiredIn: 10)
        _ = cache.set(value: 2, for: "A", priority: 1, expiredIn: 10)
        _ = cache.set(value: 3, for: "B", priority: 10, expiredIn: 10)
        _ = cache.set(value: 4, for: "C", priority: 20, expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "A"))
        XCTAssertEqual(cache.getValue(for: "B"), 3)
        XCTAssertEqual(cache.getValue(for: "C"), 4)
    }
    func testDuplicateKeysDifferentPriorities() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 10)
        _ = cache.set(value: 2, for: "A", priority: 10, expiredIn: 10)
        _ = cache.set(value: 3, for: "B", priority: 1, expiredIn: 10)
        _ = cache.set(value: 4, for: "C", priority: 20, expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "B"))
        XCTAssertEqual(cache.getValue(for: "A"), 2)
        XCTAssertEqual(cache.getValue(for: "C"), 4)
    }
}

// MARK: - LRU
/// Tests for LRU eviction and access updates.
extension TTLPriorityLRUQueueTests {
    func testLRUEviction() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 60, for: "key1", expiredIn: 10)
        _ = cache.set(value: 70, for: "key2", expiredIn: 10)
        _ = cache.set(value: 80, for: "key3", expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertEqual(cache.getValue(for: "key2"), 70)
        XCTAssertEqual(cache.getValue(for: "key3"), 80)
    }
    func testLRUAccessUpdatesPosition() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 90, for: "key1", expiredIn: 10)
        _ = cache.set(value: 100, for: "key2", expiredIn: 10)
        _ = cache.getValue(for: "key1")
        _ = cache.set(value: 110, for: "key3", expiredIn: 10)
        XCTAssertEqual(cache.getValue(for: "key1"), 90)
        XCTAssertNil(cache.getValue(for: "key2"))
        XCTAssertEqual(cache.getValue(for: "key3"), 110)
    }
    func testEvictionLRUWhenPrioritiesEqual() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 100)
        _ = cache.set(value: 2, for: "B", priority: 1, expiredIn: 100)
        _ = cache.getValue(for: "A")
        _ = cache.set(value: 3, for: "C", priority: 1, expiredIn: 100)
        XCTAssertNil(cache.getValue(for: "B"))
        XCTAssertEqual(cache.getValue(for: "A"), 1)
        XCTAssertEqual(cache.getValue(for: "C"), 3)
    }
    func testEvictAllEqualLRU() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 10)
        _ = cache.set(value: 2, for: "B", priority: 1, expiredIn: 10)
        _ = cache.getValue(for: "A")
        _ = cache.set(value: 3, for: "C", priority: 1, expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "B"))
        XCTAssertEqual(cache.getValue(for: "A"), 1)
        XCTAssertEqual(cache.getValue(for: "C"), 3)
    }
}

// MARK: - Combined TTL + Priority
/// Tests for combined TTL and priority scenarios.
extension TTLPriorityLRUQueueTests {
    func testTTLExpirationWithPriority() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 1)
        _ = cache.set(value: 2, for: "B", priority: 2, expiredIn: 10)
        sleep(2)
        XCTAssertNil(cache.getValue(for: "A"))
        XCTAssertEqual(cache.getValue(for: "B"), 2)
    }
    func testUpdatePriorityAndTTL() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 1)
        _ = cache.set(value: 10, for: "A", priority: 5, expiredIn: 5)
        sleep(2)
        XCTAssertEqual(cache.getValue(for: "A"), 10)
        _ = cache.set(value: 2, for: "B", priority: 1, expiredIn: 100)
        _ = cache.set(value: 3, for: "C", priority: 10, expiredIn: 100)
        XCTAssertNil(cache.getValue(for: "B"))
        XCTAssertEqual(cache.getValue(for: "A"), 10)
        XCTAssertEqual(cache.getValue(for: "C"), 3)
    }
    func testSimultaneousExpirationAndInsertion() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 1)
        _ = cache.set(value: 2, for: "B", priority: 2, expiredIn: 1)
        sleep(2)
        _ = cache.set(value: 3, for: "C", priority: 3, expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "A"))
        XCTAssertNil(cache.getValue(for: "B"))
        XCTAssertEqual(cache.getValue(for: "C"), 3)
    }
    func testInsertSameKeyShorterTTL() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 1)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 10)
        _ = cache.set(value: 2, for: "A", priority: 1, expiredIn: 1)
        sleep(2)
        XCTAssertNil(cache.getValue(for: "A"))
    }
    func testInsertSameKeyLongerTTL() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 1)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 1)
        _ = cache.set(value: 2, for: "A", priority: 1, expiredIn: 10)
        sleep(2)
        XCTAssertEqual(cache.getValue(for: "A"), 2)
    }
}

// MARK: - Edge and Stress Cases
/// Tests for edge cases and stress scenarios.
extension TTLPriorityLRUQueueTests {
    func testStressInsertAccess() {
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 100)
        for i in 0..<1000 {
            _ = cache.set(value: i, for: i, priority: Double(i % 10), expiredIn: 10)
        }
        var found = 0
        for i in 0..<1000 {
            if let _ = cache.getValue(for: i) { found += 1 }
        }
        XCTAssertEqual(found, 100)
        XCTAssertEqual(cache.capacity, 100)
        XCTAssertEqual(cache.isFull, true)
        XCTAssertEqual(cache.isEmpty, false)
    }
    func testInternalStateAfterManyOps() {
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 10)
        for i in 0..<10 { _ = cache.set(value: i, for: i, priority: Double(i), expiredIn: 10) }
        XCTAssertEqual(cache.isFull, true)
        XCTAssertEqual(cache.isEmpty, false)
        for i in 0..<10 { _ = cache.removeValue(for: i) }
        XCTAssertEqual(cache.isEmpty, true)
    }
    func testEvictWhenAllItemsExpired() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 1)
        _ = cache.set(value: 2, for: "B", priority: 2, expiredIn: 1)
        sleep(2)
        _ = cache.set(value: 3, for: "C", priority: 3, expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "A"))
        XCTAssertNil(cache.getValue(for: "B"))
        XCTAssertEqual(cache.getValue(for: "C"), 3)
    }
    func testEvictExpiredBeforeNonExpired() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)
        _ = cache.set(value: 1, for: "A", priority: 1, expiredIn: 1)
        _ = cache.set(value: 2, for: "B", priority: 2, expiredIn: 10)
        sleep(2)
        _ = cache.set(value: 3, for: "C", priority: 3, expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "A"))
        XCTAssertEqual(cache.getValue(for: "B"), 2)
        XCTAssertEqual(cache.getValue(for: "C"), 3)
    }
    func testRemoveNonExistentKey() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 1)
        XCTAssertNil(cache.removeValue(for: "nope"))
    }
    
    // MARK: - Remove Expired Values Tests
    
    func testRemoveExpiredValues() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)
        
        // Add values with different expiration times
        cache.set(value: 10, for: "key1", expiredIn: 0.1) // Expires quickly
        cache.set(value: 20, for: "key2", expiredIn: 0.1) // Expires quickly
        cache.set(value: 30, for: "key3", expiredIn: 10.0) // Long TTL
        cache.set(value: 40, for: "key4", expiredIn: 10.0) // Long TTL
        
        XCTAssertEqual(cache.count, 4)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        // Remove expired values
        cache.removeExpiredValues()
        
        // Should only have long TTL values remaining
        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertNil(cache.getValue(for: "key2"))
        XCTAssertEqual(cache.getValue(for: "key3"), 30)
        XCTAssertEqual(cache.getValue(for: "key4"), 40)
    }
    
    func testRemoveExpiredValuesWithNoExpired() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        
        // Add values with long TTL
        cache.set(value: 10, for: "key1", expiredIn: 10.0)
        cache.set(value: 20, for: "key2", expiredIn: 10.0)
        cache.set(value: 30, for: "key3", expiredIn: 10.0)
        
        XCTAssertEqual(cache.count, 3)
        
        // Remove expired values (none should be expired)
        cache.removeExpiredValues()
        
        // All values should remain
        XCTAssertEqual(cache.count, 3)
        XCTAssertEqual(cache.getValue(for: "key1"), 10)
        XCTAssertEqual(cache.getValue(for: "key2"), 20)
        XCTAssertEqual(cache.getValue(for: "key3"), 30)
    }
    
    func testRemoveExpiredValuesWithAllExpired() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        
        // Add values with short TTL
        cache.set(value: 10, for: "key1", expiredIn: 0.1)
        cache.set(value: 20, for: "key2", expiredIn: 0.1)
        cache.set(value: 30, for: "key3", expiredIn: 0.1)
        
        XCTAssertEqual(cache.count, 3)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        // Remove expired values
        cache.removeExpiredValues()
        
        // All values should be removed
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertNil(cache.getValue(for: "key2"))
        XCTAssertNil(cache.getValue(for: "key3"))
    }
    
    func testRemoveExpiredValuesWithMixedExpiration() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)
        
        // Add values with mixed expiration times
        cache.set(value: 10, for: "key1", expiredIn: 0.1) // Expires quickly
        cache.set(value: 20, for: "key2", expiredIn: 10.0) // Long TTL
        cache.set(value: 30, for: "key3", expiredIn: 0.1) // Expires quickly
        cache.set(value: 40, for: "key4", expiredIn: 10.0) // Long TTL
        cache.set(value: 50, for: "key5", expiredIn: 0.1) // Expires quickly
        
        XCTAssertEqual(cache.count, 5)
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.15)
        
        // Remove expired values
        cache.removeExpiredValues()
        
        // Should only have long TTL values remaining
        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.getValue(for: "key1"))
        XCTAssertEqual(cache.getValue(for: "key2"), 20)
        XCTAssertNil(cache.getValue(for: "key3"))
        XCTAssertEqual(cache.getValue(for: "key4"), 40)
        XCTAssertNil(cache.getValue(for: "key5"))
    }
}
