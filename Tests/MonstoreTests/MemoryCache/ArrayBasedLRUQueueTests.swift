//
//  ArrayBasedLRUQueueTests.swift
//
//
//  Created by Larkin on 2025/7/12.
//

import XCTest
@testable import Monstore

final class ArrayBasedLRUQueueTests: XCTestCase {
    // MARK: - Initialization Tests
    func testInitialization() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 3)
        XCTAssertEqual(queue.capacity, 3)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertFalse(queue.isFull)
    }

    // MARK: - Insert and Retrieve Tests
    func testSetAndGetValue() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 3)
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        _ = queue.setValue(30, for: "key3")
        XCTAssertEqual(queue.getValue(for: "key1"), 10)
        XCTAssertEqual(queue.getValue(for: "key2"), 20)
        XCTAssertEqual(queue.getValue(for: "key3"), 30)
        XCTAssertNil(queue.getValue(for: "key4"))
    }

    // MARK: - LRU Behavior Tests
    func testLRUStrategy() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 3)
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        _ = queue.setValue(30, for: "key3")
        _ = queue.getValue(for: "key1") // key1 is now most recently used
        _ = queue.setValue(40, for: "key4") // should evict key2
        XCTAssertNil(queue.getValue(for: "key2"))
        XCTAssertEqual(queue.getValue(for: "key1"), 10)
        XCTAssertEqual(queue.getValue(for: "key3"), 30)
        XCTAssertEqual(queue.getValue(for: "key4"), 40)
    }

    // MARK: - Capacity Overflow Tests
    func testCapacityOverflow() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 2)
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        _ = queue.setValue(30, for: "key3") // should evict key1
        XCTAssertNil(queue.getValue(for: "key1"))
        XCTAssertEqual(queue.getValue(for: "key2"), 20)
        XCTAssertEqual(queue.getValue(for: "key3"), 30)
    }

    // MARK: - Remove Element Tests
    func testRemoveValue() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 3)
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        XCTAssertEqual(queue.removeValue(for: "key1"), 10)
        XCTAssertNil(queue.getValue(for: "key1"))
        XCTAssertNil(queue.removeValue(for: "key3"))
    }

    // MARK: - Order Management Tests
    func testOrderAfterAccess() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 3)
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        _ = queue.setValue(30, for: "key3")
        _ = queue.getValue(for: "key1") // key1 should be most recently used
        // No description property, so we can't check order directly, but we can check eviction order
        _ = queue.setValue(40, for: "key4") // should evict key2
        XCTAssertNil(queue.getValue(for: "key2"))
        XCTAssertEqual(queue.getValue(for: "key1"), 10)
    }

    // MARK: - Edge Case Tests
    func testEdgeCases() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 0)
        XCTAssertEqual(queue.setValue(10, for: "key1"), 10)
        XCTAssertNil(queue.getValue(for: "key1"))
        XCTAssertNil(queue.removeValue(for: "key1"))
    }

    // MARK: - Empty Queue Behavior
    func testEmptyQueue() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 3)
        XCTAssertTrue(queue.isEmpty)
        _ = queue.setValue(10, for: "key1")
        XCTAssertFalse(queue.isEmpty)
        _ = queue.removeValue(for: "key1")
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: - Overwrite Existing Key
    func testOverwriteExistingValue() {
        let queue = ArrayBasedLRUQueue<String, Int>(capacity: 2)
        _ = queue.setValue(1, for: "a")
        _ = queue.setValue(2, for: "b")
        _ = queue.setValue(9, for: "a") // overwrite
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.getValue(for: "a"), 9)
        XCTAssertEqual(queue.getValue(for: "b"), 2)
    }
}
