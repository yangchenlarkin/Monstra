//
//  TTLPriorityLRUQueueTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/6/27.
//

import XCTest

@testable import Monstore

/// Unit tests for TTLPriorityLRUQueue covering initialization, insertion, retrieval, TTL expiration, deletion, LRU behavior, and edge cases.
final class TTLPriorityLRUQueueTests: XCTestCase {
    // MARK: - Initialization Tests
    /// Test cache initialization with different capacities.
    func testInitialization() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)
        XCTAssertEqual(cache.capacity, 5, "Capacity should be set correctly.")

        let unlimitedCache = TTLPriorityLRUQueue<String, Int>(capacity: -1)
        XCTAssertEqual(unlimitedCache.capacity, 0, "Negative capacity should default to 0.")
    }

    // MARK: - Insertion and Retrieval Tests
    /// Test inserting values and retrieving them.
    func testInsertAndRetrieve() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        _ = cache.unsafeSet(value: 10, for: "key1", expiredIn: 10)
        _ = cache.unsafeSet(value: 20, for: "key2", expiredIn: 20)

        XCTAssertEqual(cache.getValue(for: "key1"), 10, "Value for 'key1' should match the inserted value.")
        XCTAssertEqual(cache.getValue(for: "key2"), 20, "Value for 'key2' should match the inserted value.")
        XCTAssertNil(cache.getValue(for: "key3"), "Retrieving a non-existent key should return nil.")
    }

    /// Test overwriting an existing key value works correctly.
    func testOverwriteExistingKey() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        _ = cache.unsafeSet(value: 10, for: "key1", expiredIn: 10)
        _ = cache.unsafeSet(value: 20, for: "key1", expiredIn: 20) // Overwrite

        XCTAssertEqual(cache.getValue(for: "key1"), 20, "Overwritten value for 'key1' should match the updated value.")
    }

    // MARK: - TTL Expiration Tests
    /// Test that values expire after their TTL.
    func testExpiration() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)

        _ = cache.unsafeSet(value: 30, for: "key1", expiredIn: 1) // TTL: 1 second
        sleep(2) // Wait for the value to expire

        XCTAssertNil(cache.getValue(for: "key1"), "Expired values should return nil.")
    }

    /// Test that multiple expired entries do not affect valid entries.
    func testMultipleExpiration() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)

        _ = cache.unsafeSet(value: 10, for: "key1", expiredIn: 1) // TTL: 1 second
        _ = cache.unsafeSet(value: 20, for: "key2", expiredIn: 10)

        sleep(2) // Wait for key1 to expire

        XCTAssertNil(cache.getValue(for: "key1"), "Key1 should expire after its TTL.")
        XCTAssertEqual(cache.getValue(for: "key2"), 20, "Key2 should still return its value.")
    }
    
    /// Test setting a key with zero or negative TTL behaves correctly.
    func testZeroOrNegativeTTLKey() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Step 1: Insert keys with zero and negative TTLs
        _ = cache.unsafeSet(value: 10, for: "Key1", expiredIn: 0)
        _ = cache.unsafeSet(value: 20, for: "Key2", expiredIn: -1)

        // Validate behavior
        XCTAssertNil(cache.getValue(for: "Key1"), "Key1 with zero TTL should be treated as expired.")
        XCTAssertNil(cache.getValue(for: "Key2"), "Key2 with negative TTL should be treated as expired.")
    }

    // MARK: - Deletion Tests

    /// Test removing values from the cache.
    func testRemoveValue() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        _ = cache.unsafeSet(value: 40, for: "key1", expiredIn: 10)
        _ = cache.unsafeSet(value: 50, for: "key2", expiredIn: 20)

        XCTAssertEqual(cache.unsafeRemoveValue(for: "key1"), 40, "Removed value should match the inserted value.")
        XCTAssertNil(cache.getValue(for: "key1"), "After removal, 'key1' should no longer exist.")

        XCTAssertNil(cache.unsafeRemoveValue(for: "key3"), "Removing a non-existent key should return nil.")
    }

    // MARK: - LRU Eviction Tests

    /// Test cache behavior when exceeding capacity (triggering LRU).
    func testLRUEviction() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)

        _ = cache.unsafeSet(value: 60, for: "key1", expiredIn: 10)
        _ = cache.unsafeSet(value: 70, for: "key2", expiredIn: 10)
        _ = cache.unsafeSet(value: 80, for: "key3", expiredIn: 10) // Insert third element, evicting least recently used key.

        XCTAssertNil(cache.getValue(for: "key1"), "Key1 should be evicted due to LRU policy.")
        XCTAssertEqual(cache.getValue(for: "key2"), 70, "Key2 should still exist.")
        XCTAssertEqual(cache.getValue(for: "key3"), 80, "Key3 should still exist.")
    }

    /// Test that accessing a key updates its position in the LRU queue.
    func testLRUAccessUpdatesPosition() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 2)

        _ = cache.unsafeSet(value: 90, for: "key1", expiredIn: 10)
        _ = cache.unsafeSet(value: 100, for: "key2", expiredIn: 10)

        _ = cache.getValue(for: "key1") // Access key1 to mark it as recently used
        _ = cache.unsafeSet(value: 110, for: "key3", expiredIn: 10) // Insert key3, evicting key2

        XCTAssertEqual(cache.getValue(for: "key1"), 90, "Key1 should still exist as it was recently accessed.")
        XCTAssertNil(cache.getValue(for: "key2"), "Key2 should be evicted due to LRU policy.")
        XCTAssertEqual(cache.getValue(for: "key3"), 110, "Key3 should still exist.")
    }
    
    /// Test LRU eviction when the least recently used tail node is expired.
    func testLRUEvictionTailNodeExpired() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        // Step 1: Add three elements with different expiration times
        _ = cache.unsafeSet(value: 100, for: "key1", expiredIn: 5) // Head node (most recently used)
        _ = cache.unsafeSet(value: 200, for: "key2", expiredIn: 5) // Middle node
        _ = cache.unsafeSet(value: 300, for: "key3", expiredIn: 1) // Tail node (least recently used)
        // Simulate expiration for the tail node
        sleep(2) // Allow "key3" to expire
        // Insert a new element when the tail node (key3) has expired
        _ = cache.unsafeSet(value: 400, for: "key4", expiredIn: 10)
        // Validate the state
        XCTAssertNil(cache.getValue(for: "key3"), "Key3 should have expired and been removed.")
        XCTAssertEqual(cache.getValue(for: "key4"), 400, "Key4 should still exist.")
        XCTAssertEqual(cache.getValue(for: "key1"), 100, "Key1 should not be evicted.")
        XCTAssertEqual(cache.getValue(for: "key2"), 200, "Key2 should not be evicted.")
    }
    
    /// Test LRU eviction when a middle node is expired.
    func testLRUEvictionMiddleNodeExpired() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        // Step 1: Add three elements with different expiration times
        _ = cache.unsafeSet(value: 100, for: "key1", expiredIn: 5) // Head node (most recently used)
        _ = cache.unsafeSet(value: 200, for: "key2", expiredIn: 1) // Middle node
        _ = cache.unsafeSet(value: 300, for: "key3", expiredIn: 5) // Tail node (least recently used)
        // Simulate expiration for the middle node
        sleep(2) // Allow "key2" to expire
        // Insert a new element after the middle node (key2) expires
        _ = cache.unsafeSet(value: 400, for: "key4", expiredIn: 10)
        // Validate the state
        XCTAssertNil(cache.getValue(for: "key2"), "Key2 should have expired and been removed.")
        XCTAssertEqual(cache.getValue(for: "key4"), 400, "Key4 should still exist.")
        XCTAssertEqual(cache.getValue(for: "key1"), 100, "Key1 should not be evicted.")
        XCTAssertEqual(cache.getValue(for: "key3"), 300, "Key3 should not be evicted.")
    }
    
    /// Test LRU eviction when the head node is expired.
    func testLRUEvictionHeadNodeExpired() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)
        // Step 1: Add three elements with different expiration times
        _ = cache.unsafeSet(value: 100, for: "key1", expiredIn: 1) // Head node (most recently used)
        _ = cache.unsafeSet(value: 200, for: "key2", expiredIn: 5) // Middle node
        _ = cache.unsafeSet(value: 300, for: "key3", expiredIn: 5) // Tail node (least recently used)
        // Simulate expiration for the head node
        sleep(2) // Allow "key1" to expire
        // Insert a new element after the head node (key1) expires
        _ = cache.unsafeSet(value: 400, for: "key4", expiredIn: 10)
        // Validate the state
        XCTAssertNil(cache.getValue(for: "key1"), "Key1 should have expired and been removed.")
        XCTAssertEqual(cache.getValue(for: "key4"), 400, "Key4 should still exist.")
        XCTAssertEqual(cache.getValue(for: "key2"), 200, "Key2 should not be evicted.")
        XCTAssertEqual(cache.getValue(for: "key3"), 300, "Key3 should not be evicted.")
    }
    
    // MARK: - Comprehensive Tests
    /// Test a combination of cache behaviors including LRU eviction, updates, and TTL expiration.
    func testComprehensiveScenario1() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Step 1: Insert three elements
        _ = cache.unsafeSet(value: 1, for: "Key1", expiredIn: 10) // Insert Key1
        _ = cache.unsafeSet(value: 2, for: "Key2", expiredIn: 10) // Insert Key2
        _ = cache.unsafeSet(value: 3, for: "Key3", expiredIn: 10) // Insert Key3

        // Step 2: Update an existing key (Key2)
        _ = cache.unsafeSet(value: 4, for: "Key2", expiredIn: 10) // Update Key2

        // Step 3: Insert a new key (Key4) to trigger LRU eviction
        _ = cache.unsafeSet(value: 4, for: "Key4", expiredIn: 10) // Insert Key4, evicts Key1

        // Validations
        XCTAssertNil(cache.getValue(for: "Key1"), "Key1 should have been evicted due to LRU policy.")
        XCTAssertEqual(cache.getValue(for: "Key2"), 4, "Key2 should have the updated value (4).")
        XCTAssertEqual(cache.getValue(for: "Key3"), 3, "Key3 should still exist in the cache.")
        XCTAssertEqual(cache.getValue(for: "Key4"), 4, "Key4 should exist as the newly added element.")
    }

    /// Test mixed behavior involving TTL expiration, updates, and LRU policy.
    func testComprehensiveScenario2() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Step 1: Insert three elements with TTL
        _ = cache.unsafeSet(value: 1, for: "Key1", expiredIn: 2) // Short-lived TTL
        _ = cache.unsafeSet(value: 2, for: "Key2", expiredIn: 10)
        _ = cache.unsafeSet(value: 3, for: "Key3", expiredIn: 10)

        sleep(3) // Allow Key1 to expire

        // Step 2: Insert a new element after expiration
        _ = cache.unsafeSet(value: 4, for: "Key4", expiredIn: 10)

        // Step 3: Update an existing key (Key3) and validate TTL behavior
        _ = cache.unsafeSet(value: 5, for: "Key3", expiredIn: 1)

        sleep(2) // Allow Key3 to expire

        // Validations
        XCTAssertNil(cache.getValue(for: "Key1"), "Key1 should have expired.")
        XCTAssertEqual(cache.getValue(for: "Key2"), 2, "Key2 should still exist.")
        XCTAssertNil(cache.getValue(for: "Key3"), "Key3 should have expired after its updated TTL.")
        XCTAssertEqual(cache.getValue(for: "Key4"), 4, "Key4 should still exist as the newly added element.")
    }

    /// Test sequential operations including access to update LRU and trigger evictions.
    func testComprehensiveScenario3() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Step 1: Insert three elements
        _ = cache.unsafeSet(value: 10, for: "Key1", expiredIn: 10)
        _ = cache.unsafeSet(value: 20, for: "Key2", expiredIn: 10)
        _ = cache.unsafeSet(value: 30, for: "Key3", expiredIn: 10)

        // Step 2: Access Key1 to update its LRU position
        XCTAssertEqual(cache.getValue(for: "Key1"), 10, "Key1 should exist and be accessed to update its LRU position.")

        // Step 3: Insert a new element to trigger LRU policy
        _ = cache.unsafeSet(value: 40, for: "Key4", expiredIn: 10)

        // Validations
        XCTAssertNil(cache.getValue(for: "Key2"), "Key2 should have been evicted due to LRU policy.")
        XCTAssertEqual(cache.getValue(for: "Key1"), 10, "Key1 should still exist as it was recently accessed.")
        XCTAssertEqual(cache.getValue(for: "Key3"), 30, "Key3 should still exist.")
        XCTAssertEqual(cache.getValue(for: "Key4"), 40, "Key4 should exist as the newly added element.")
    }

    /// Test inserting duplicate keys with updated TTL values and ensure proper expiration.
    func testComprehensiveScenario4() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Step 1: Insert the same key multiple times with different TTLs
        _ = cache.unsafeSet(value: 10, for: "Key1", expiredIn: 1) // Set a short TTL
        sleep(2) // Allow Key1 to expire

        _ = cache.unsafeSet(value: 20, for: "Key1", expiredIn: 10) // Reinsert Key1 with a longer TTL

        // Validations
        XCTAssertEqual(cache.getValue(for: "Key1"), 20, "Key1 should have the updated value and TTL.")
    }

    /// Test handling a cache with zero capacity to ensure no values are stored.
    func testComprehensiveScenario5() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 0)

        // Attempt to insert values into a zero-capacity cache
        _ = cache.unsafeSet(value: 1, for: "Key1", expiredIn: 10)

        // Validations
        XCTAssertNil(cache.getValue(for: "Key1"), "No values should be stored in a zero-capacity cache.")
    }
    
    /// Test re-setting a key after expiration to ensure correct behavior.
    func testReSetAfterExpiration() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Step 1: Insert a key with a short TTL and let it expire
        _ = cache.unsafeSet(value: 10, for: "Key1", expiredIn: 1)
        sleep(2) // Let Key1 expire

        // Step 2: Re-insert the same key with a new TTL
        _ = cache.unsafeSet(value: 20, for: "Key1", expiredIn: 5)

        // Validate the updated key
        XCTAssertEqual(cache.getValue(for: "Key1"), 20, "After expiration, re-inserting Key1 should update its value and TTL.")
    }
    
    /// Test behavior when multiple keys expire at the same time.
    func testMultipleKeysExpireSimultaneously() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Insert keys with the same TTL
        _ = cache.unsafeSet(value: 10, for: "Key1", expiredIn: 2)
        _ = cache.unsafeSet(value: 20, for: "Key2", expiredIn: 2)
        _ = cache.unsafeSet(value: 30, for: "Key3", expiredIn: 5)

        sleep(3) // Allow Key1 and Key2 to expire

        // Validate expiration
        XCTAssertNil(cache.getValue(for: "Key1"), "Key1 should expire.")
        XCTAssertNil(cache.getValue(for: "Key2"), "Key2 should expire.")
        XCTAssertEqual(cache.getValue(for: "Key3"), 30, "Key3 should still exist.")
    }
    
    /// Test removing expired keys to ensure proper behavior.
    func testRemoveExpiredKey() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        // Step 1: Insert a key with a short TTL
        _ = cache.unsafeSet(value: 10, for: "Key1", expiredIn: 1)
        sleep(2) // Let Key1 expire

        // Step 2: Remove expired key
        let removedValue = cache.unsafeRemoveValue(for: "Key1")

        // Validate removal behavior
        XCTAssertEqual(removedValue, 10, "Removing an expired key should return its original value.")
        XCTAssertNil(cache.getValue(for: "Key1"), "Key1 should no longer exist in the cache.")
    }

    // MARK: - Edge Case Tests
    /// Test handling capacity of zero.
    func testCapacityZero() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 0)

        _ = cache.unsafeSet(value: 10, for: "key1", expiredIn: 10)
        XCTAssertNil(cache.getValue(for: "key1"), "Cache with zero capacity should not hold any values.")
    }

    /// Test behavior when inserting duplicate keys.
    func testInsertDuplicates() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 5)

        _ = cache.unsafeSet(value: 10, for: "key1", expiredIn: 10)
        _ = cache.unsafeSet(value: 20, for: "key1", expiredIn: 20) // Overwrite

        XCTAssertEqual(cache.getValue(for: "key1"), 20, "The value for 'key1' should reflect the last inserted value.")
    }

    /// Test retrieving expired keys does not affect valid entries.
    func testRetrievingExpiredKeys() {
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: 3)

        _ = cache.unsafeSet(value: 10, for: "key1", expiredIn: 1) // TTL: 1 second
        _ = cache.unsafeSet(value: 20, for: "key2", expiredIn: 10)

        sleep(2) // Allow key1 to expire

        XCTAssertNil(cache.getValue(for: "key1"), "Expired key1 should return nil.")
        XCTAssertEqual(cache.getValue(for: "key2"), 20, "Valid key2 should still return its value.")
    }
}
