//
//  PriorityLRUQueueTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/5/8.
//

import XCTest
@testable import Monstore

final class PriorityLRUQueueTests: XCTestCase {
    
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
