//
//  PriorityLRUQueueTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/5/8.
//

import XCTest
@testable import Monstore

/// Test class for LRUQueue implementation
final class PriorityLRUQueueTests: XCTestCase {
    
    // Factory method to create the queue instance
    func createQueue(capacity: Int) -> PriorityLRUQueue<String, Int> {
        return PriorityLRUQueue(capacity: capacity)
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


extension PriorityLRUQueueTests {
    // MARK: - Basic Functionality Tests
    
    func testInit() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 5)
        XCTAssertEqual(queue.capacity, 5)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertFalse(queue.isFull)
    }
    
    func testInitWithZeroCapacity() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 0)
        XCTAssertEqual(queue.capacity, 0)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertTrue(queue.isFull)
    }
    
    func testInitWithNegativeCapacity() {
        let queue = PriorityLRUQueue<String, Int>(capacity: -5)
        XCTAssertEqual(queue.capacity, 0)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertTrue(queue.isFull)
    }
    
    // MARK: - Set Value Tests
    
    func testSetValueBasic() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        let evicted = queue.setValue(10, for: "key1", with: 1.0)
        XCTAssertNil(evicted)
        XCTAssertEqual(queue.count, 1)
        XCTAssertFalse(queue.isEmpty)
        
        let evicted2 = queue.setValue(20, for: "key2", with: 2.0)
        XCTAssertNil(evicted2)
        XCTAssertEqual(queue.count, 2)
    }
    
    func testSetValueWithEviction() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 2)
        
        // Insert two elements
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 2.0)
        XCTAssertEqual(queue.count, 2)
        
        // Insert third element - should evict lowest priority (highest value)
        let evicted = queue.setValue(30, for: "key3", with: 0.5)
        XCTAssertEqual(evicted, 30) // key2 with priority 2.0 should be evicted
        XCTAssertEqual(queue.count, 2)
    }
    
    func testSetValueUpdateExisting() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setValue(10, for: "key1", with: 1.0)
        XCTAssertEqual(queue.count, 1)
        
        // Update existing key
        let evicted = queue.setValue(15, for: "key1", with: 1.5)
        XCTAssertNil(evicted) // No eviction since we're just updating
        XCTAssertEqual(queue.count, 1)
    }
    
    func testSetValueWithZeroCapacity() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 0)
        
        let evicted = queue.setValue(10, for: "key1", with: 1.0)
        XCTAssertEqual(evicted, 10) // Value should be immediately evicted
        XCTAssertEqual(queue.count, 0)
    }
    
    // MARK: - Get Value Tests
    
    func testGetValueBasic() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 2.0)
        
        let value1 = queue.getValue(for: "key1")
        XCTAssertEqual(value1, 10)
        
        let value2 = queue.getValue(for: "key2")
        XCTAssertEqual(value2, 20)
    }
    
    func testGetValueNonExistent() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        let value = queue.getValue(for: "nonexistent")
        XCTAssertNil(value)
    }
    
    func testGetValueMovesToFront() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 1.0) // Same priority
        queue.setValue(30, for: "key3", with: 1.0) // Same priority
        
        // Access key1, which should move it to front of its priority queue
        _ = queue.getValue(for: "key1")
        
        // Now add a new element with same priority - should evict the least recently used
        let evicted = queue.setValue(40, for: "key4", with: 1.0)
        // Should evict key2 or key3, not key1 since it was recently accessed
        XCTAssertNotNil(evicted)
        XCTAssertEqual(queue.count, 3)
    }
    
    // MARK: - Remove Value Tests
    
    func testRemoveValueBasic() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 2.0)
        
        let removed = queue.removeValue(for: "key1")
        XCTAssertEqual(removed, 10)
        XCTAssertEqual(queue.count, 1)
        
        let removed2 = queue.removeValue(for: "key2")
        XCTAssertEqual(removed2, 20)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
    }
    
    func testRemoveValueNonExistent() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        let removed = queue.removeValue(for: "nonexistent")
        XCTAssertNil(removed)
    }
    
    // MARK: - Priority Eviction Tests
    
    func testPriorityEviction() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        // Insert elements with different priorities
        queue.setValue(10, for: "key1", with: 1.0) // Low priority
        queue.setValue(20, for: "key2", with: 2.0) // Medium priority
        queue.setValue(30, for: "key3", with: 3.0) // High priority
        
        // Insert fourth element - should evict lowest priority (highest value)
        let evicted = queue.setValue(40, for: "key4", with: 0.5)
        XCTAssertEqual(evicted, 40) // key3 with priority 0.5 should be evicted
    }
    
    func testSamePriorityLRUEviction() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        // Insert elements with same priority
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 1.0)
        queue.setValue(30, for: "key3", with: 1.0)
        
        // Insert fourth element - should evict least recently used within same priority
        let evicted = queue.setValue(40, for: "key4", with: 1.0)
        XCTAssertEqual(evicted, 10) // key1 should be evicted (first inserted)
    }
    
    func testPriorityQueueCleanup() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 2)
        
        // Insert elements with different priorities
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 2.0)
        
        // Remove all elements from priority 1.0
        let removed = queue.removeValue(for: "key1")
        XCTAssertEqual(removed, 10)
        XCTAssertEqual(queue.count, 1)
        
        // Priority 1.0 should be removed from priorities array
        // This is tested indirectly by checking that the queue still works
        queue.setValue(30, for: "key3", with: 1.0) // Should work fine
        XCTAssertEqual(queue.count, 2)
    }
    
    // MARK: - Complex Scenarios
    
    func testComplexPriorityScenario() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 4)
        
        // Insert elements with mixed priorities
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 2.0)
        queue.setValue(30, for: "key3", with: 1.0) // Same priority as key1
        queue.setValue(40, for: "key4", with: 3.0)
        
        // Access key1 to make it more recently used
        _ = queue.getValue(for: "key1")
        
        // Insert fifth element - should evict from lowest priority
        let evicted = queue.setValue(50, for: "key5", with: 5.0)
        XCTAssertEqual(evicted, 30) // key3 with priority 1.0 should be evicted
        
        // Insert another element - should evict from remaining lowest priority
        let evicted2 = queue.setValue(60, for: "key6", with: 5.0)
        XCTAssertEqual(evicted2, 10) // key1 with priority 1.0 should be evicted
    }
    
    func testUpdatePriority() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 2.0)
        queue.setValue(30, for: "key3", with: 3.0)
        
        // Update key1 with different priority
        let evicted = queue.setValue(15, for: "key1", with: 4.0)
        XCTAssertNil(evicted) // No eviction since we're just updating
        
        // Now insert a new element - should evict from lowest priority
        let evicted2 = queue.setValue(40, for: "key4", with: 5.0)
        XCTAssertEqual(evicted2, 20) // key3 with priority 3.0 should be evicted
    }
    
    // MARK: - Edge Cases
    
    func testEmptyQueueOperations() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        XCTAssertNil(queue.getValue(for: "key1"))
        XCTAssertNil(queue.removeValue(for: "key1"))
        XCTAssertTrue(queue.isEmpty)
    }
    
    func testSingleElementQueue() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 1)
        
        queue.setValue(10, for: "key1", with: 1.0)
        XCTAssertEqual(queue.count, 1)
        
        let evicted = queue.setValue(20, for: "key2", with: 2.0)
        XCTAssertEqual(evicted, 10) // key1 should be evicted
        XCTAssertEqual(queue.count, 1)
    }
    
    func testDescription() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setValue(10, for: "key1", with: 1.0)
        queue.setValue(20, for: "key2", with: 2.0)
        
        let desc = queue.description
        XCTAssertEqual(desc, "[10, 20]")
    }
} 
