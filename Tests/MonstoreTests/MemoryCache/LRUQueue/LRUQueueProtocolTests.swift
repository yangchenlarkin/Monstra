//
//  LRUQueueProtocolTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/12.
//

import XCTest
@testable import Monstore

/// Generic test class for any LRU queue implementation that conforms to LRUQueueProtocol
/// This allows us to test multiple implementations with the same test cases
class LRUQueueProtocolTests<Queue: LRUQueueProtocol>: XCTestCase where Queue.K == String, Queue.Element == Int {
    
    // Factory method to create the queue instance - subclasses must override this
    func createQueue(capacity: Int) -> Queue {
        fatalError("Subclasses must override createQueue(capacity:)")
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        let queue = createQueue(capacity: 3)
        XCTAssertEqual(queue.capacity, 3)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertFalse(queue.isFull)
    }
    
    // MARK: - Insert and Retrieve Tests
    
    func testSetAndGetValue() {
        let queue = createQueue(capacity: 3)
        
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
        let queue = createQueue(capacity: 3)
        
        // Insert initial elements
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        _ = queue.setValue(30, for: "key3")
        
        // Access key1 to make it the most recently used
        _ = queue.getValue(for: "key1")
        
        // Insert a new element, triggering LRU eviction
        _ = queue.setValue(40, for: "key4")
        
        XCTAssertNil(queue.getValue(for: "key2"), "'key2' should be evicted since it is the least recently used.")
        XCTAssertEqual(queue.getValue(for: "key1"), 10, "'key1' should still exist as it is most recently used.")
        XCTAssertEqual(queue.getValue(for: "key3"), 30, "'key3' should still exist.")
        XCTAssertEqual(queue.getValue(for: "key4"), 40, "'key4' should be the most recently inserted element.")
    }
    
    // MARK: - Capacity Overflow Tests
    
    func testCapacityOverflow() {
        let queue = createQueue(capacity: 2)
        
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        _ = queue.setValue(30, for: "key3") // This should evict key1
        
        XCTAssertNil(queue.getValue(for: "key1"), "When capacity is exceeded, the least recently used entry ('key1') should be evicted.")
        XCTAssertEqual(queue.getValue(for: "key2"), 20, "'key2' should still exist.")
        XCTAssertEqual(queue.getValue(for: "key3"), 30, "'key3' should still exist.")
    }
    
    // MARK: - Remove Element Tests
    
    func testRemoveValue() {
        let queue = createQueue(capacity: 3)
        
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        
        XCTAssertEqual(queue.removeValue(for: "key1"), 10, "'key1' should be removed and return the correct value.")
        XCTAssertNil(queue.getValue(for: "key1"), "'key1' should not exist after removal.")
        XCTAssertNil(queue.removeValue(for: "key3"), "Removing a non-existent key should return nil.")
    }
    
    // MARK: - Order Management Tests
    
    func testOrderAfterAccess() {
        let queue = createQueue(capacity: 3)
        
        _ = queue.setValue(10, for: "key1")
        _ = queue.setValue(20, for: "key2")
        _ = queue.setValue(30, for: "key3")
        
        // Access key1 to reorder
        _ = queue.getValue(for: "key1")
        
        // Insert a new element to trigger eviction and verify LRU order
        _ = queue.setValue(40, for: "key4")
        
        XCTAssertNil(queue.getValue(for: "key2"), "'key2' should be evicted as it's least recently used.")
        XCTAssertEqual(queue.getValue(for: "key1"), 10, "'key1' should still exist as it was accessed most recently.")
        XCTAssertEqual(queue.getValue(for: "key3"), 30, "'key3' should still exist.")
        XCTAssertEqual(queue.getValue(for: "key4"), 40, "'key4' should be the most recently inserted element.")
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCases() {
        let queue = createQueue(capacity: 0)
        
        XCTAssertEqual(queue.setValue(10, for: "key1"), 10, "Inserting into a capacity-0 queue should return the value as it cannot be stored.")
        XCTAssertNil(queue.getValue(for: "key1"), "Retrieving from a capacity-0 queue should return nil.")
        XCTAssertNil(queue.removeValue(for: "key1"), "Removing from a capacity-0 queue should return nil.")
    }
    
    // MARK: - Empty Queue Behavior
    
    func testEmptyQueue() {
        let queue = createQueue(capacity: 3)
        
        XCTAssertTrue(queue.isEmpty, "Newly initialized queue should be empty.")
        
        _ = queue.setValue(10, for: "key1")
        XCTAssertFalse(queue.isEmpty, "Queue should not be empty after inserting an element.")
        
        _ = queue.removeValue(for: "key1")
        XCTAssertTrue(queue.isEmpty, "Queue should be empty after removing the only element.")
    }
    
    // MARK: - Overwrite Existing Key Tests
    
    func testOverwriteExistingValue() {
        let queue = createQueue(capacity: 2)
        
        _ = queue.setValue(1, for: "a")
        _ = queue.setValue(2, for: "b")
        _ = queue.setValue(9, for: "a") // overwrite existing key
        
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.getValue(for: "a"), 9)
        XCTAssertEqual(queue.getValue(for: "b"), 2)
    }
    
    // MARK: - Full Queue Behavior Tests
    
    func testFullQueueBehavior() {
        let queue = createQueue(capacity: 2)
        
        _ = queue.setValue(1, for: "a")
        _ = queue.setValue(2, for: "b")
        
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.count, 2)
        
        // Adding another element should evict the least recently used
        _ = queue.setValue(3, for: "c")
        
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.count, 2)
        XCTAssertNil(queue.getValue(for: "a")) // Should be evicted
        XCTAssertEqual(queue.getValue(for: "b"), 2)
        XCTAssertEqual(queue.getValue(for: "c"), 3)
    }
    
    // MARK: - LRU Eviction Order Tests
    
    func testLRUEvictionOrder() {
        let queue = createQueue(capacity: 3)
        
        // Insert elements
        _ = queue.setValue(1, for: "a")
        _ = queue.setValue(2, for: "b")
        _ = queue.setValue(3, for: "c")
        
        // Access in different order
        _ = queue.getValue(for: "b") // b becomes most recently used
        _ = queue.getValue(for: "a") // a becomes most recently used
        _ = queue.getValue(for: "c") // c becomes most recently used
        
        // Add new element - should evict 'b' as it's now least recently used
        _ = queue.setValue(4, for: "d")
        
        XCTAssertNil(queue.getValue(for: "b"))
        XCTAssertEqual(queue.getValue(for: "a"), 1)
        XCTAssertEqual(queue.getValue(for: "c"), 3)
        XCTAssertEqual(queue.getValue(for: "d"), 4)
    }
} 