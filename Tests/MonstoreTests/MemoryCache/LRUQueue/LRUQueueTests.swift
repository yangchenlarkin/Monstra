//
//  LRUQueueTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/12.
//

import XCTest
@testable import Monstore

/// Test class for LRUQueue implementation
final class LRUQueueTests: XCTestCase {
    
    // Factory method to create the queue instance
    func createQueue(capacity: Int) -> LRUQueue<String, Int> {
        return LRUQueue(capacity: capacity)
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
        
        // Test setValue return values
        XCTAssertNil(queue.setValue(10, for: "key1"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(20, for: "key2"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(30, for: "key3"), "setValue should return nil for new key")
        
        // Test getValue return values
        XCTAssertEqual(queue.getValue(for: "key1"), 10, "getValue should return the correct value")
        XCTAssertEqual(queue.getValue(for: "key2"), 20, "getValue should return the correct value")
        XCTAssertEqual(queue.getValue(for: "key3"), 30, "getValue should return the correct value")
        XCTAssertNil(queue.getValue(for: "key4"), "getValue should return nil for non-existent key")
    }
    
    // MARK: - LRU Behavior Tests
    
    func testLRUStrategy() {
        let queue = createQueue(capacity: 3)
        
        // Insert initial elements and verify return values
        XCTAssertNil(queue.setValue(10, for: "key1"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(20, for: "key2"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(30, for: "key3"), "setValue should return nil for new key")
        
        // Access key1 to make it the most recently used
        XCTAssertEqual(queue.getValue(for: "key1"), 10, "getValue should return the correct value")
        
        // Insert a new element, triggering LRU eviction
        XCTAssertEqual(queue.setValue(40, for: "key4"), 20, "setValue should return evicted value when capacity is exceeded")
        
        XCTAssertNil(queue.getValue(for: "key2"), "'key2' should be evicted since it is the least recently used.")
        XCTAssertEqual(queue.getValue(for: "key1"), 10, "'key1' should still exist as it is most recently used.")
        XCTAssertEqual(queue.getValue(for: "key3"), 30, "'key3' should still exist.")
        XCTAssertEqual(queue.getValue(for: "key4"), 40, "'key4' should be the most recently inserted element.")
    }
    
    // MARK: - Capacity Overflow Tests
    
    func testCapacityOverflow() {
        let queue = createQueue(capacity: 2)
        
        // Test setValue return values for capacity overflow
        XCTAssertNil(queue.setValue(10, for: "key1"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(20, for: "key2"), "setValue should return nil for new key")
        XCTAssertEqual(queue.setValue(30, for: "key3"), 10, "setValue should return evicted value when capacity is exceeded")
        
        XCTAssertNil(queue.getValue(for: "key1"), "When capacity is exceeded, the least recently used entry ('key1') should be evicted.")
        XCTAssertEqual(queue.getValue(for: "key2"), 20, "'key2' should still exist.")
        XCTAssertEqual(queue.getValue(for: "key3"), 30, "'key3' should still exist.")
    }
    
    // MARK: - Remove Element Tests
    
    func testRemoveValue() {
        let queue = createQueue(capacity: 3)
        
        // Test setValue return values
        XCTAssertNil(queue.setValue(10, for: "key1"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(20, for: "key2"), "setValue should return nil for new key")
        
        // Test removeValue return values
        XCTAssertEqual(queue.removeValue(for: "key1"), 10, "'key1' should be removed and return the correct value.")
        XCTAssertNil(queue.getValue(for: "key1"), "'key1' should not exist after removal.")
        XCTAssertNil(queue.removeValue(for: "key3"), "Removing a non-existent key should return nil.")
    }
    
    // MARK: - Order Management Tests
    
    func testOrderAfterAccess() {
        let queue = createQueue(capacity: 3)
        
        // Test setValue return values
        XCTAssertNil(queue.setValue(10, for: "key1"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(20, for: "key2"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(30, for: "key3"), "setValue should return nil for new key")
        
        // Access key1 to reorder and verify getValue return value
        XCTAssertEqual(queue.getValue(for: "key1"), 10, "getValue should return the correct value")
        
        // Insert a new element to trigger eviction and verify LRU order
        XCTAssertEqual(queue.setValue(40, for: "key4"), 20, "setValue should return evicted value when capacity is exceeded")
        
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
        
        // Test setValue return values for new keys
        XCTAssertNil(queue.setValue(1, for: "a"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(2, for: "b"), "setValue should return nil for new key")
        
        // Test setValue return value for overwriting existing key
        XCTAssertNil(queue.setValue(9, for: "a"), "setValue should return nil when overwriting existing key")
        
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.getValue(for: "a"), 9, "getValue should return the updated value")
        XCTAssertEqual(queue.getValue(for: "b"), 2, "getValue should return the correct value")
    }
    
    // MARK: - Full Queue Behavior Tests
    
    func testFullQueueBehavior() {
        let queue = createQueue(capacity: 2)
        
        // Test setValue return values for new keys
        XCTAssertNil(queue.setValue(1, for: "a"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(2, for: "b"), "setValue should return nil for new key")
        
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.count, 2)
        
        // Adding another element should evict the least recently used
        XCTAssertEqual(queue.setValue(3, for: "c"), 1, "setValue should return evicted value when capacity is exceeded")
        
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.count, 2)
        XCTAssertNil(queue.getValue(for: "a"), "Should be evicted") // Should be evicted
        XCTAssertEqual(queue.getValue(for: "b"), 2, "getValue should return the correct value")
        XCTAssertEqual(queue.getValue(for: "c"), 3, "getValue should return the correct value")
    }
    
    // MARK: - LRU Eviction Order Tests
    
    func testLRUEvictionOrder() {
        let queue = createQueue(capacity: 3)
        
        // Insert elements and verify setValue return values
        XCTAssertNil(queue.setValue(1, for: "a"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(2, for: "b"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(3, for: "c"), "setValue should return nil for new key")
        
        // Access in different order and verify getValue return values
        XCTAssertEqual(queue.getValue(for: "b"), 2, "getValue should return the correct value") // b becomes most recently used
        XCTAssertEqual(queue.getValue(for: "a"), 1, "getValue should return the correct value") // a becomes most recently used
        XCTAssertEqual(queue.getValue(for: "c"), 3, "getValue should return the correct value") // c becomes most recently used
        
        // Add new element - should evict 'b' as it's now least recently used
        XCTAssertEqual(queue.setValue(4, for: "d"), 2, "setValue should return evicted value when capacity is exceeded")
        
        XCTAssertNil(queue.getValue(for: "b"), "getValue should return nil for evicted key")
        XCTAssertEqual(queue.getValue(for: "a"), 1, "getValue should return the correct value")
        XCTAssertEqual(queue.getValue(for: "c"), 3, "getValue should return the correct value")
        XCTAssertEqual(queue.getValue(for: "d"), 4, "getValue should return the correct value")
    }
    
    // MARK: - Return Value Tests
    
    func testReturnValues() {
        let queue = createQueue(capacity: 2)
        
        // Test setValue return values for different scenarios
        XCTAssertNil(queue.setValue(10, for: "key1"), "setValue should return nil for new key")
        XCTAssertNil(queue.setValue(20, for: "key2"), "setValue should return nil for new key")
        XCTAssertEqual(queue.setValue(30, for: "key3"), 10, "setValue should return evicted value when capacity exceeded")
        
        // Test getValue return values for different scenarios
        XCTAssertEqual(queue.getValue(for: "key2"), 20, "getValue should return correct value for existing key")
        XCTAssertEqual(queue.getValue(for: "key3"), 30, "getValue should return correct value for existing key")
        XCTAssertNil(queue.getValue(for: "key1"), "getValue should return nil for evicted key")
        XCTAssertNil(queue.getValue(for: "key4"), "getValue should return nil for non-existent key")
        
        // Test removeValue return values for different scenarios
        XCTAssertEqual(queue.removeValue(for: "key2"), 20, "removeValue should return correct value for existing key")
        XCTAssertNil(queue.removeValue(for: "key2"), "removeValue should return nil for already removed key")
        XCTAssertNil(queue.removeValue(for: "key4"), "removeValue should return nil for non-existent key")
        
        // Test overwriting existing key
        XCTAssertNil(queue.setValue(40, for: "key3"), "setValue should return nil when overwriting existing key")
        XCTAssertEqual(queue.getValue(for: "key3"), 40, "getValue should return updated value after overwrite")
    }
    
    func testCapacityZeroReturnValues() {
        let queue = createQueue(capacity: 0)
        
        // Test setValue return value for capacity 0
        XCTAssertEqual(queue.setValue(10, for: "key1"), 10, "setValue should return input value when capacity is 0")
        
        // Test getValue return value for capacity 0
        XCTAssertNil(queue.getValue(for: "key1"), "getValue should return nil when capacity is 0")
        
        // Test removeValue return value for capacity 0
        XCTAssertNil(queue.removeValue(for: "key1"), "removeValue should return nil when capacity is 0")
    }
} 
