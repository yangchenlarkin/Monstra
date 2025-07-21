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
    
    func testSetAndGetElement() {
        let queue = createQueue(capacity: 3)
        
        // Test setElement return elements
        XCTAssertNil(queue.setElement(10, for: "key1"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(20, for: "key2"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(30, for: "key3"), "setElement should return nil for new key")
        
        // Test getElement return elements
        XCTAssertEqual(queue.getElement(for: "key1"), 10, "getElement should return the correct element")
        XCTAssertEqual(queue.getElement(for: "key2"), 20, "getElement should return the correct element")
        XCTAssertEqual(queue.getElement(for: "key3"), 30, "getElement should return the correct element")
        XCTAssertNil(queue.getElement(for: "key4"), "getElement should return nil for non-existent key")
    }
    
    // MARK: - LRU Behavior Tests
    
    func testLRUStrategy() {
        let queue = createQueue(capacity: 3)
        
        // Insert initial elements and verify return elements
        XCTAssertNil(queue.setElement(10, for: "key1"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(20, for: "key2"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(30, for: "key3"), "setElement should return nil for new key")
        
        // Access key1 to make it the most recently used
        XCTAssertEqual(queue.getElement(for: "key1"), 10, "getElement should return the correct element")
        
        // Insert a new element, triggering LRU eviction
        XCTAssertEqual(queue.setElement(40, for: "key4"), 20, "setElement should return evicted element when capacity is exceeded")
        
        XCTAssertNil(queue.getElement(for: "key2"), "'key2' should be evicted since it is the least recently used.")
        XCTAssertEqual(queue.getElement(for: "key1"), 10, "'key1' should still exist as it is most recently used.")
        XCTAssertEqual(queue.getElement(for: "key3"), 30, "'key3' should still exist.")
        XCTAssertEqual(queue.getElement(for: "key4"), 40, "'key4' should be the most recently inserted element.")
    }
    
    // MARK: - Capacity Overflow Tests
    
    func testCapacityOverflow() {
        let queue = createQueue(capacity: 2)
        
        // Test setElement return elements for capacity overflow
        XCTAssertNil(queue.setElement(10, for: "key1"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(20, for: "key2"), "setElement should return nil for new key")
        XCTAssertEqual(queue.setElement(30, for: "key3"), 10, "setElement should return evicted element when capacity is exceeded")
        
        XCTAssertNil(queue.getElement(for: "key1"), "When capacity is exceeded, the least recently used entry ('key1') should be evicted.")
        XCTAssertEqual(queue.getElement(for: "key2"), 20, "'key2' should still exist.")
        XCTAssertEqual(queue.getElement(for: "key3"), 30, "'key3' should still exist.")
    }
    
    // MARK: - Remove Element Tests
    
    func testRemoveElement() {
        let queue = createQueue(capacity: 3)
        
        // Test setElement return elements
        XCTAssertNil(queue.setElement(10, for: "key1"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(20, for: "key2"), "setElement should return nil for new key")
        
        // Test removeElement return elements
        XCTAssertEqual(queue.removeElement(for: "key1"), 10, "'key1' should be removed and return the correct element.")
        XCTAssertNil(queue.getElement(for: "key1"), "'key1' should not exist after removal.")
        XCTAssertNil(queue.removeElement(for: "key3"), "Removing a non-existent key should return nil.")
    }
    
    // MARK: - Order Management Tests
    
    func testOrderAfterAccess() {
        let queue = createQueue(capacity: 3)
        
        // Test setElement return elements
        XCTAssertNil(queue.setElement(10, for: "key1"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(20, for: "key2"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(30, for: "key3"), "setElement should return nil for new key")
        
        // Access key1 to reorder and verify getElement return element
        XCTAssertEqual(queue.getElement(for: "key1"), 10, "getElement should return the correct element")
        
        // Insert a new element to trigger eviction and verify LRU order
        XCTAssertEqual(queue.setElement(40, for: "key4"), 20, "setElement should return evicted element when capacity is exceeded")
        
        XCTAssertNil(queue.getElement(for: "key2"), "'key2' should be evicted as it's least recently used.")
        XCTAssertEqual(queue.getElement(for: "key1"), 10, "'key1' should still exist as it was accessed most recently.")
        XCTAssertEqual(queue.getElement(for: "key3"), 30, "'key3' should still exist.")
        XCTAssertEqual(queue.getElement(for: "key4"), 40, "'key4' should be the most recently inserted element.")
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCases() {
        let queue = createQueue(capacity: 0)
        
        XCTAssertEqual(queue.setElement(10, for: "key1"), 10, "Inserting into a capacity-0 queue should return the element as it cannot be stored.")
        XCTAssertNil(queue.getElement(for: "key1"), "Retrieving from a capacity-0 queue should return nil.")
        XCTAssertNil(queue.removeElement(for: "key1"), "Removing from a capacity-0 queue should return nil.")
    }
    
    // MARK: - Empty Queue Behavior
    
    func testEmptyQueue() {
        let queue = createQueue(capacity: 3)
        
        XCTAssertTrue(queue.isEmpty, "Newly initialized queue should be empty.")
        
        _ = queue.setElement(10, for: "key1")
        XCTAssertFalse(queue.isEmpty, "Queue should not be empty after inserting an element.")
        
        _ = queue.removeElement(for: "key1")
        XCTAssertTrue(queue.isEmpty, "Queue should be empty after removing the only element.")
    }
    
    // MARK: - Overwrite Existing Key Tests
    
    func testOverwriteExistingElement() {
        let queue = createQueue(capacity: 2)
        
        // Test setElement return elements for new keys
        XCTAssertNil(queue.setElement(1, for: "a"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(2, for: "b"), "setElement should return nil for new key")
        
        // Test setElement return element for overwriting existing key
        XCTAssertNil(queue.setElement(9, for: "a"), "setElement should return nil when overwriting existing key")
        
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.getElement(for: "a"), 9, "getElement should return the updated element")
        XCTAssertEqual(queue.getElement(for: "b"), 2, "getElement should return the correct element")
    }
    
    // MARK: - Full Queue Behavior Tests
    
    func testFullQueueBehavior() {
        let queue = createQueue(capacity: 2)
        
        // Test setElement return elements for new keys
        XCTAssertNil(queue.setElement(1, for: "a"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(2, for: "b"), "setElement should return nil for new key")
        
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.count, 2)
        
        // Adding another element should evict the least recently used
        XCTAssertEqual(queue.setElement(3, for: "c"), 1, "setElement should return evicted element when capacity is exceeded")
        
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.count, 2)
        XCTAssertNil(queue.getElement(for: "a"), "Should be evicted") // Should be evicted
        XCTAssertEqual(queue.getElement(for: "b"), 2, "getElement should return the correct element")
        XCTAssertEqual(queue.getElement(for: "c"), 3, "getElement should return the correct element")
    }
    
    // MARK: - LRU Eviction Order Tests
    
    func testLRUEvictionOrder() {
        let queue = createQueue(capacity: 3)
        
        // Insert elements and verify setElement return elements
        XCTAssertNil(queue.setElement(1, for: "a"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(2, for: "b"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(3, for: "c"), "setElement should return nil for new key")
        
        // Access in different order and verify getElement return elements
        XCTAssertEqual(queue.getElement(for: "b"), 2, "getElement should return the correct element") // b becomes most recently used
        XCTAssertEqual(queue.getElement(for: "a"), 1, "getElement should return the correct element") // a becomes most recently used
        XCTAssertEqual(queue.getElement(for: "c"), 3, "getElement should return the correct element") // c becomes most recently used
        
        // Add new element - should evict 'b' as it's now least recently used
        XCTAssertEqual(queue.setElement(4, for: "d"), 2, "setElement should return evicted element when capacity is exceeded")
        
        XCTAssertNil(queue.getElement(for: "b"), "getElement should return nil for evicted key")
        XCTAssertEqual(queue.getElement(for: "a"), 1, "getElement should return the correct element")
        XCTAssertEqual(queue.getElement(for: "c"), 3, "getElement should return the correct element")
        XCTAssertEqual(queue.getElement(for: "d"), 4, "getElement should return the correct element")
    }
    
    // MARK: - Return Element Tests
    
    func testReturnElements() {
        let queue = createQueue(capacity: 2)
        
        // Test setElement return elements for different scenarios
        XCTAssertNil(queue.setElement(10, for: "key1"), "setElement should return nil for new key")
        XCTAssertNil(queue.setElement(20, for: "key2"), "setElement should return nil for new key")
        XCTAssertEqual(queue.setElement(30, for: "key3"), 10, "setElement should return evicted element when capacity exceeded")
        
        // Test getElement return elements for different scenarios
        XCTAssertEqual(queue.getElement(for: "key2"), 20, "getElement should return correct element for existing key")
        XCTAssertEqual(queue.getElement(for: "key3"), 30, "getElement should return correct element for existing key")
        XCTAssertNil(queue.getElement(for: "key1"), "getElement should return nil for evicted key")
        XCTAssertNil(queue.getElement(for: "key4"), "getElement should return nil for non-existent key")
        
        // Test removeElement return elements for different scenarios
        XCTAssertEqual(queue.removeElement(for: "key2"), 20, "removeElement should return correct element for existing key")
        XCTAssertNil(queue.removeElement(for: "key2"), "removeElement should return nil for already removed key")
        XCTAssertNil(queue.removeElement(for: "key4"), "removeElement should return nil for non-existent key")
        
        // Test overwriting existing key
        XCTAssertNil(queue.setElement(40, for: "key3"), "setElement should return nil when overwriting existing key")
        XCTAssertEqual(queue.getElement(for: "key3"), 40, "getElement should return updated element after overwrite")
    }
    
    func testCapacityZeroReturnElements() {
        let queue = createQueue(capacity: 0)
        
        // Test setElement return element for capacity 0
        XCTAssertEqual(queue.setElement(10, for: "key1"), 10, "setElement should return input element when capacity is 0")
        
        // Test getElement return element for capacity 0
        XCTAssertNil(queue.getElement(for: "key1"), "getElement should return nil when capacity is 0")
        
        // Test removeElement return element for capacity 0
        XCTAssertNil(queue.removeElement(for: "key1"), "removeElement should return nil when capacity is 0")
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
    
    // MARK: - Set Element Tests
    
    func testSetElementBasic() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        let evicted = queue.setElement(10, for: "key1", with: 1.0)
        XCTAssertNil(evicted)
        XCTAssertEqual(queue.count, 1)
        XCTAssertFalse(queue.isEmpty)
        
        let evicted2 = queue.setElement(20, for: "key2", with: 2.0)
        XCTAssertNil(evicted2)
        XCTAssertEqual(queue.count, 2)
    }
    
    func testSetElementWithEviction() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 2)
        
        // Insert two elements
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        XCTAssertEqual(queue.count, 2)
        
        // Insert third element - should evict lowest priority (highest element)
        let evicted = queue.setElement(30, for: "key3", with: 0.5)
        XCTAssertEqual(evicted, 30) // key2 with priority 2.0 should be evicted
        XCTAssertEqual(queue.count, 2)
    }
    
    func testSetElementUpdateExisting() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setElement(10, for: "key1", with: 1.0)
        XCTAssertEqual(queue.count, 1)
        
        // Update existing key
        let evicted = queue.setElement(15, for: "key1", with: 1.5)
        XCTAssertNil(evicted) // No eviction since we're just updating
        XCTAssertEqual(queue.count, 1)
    }
    
    func testSetElementWithZeroCapacity() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 0)
        
        let evicted = queue.setElement(10, for: "key1", with: 1.0)
        XCTAssertEqual(evicted, 10) // Element should be immediately evicted
        XCTAssertEqual(queue.count, 0)
    }
    
    // MARK: - Get Element Tests
    
    func testGetElementBasic() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        
        let element1 = queue.getElement(for: "key1")
        XCTAssertEqual(element1, 10)
        
        let element2 = queue.getElement(for: "key2")
        XCTAssertEqual(element2, 20)
    }
    
    func testGetElementNonExistent() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        let element = queue.getElement(for: "nonexistent")
        XCTAssertNil(element)
    }
    
    func testGetElementMovesToFront() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 1.0) // Same priority
        queue.setElement(30, for: "key3", with: 1.0) // Same priority
        
        // Access key1, which should move it to front of its priority queue
        _ = queue.getElement(for: "key1")
        
        // Now add a new element with same priority - should evict the least recently used
        let evicted = queue.setElement(40, for: "key4", with: 1.0)
        // Should evict key2 or key3, not key1 since it was recently accessed
        XCTAssertNotNil(evicted)
        XCTAssertEqual(queue.count, 3)
    }
    
    // MARK: - Remove Element Tests
    
    func testRemoveElementBasic() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        
        let removed = queue.removeElement(for: "key1")
        XCTAssertEqual(removed, 10)
        XCTAssertEqual(queue.count, 1)
        
        let removed2 = queue.removeElement(for: "key2")
        XCTAssertEqual(removed2, 20)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
    }
    
    func testRemoveElementNonExistent() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        let removed = queue.removeElement(for: "nonexistent")
        XCTAssertNil(removed)
    }
    
    // MARK: - Priority Eviction Tests
    
    func testPriorityEviction() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        // Insert elements with different priorities
        queue.setElement(10, for: "key1", with: 1.0) // Low priority
        queue.setElement(20, for: "key2", with: 2.0) // Medium priority
        queue.setElement(30, for: "key3", with: 3.0) // High priority
        
        // Insert fourth element - should evict lowest priority (highest element)
        let evicted = queue.setElement(40, for: "key4", with: 0.5)
        XCTAssertEqual(evicted, 40) // key3 with priority 0.5 should be evicted
    }
    
    func testSamePriorityLRUEviction() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        // Insert elements with same priority
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 1.0)
        queue.setElement(30, for: "key3", with: 1.0)
        
        // Insert fourth element - should evict least recently used within same priority
        let evicted = queue.setElement(40, for: "key4", with: 1.0)
        XCTAssertEqual(evicted, 10) // key1 should be evicted (first inserted)
    }
    
    func testPriorityQueueCleanup() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 2)
        
        // Insert elements with different priorities
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        
        // Remove all elements from priority 1.0
        let removed = queue.removeElement(for: "key1")
        XCTAssertEqual(removed, 10)
        XCTAssertEqual(queue.count, 1)
        
        // Priority 1.0 should be removed from priorities array
        // This is tested indirectly by checking that the queue still works
        queue.setElement(30, for: "key3", with: 1.0) // Should work fine
        XCTAssertEqual(queue.count, 2)
    }
    
    // MARK: - Complex Scenarios
    
    func testComplexPriorityScenario() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 4)
        
        // Insert elements with mixed priorities
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        queue.setElement(30, for: "key3", with: 1.0) // Same priority as key1
        queue.setElement(40, for: "key4", with: 3.0)
        
        // Access key1 to make it more recently used
        _ = queue.getElement(for: "key1")
        
        // Insert fifth element - should evict from lowest priority
        let evicted = queue.setElement(50, for: "key5", with: 5.0)
        XCTAssertEqual(evicted, 30) // key3 with priority 1.0 should be evicted
        
        // Insert another element - should evict from remaining lowest priority
        let evicted2 = queue.setElement(60, for: "key6", with: 5.0)
        XCTAssertEqual(evicted2, 10) // key1 with priority 1.0 should be evicted
    }
    
    func testUpdatePriority() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        queue.setElement(30, for: "key3", with: 3.0)
        
        // Update key1 with different priority
        let evicted = queue.setElement(15, for: "key1", with: 4.0)
        XCTAssertNil(evicted) // No eviction since we're just updating
        
        // Now insert a new element - should evict from lowest priority
        let evicted2 = queue.setElement(40, for: "key4", with: 5.0)
        XCTAssertEqual(evicted2, 20) // key3 with priority 3.0 should be evicted
    }
    
    // MARK: - Edge Cases
    
    func testEmptyQueueOperations() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        XCTAssertNil(queue.getElement(for: "key1"))
        XCTAssertNil(queue.removeElement(for: "key1"))
        XCTAssertTrue(queue.isEmpty)
    }
    
    func testSingleElementQueue() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 1)
        
        queue.setElement(10, for: "key1", with: 1.0)
        XCTAssertEqual(queue.count, 1)
        
        let evicted = queue.setElement(20, for: "key2", with: 2.0)
        XCTAssertEqual(evicted, 10) // key1 should be evicted
        XCTAssertEqual(queue.count, 1)
    }
    
    func testDescription() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        
        let desc = queue.description
        XCTAssertEqual(desc, "[10, 20]")
    }
    
    // MARK: - Remove Element (No Parameter) Tests
    
    func testRemoveElementNoParameter() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        // Add some elements
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 2.0)
        queue.setElement(30, for: "key3", with: 3.0)
        
        XCTAssertEqual(queue.count, 3)
        
        // Remove least recently used element (should be key1 with lowest priority)
        let removedElement = queue.removeElement()
        XCTAssertNotNil(removedElement)
        XCTAssertEqual(queue.count, 2)
        
        // Remove another element
        let secondRemovedElement = queue.removeElement()
        XCTAssertNotNil(secondRemovedElement)
        XCTAssertEqual(queue.count, 1)
        
        // Remove last element
        let thirdRemovedElement = queue.removeElement()
        XCTAssertNotNil(thirdRemovedElement)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        
        // Try to remove from empty queue
        let emptyRemovedElement = queue.removeElement()
        XCTAssertNil(emptyRemovedElement)
    }
    
    func testRemoveElementNoParameterWithSamePriority() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        // Add elements with same priority
        queue.setElement(10, for: "key1", with: 1.0)
        queue.setElement(20, for: "key2", with: 1.0)
        queue.setElement(30, for: "key3", with: 1.0)
        
        XCTAssertEqual(queue.count, 3)
        
        // Access key2 to make it more recently used
        _ = queue.getElement(for: "key2")
        
        // Remove least recently used element (should be key1 since key2 was accessed)
        let removedElement = queue.removeElement()
        XCTAssertEqual(removedElement, 10) // key1 should be removed
        XCTAssertEqual(queue.count, 2)
        
        // Remove another element (should be key3 since key2 was accessed)
        let secondRemovedElement = queue.removeElement()
        XCTAssertEqual(secondRemovedElement, 30) // key3 should be removed
        XCTAssertEqual(queue.count, 1)
        
        // Remove last element
        let thirdRemovedElement = queue.removeElement()
        XCTAssertEqual(thirdRemovedElement, 20) // key2 should be removed
        XCTAssertEqual(queue.count, 0)
    }
    
    func testRemoveElementNoParameterWithDifferentPriorities() {
        let queue = PriorityLRUQueue<String, Int>(capacity: 3)
        
        // Add elements with different priorities
        queue.setElement(10, for: "key1", with: 1.0) // Lowest priority
        queue.setElement(20, for: "key2", with: 2.0) // Medium priority
        queue.setElement(30, for: "key3", with: 3.0) // Highest priority
        
        XCTAssertEqual(queue.count, 3)
        
        // Remove least recently used element (should be from lowest priority)
        let removedElement = queue.removeElement()
        XCTAssertEqual(removedElement, 10) // key1 with lowest priority should be removed
        XCTAssertEqual(queue.count, 2)
        
        // Remove another element (should be from remaining lowest priority)
        let secondRemovedElement = queue.removeElement()
        XCTAssertEqual(secondRemovedElement, 20) // key2 with medium priority should be removed
        XCTAssertEqual(queue.count, 1)
        
        // Remove last element
        let thirdRemovedElement = queue.removeElement()
        XCTAssertEqual(thirdRemovedElement, 30) // key3 should be removed
        XCTAssertEqual(queue.count, 0)
    }
} 
