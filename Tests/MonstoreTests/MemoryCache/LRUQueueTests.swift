//
//  LRUQueueTests.swift
//
//  Created by Larkin on 2025/5/9.
//

import XCTest

@testable import Monstore

/// Unit tests for LRUQueue class, covering basic functionality,
/// edge cases, and LRU cache behavior.
final class LRUQueueTests: XCTestCase {

    // MARK: - Initialization Tests

    /// Test queue initialization with a valid capacity and initial states.
    func testInitialization() {
        let queue = LRUQueue<String, Int>(capacity: 3)
        XCTAssertEqual(queue.capacity, 3, "The queue capacity should be initialized correctly.")
        XCTAssertTrue(queue.isEmpty, "A newly created queue should be empty.")
        XCTAssertFalse(queue.isFull, "A newly created queue shouldn't be full.")
    }

    // MARK: - Insert and Retrieve Tests

    /// Test inserting and retrieving values from the queue.
    func testSetAndGetValue() {
        let queue = LRUQueue<String, Int>(capacity: 3)

        _ = queue.unsafeSetValue(10, for: "key1")
        _ = queue.unsafeSetValue(20, for: "key2")
        _ = queue.unsafeSetValue(30, for: "key3")

        XCTAssertEqual(queue.unsafeGetValue(for: "key1"), 10, "The retrieved value for 'key1' should match the inserted value.")
        XCTAssertEqual(queue.unsafeGetValue(for: "key2"), 20, "The retrieved value for 'key2' should match the inserted value.")
        XCTAssertEqual(queue.unsafeGetValue(for: "key3"), 30, "The retrieved value for 'key3' should match the inserted value.")
        XCTAssertNil(queue.unsafeGetValue(for: "key4"), "Retrieving a non-existent key should return nil.")
    }

    // MARK: - LRU Behavior Tests

    /// Test the correct implementation of LRU eviction policy.
    func testLRUStrategy() {
        let queue = LRUQueue<String, Int>(capacity: 3)

        // Insert initial elements
        _ = queue.unsafeSetValue(10, for: "key1")
        _ = queue.unsafeSetValue(20, for: "key2")
        _ = queue.unsafeSetValue(30, for: "key3")

        // Access key1 to make it the most recently used
        _ = queue.unsafeGetValue(for: "key1")

        // Insert a new element, triggering LRU eviction
        _ = queue.unsafeSetValue(40, for: "key4")

        XCTAssertNil(queue.unsafeGetValue(for: "key2"), "'key2' should be evicted since it is the least recently used.")
        XCTAssertEqual(queue.unsafeGetValue(for: "key1"), 10, "'key1' should still exist as it is most recently used.")
        XCTAssertEqual(queue.unsafeGetValue(for: "key3"), 30, "'key3' should still exist.")
        XCTAssertEqual(queue.unsafeGetValue(for: "key4"), 40, "'key4' should be the most recently inserted element.")
    }

    // MARK: - Capacity Overflow Tests

    /// Test correct eviction behavior when the queue exceeds capacity.
    func testCapacityOverflow() {
        let queue = LRUQueue<String, Int>(capacity: 2)

        _ = queue.unsafeSetValue(10, for: "key1")
        _ = queue.unsafeSetValue(20, for: "key2")
        _ = queue.unsafeSetValue(30, for: "key3") // This should evict key1

        XCTAssertNil(queue.unsafeGetValue(for: "key1"), "When capacity is exceeded, the least recently used entry ('key1') should be evicted.")
        XCTAssertEqual(queue.unsafeGetValue(for: "key2"), 20, "'key2' should still exist.")
        XCTAssertEqual(queue.unsafeGetValue(for: "key3"), 30, "'key3' should still exist.")
    }

    // MARK: - Remove Element Tests

    /// Test removing elements from the queue.
    func testRemoveValue() {
        let queue = LRUQueue<String, Int>(capacity: 3)

        _ = queue.unsafeSetValue(10, for: "key1")
        _ = queue.unsafeSetValue(20, for: "key2")

        XCTAssertEqual(queue.unsafeRemoveValue(for: "key1"), 10, "'key1' should be removed and return the correct value.")
        XCTAssertNil(queue.unsafeGetValue(for: "key1"), "'key1' should not exist after removal.")
        XCTAssertNil(queue.unsafeRemoveValue(for: "key3"), "Removing a non-existent key should return nil.")
    }

    // MARK: - Order Management Tests

    /// Test whether accessing an element updates its order in the queue.
    func testOrderAfterAccess() {
        let queue = LRUQueue<String, Int>(capacity: 3)

        _ = queue.unsafeSetValue(10, for: "key1")
        _ = queue.unsafeSetValue(20, for: "key2")
        _ = queue.unsafeSetValue(30, for: "key3")

        // Access key1 to reorder
        _ = queue.unsafeGetValue(for: "key1")

        // Check if the description reflects the updated order
        XCTAssertEqual(queue.description, "[10, 30, 20]", "Accessing 'key1' should move it to the front of the queue.")
    }

    // MARK: - Edge Case Tests

    /// Test edge cases like capacity zero or overwriting the same key.
    func testEdgeCases() {
        let queue = LRUQueue<String, Int>(capacity: 0)

        XCTAssertNil(queue.unsafeSetValue(10, for: "key1"), "Inserting into a capacity-0 queue should not store the element.")
        XCTAssertNil(queue.unsafeGetValue(for: "key1"), "Retrieving from a capacity-0 queue should return nil.")
        XCTAssertNil(queue.unsafeRemoveValue(for: "key1"), "Removing from a capacity-0 queue should return nil.")
    }

    // MARK: - Empty Queue Behavior

    /// Test behaviors on an empty queue after initialization or removal.
    func testEmptyQueue() {
        let queue = LRUQueue<String, Int>(capacity: 3)

        XCTAssertTrue(queue.isEmpty, "Newly initialized queue should be empty.")

        _ = queue.unsafeSetValue(10, for: "key1")
        XCTAssertFalse(queue.isEmpty, "Queue should not be empty after inserting an element.")

        _ = queue.unsafeRemoveValue(for: "key1")
        XCTAssertTrue(queue.isEmpty, "Queue should be empty after removing the only element.")
    }

    // MARK: - Additional Behavior Tests

    /// Test inserting and overwriting an element within capacity.
    func testInsertWithinCapacity() {
        let queue = LRUQueue<String, Int>(capacity: 3)

        _ = queue.unsafeSetValue(1, for: "a")
        _ = queue.unsafeSetValue(2, for: "b")
        _ = queue.unsafeSetValue(3, for: "c")

        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(Array(queue), [3, 2, 1])
    }

    /// Test overwriting an existing key and moving it to the front.
    func testOverwriteExistingValue() {
        let queue = LRUQueue<String, Int>(capacity: 2)

        _ = queue.unsafeSetValue(1, for: "a")
        _ = queue.unsafeSetValue(2, for: "b")
        _ = queue.unsafeSetValue(9, for: "a") // overwrite

        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(Array(queue), [9, 2])
    }

    /// Test the queue description format.
    func testDescriptionFormat() {
        let queue = LRUQueue<String, Int>(capacity: 2)

        _ = queue.unsafeSetValue(100, for: "a")
        _ = queue.unsafeSetValue(200, for: "b")

        XCTAssertEqual(queue.description, "[200, 100]", "The description should reflect the correct element order.")
    }
}
