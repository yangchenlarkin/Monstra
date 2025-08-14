//
//  KeyQueueTests.swift
//  MonstaskTests
//
//  Created by Larkin on 2025/7/22.
//

import XCTest
@testable import Monstask

final class KeyQueueTests: XCTestCase {

    // MARK: - Basic Operations Tests

    func testInitialization() {
        let queue = KeyQueue<String>(capacity: 10)
        XCTAssertEqual(queue.capacity, 10)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertFalse(queue.isFull)
    }

    func testInitializationWithZeroCapacity() {
        let queue = KeyQueue<String>(capacity: 0)
        XCTAssertEqual(queue.capacity, 0)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertTrue(queue.isFull)
    }

    func testInitializationWithNegativeCapacity() {
        let queue = KeyQueue<String>(capacity: -5)
        XCTAssertEqual(queue.capacity, 0)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertTrue(queue.isFull)
    }

    // MARK: - LRU Behavior Tests

    func testLRUBehavior() {
        let queue = KeyQueue<String>(capacity: 5)
        
        // Add keys
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Re-insert "A" - should move to front
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        
        // Dequeue from front should return "A" (most recently used)
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertNil(queue.dequeueFront())
    }

    func testLRUBehaviorWithMultipleReinserts() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Re-insert in reverse order
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        
        // Should return in reverse order of re-insertion
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertEqual(queue.dequeueFront(), "C")
    }

    // MARK: - Queue Operations Tests

    func testEnqueueFront() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.count, 1)
        XCTAssertFalse(queue.isEmpty)
        
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.count, 2)
        
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.count, 3)
        XCTAssertTrue(queue.isFull)
    }

    func testDequeueFront() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Empty queue
        XCTAssertNil(queue.dequeueFront())
        
        // Single element
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertTrue(queue.isEmpty)
        
        // Multiple elements
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertNil(queue.dequeueFront())
    }

    func testDequeueFrontWithCount() {
        let queue = KeyQueue<String>(capacity: 5)
        
        // Empty queue
        XCTAssertEqual(queue.dequeueFront(count: 3), [])
        
        // Single element
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.dequeueFront(count: 1), ["A"])
        XCTAssertTrue(queue.isEmpty)
        
        // Multiple elements - request less than available
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(count: 2), ["C", "B"])
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.dequeueFront(), "A")
        
        // Multiple elements - request more than available
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(count: 5), ["C", "B", "A"])
        XCTAssertTrue(queue.isEmpty)
    }

    func testDequeueFrontWithCountZero() {
        let queue = KeyQueue<String>(capacity: 3)
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(count: 0), [])
        XCTAssertEqual(queue.count, 2)
    }

    func testDequeueFrontWithCountLarge() {
        let queue = KeyQueue<String>(capacity: 3)
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Request more than available
        let result = queue.dequeueFront(count: 10)
        XCTAssertEqual(result, ["C", "B", "A"])
        XCTAssertTrue(queue.isEmpty)
    }

    func testDequeueBack() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Empty queue
        XCTAssertNil(queue.dequeueBack())
        
        // Single element
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.dequeueBack(), "A")
        XCTAssertTrue(queue.isEmpty)
        
        // Multiple elements
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueBack(), "A")
        XCTAssertEqual(queue.dequeueBack(), "B")
        XCTAssertEqual(queue.dequeueBack(), "C")
        XCTAssertNil(queue.dequeueBack())
    }

    func testDequeueBackWithCount() {
        let queue = KeyQueue<String>(capacity: 5)
        
        // Empty queue
        XCTAssertEqual(queue.dequeueBack(count: 3), [])
        
        // Single element
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.dequeueBack(count: 1), ["A"])
        XCTAssertTrue(queue.isEmpty)
        
        // Multiple elements - request less than available
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueBack(count: 2), ["A", "B"])
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.dequeueBack(), "C")
        
        // Multiple elements - request more than available
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueBack(count: 5), ["A", "B", "C"])
        XCTAssertTrue(queue.isEmpty)
    }

    func testDequeueBackWithCountZero() {
        let queue = KeyQueue<String>(capacity: 3)
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueBack(count: 0), [])
        XCTAssertEqual(queue.count, 2)
    }

    func testDequeueBackWithCountLarge() {
        let queue = KeyQueue<String>(capacity: 3)
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Request more than available
        let result = queue.dequeueBack(count: 10)
        XCTAssertEqual(result, ["A", "B", "C"])
        XCTAssertTrue(queue.isEmpty)
    }

    func testMixedDequeueOperations() {
        let queue = KeyQueue<String>(capacity: 5)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "E", evictedStrategy: .FIFO)
        
        // Dequeue from front then back
        XCTAssertEqual(queue.dequeueFront(), "E")
        XCTAssertEqual(queue.dequeueBack(), "A")
        XCTAssertEqual(queue.dequeueFront(), "D")
        XCTAssertEqual(queue.dequeueBack(), "B")
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertNil(queue.dequeueFront())
    }

    func testMixedDequeueWithCount() {
        let queue = KeyQueue<String>(capacity: 6)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "E", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "F", evictedStrategy: .FIFO)
        
        // Dequeue multiple from front
        XCTAssertEqual(queue.dequeueFront(count: 2), ["F", "E"])
        XCTAssertEqual(queue.count, 4)
        
        // Dequeue multiple from back
        XCTAssertEqual(queue.dequeueBack(count: 2), ["A", "B"])
        XCTAssertEqual(queue.count, 2)
        
        // Dequeue remaining
        XCTAssertEqual(queue.dequeueFront(count: 3), ["D", "C"])
        XCTAssertTrue(queue.isEmpty)
    }

    func testDequeueWithCountAfterLRU() {
        let queue = KeyQueue<String>(capacity: 4)
        
        // Initial state: [A, B, C, D]
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        
        // Access "B" to make it most recently used: [B, D, C, A]
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        // Dequeue 2 from front
        XCTAssertEqual(queue.dequeueFront(count: 2), ["B", "D"])
        XCTAssertEqual(queue.count, 2)
        
        // Dequeue 2 from back
        XCTAssertEqual(queue.dequeueBack(count: 2), ["A", "C"])
        XCTAssertTrue(queue.isEmpty)
    }

    func testDequeueWithCountPerformance() {
        let queue = KeyQueue<Int>(capacity: 1000)
        
        // Fill the queue
        for i in 1...1000 {
            queue.enqueueFront(key: i, evictedStrategy: .FIFO)
        }
        
        // Dequeue in batches
        let batch1 = queue.dequeueFront(count: 100)
        XCTAssertEqual(batch1.count, 100)
        XCTAssertEqual(batch1.first, 1000)
        XCTAssertEqual(batch1.last, 901)
        
        let batch2 = queue.dequeueBack(count: 100)
        XCTAssertEqual(batch2.count, 100)
        XCTAssertEqual(batch2.first, 1)
        XCTAssertEqual(batch2.last, 100)
        
        XCTAssertEqual(queue.count, 800)
    }

    func testDequeueWithCountEdgeCases() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Test with UInt.max
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        let result = queue.dequeueFront(count: UInt.max)
        XCTAssertEqual(result, ["C", "B", "A"])
        XCTAssertTrue(queue.isEmpty)
        
        // Test with zero count multiple times
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(count: 0), [])
        XCTAssertEqual(queue.dequeueBack(count: 0), [])
        XCTAssertEqual(queue.count, 2)
    }

    func testDequeueWithCountConsistency() {
        let queue = KeyQueue<String>(capacity: 5)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "E", evictedStrategy: .FIFO)
        
        // Dequeue 3 from front, then 2 from back
        let frontResult = queue.dequeueFront(count: 3)
        let backResult = queue.dequeueBack(count: 2)
        
        XCTAssertEqual(frontResult, ["E", "D", "C"])
        XCTAssertEqual(backResult, ["A", "B"])
        XCTAssertTrue(queue.isEmpty)
        
        // Verify consistency with individual dequeue operations
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        let individualResults = [
            queue.dequeueFront(),
            queue.dequeueFront(),
            queue.dequeueFront()
        ].compactMap { $0 }
        
        // Re-add elements for batch test
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        let batchResult = queue.dequeueFront(count: 3)
        XCTAssertEqual(individualResults, batchResult)
    }

    // MARK: - Removal Operations Tests

    func testRemoveExistingKey() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        queue.remove(key: "B")
        XCTAssertEqual(queue.count, 2)
        
        // Should return remaining keys in correct order
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertNil(queue.dequeueFront())
    }

    func testRemoveNonExistentKey() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        queue.remove(key: "C") // Non-existent key
        XCTAssertEqual(queue.count, 2) // Count should remain unchanged
        
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertEqual(queue.dequeueFront(), "A")
    }

    func testRemoveFromEmptyQueue() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.remove(key: "A")
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
    }

    func testRemoveAllKeys() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        queue.remove(key: "A")
        queue.remove(key: "B")
        queue.remove(key: "C")
        
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertNil(queue.dequeueFront())
    }

    // MARK: - Edge Cases Tests

    func testEmptyQueueOperations() {
        let queue = KeyQueue<String>(capacity: 3)
        
        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(queue.count, 0)
        XCTAssertFalse(queue.isFull)
        XCTAssertNil(queue.dequeueFront())
        XCTAssertNil(queue.dequeueBack())
    }

    func testFullQueueOperations() {
        let queue = KeyQueue<String>(capacity: 2)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        XCTAssertTrue(queue.isFull)
        XCTAssertEqual(queue.count, 2)
        XCTAssertFalse(queue.isEmpty)
        
        // Adding another key should evict the least recently used
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.count, 2)
        XCTAssertTrue(queue.isFull)
        
        // Should return "C" and "B", "A" should be evicted
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertNil(queue.dequeueFront())
    }

    func testSingleElementQueue() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.count, 1)
        XCTAssertFalse(queue.isEmpty)
        XCTAssertFalse(queue.isFull)
        
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertTrue(queue.isEmpty)
        XCTAssertNil(queue.dequeueFront())
    }

    // MARK: - Capacity Management Tests

    func testCapacityEviction() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Fill the queue
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Add one more - should evict "A" (least recently used)
        queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.count, 3)
        XCTAssertTrue(queue.isFull)
        
        // Should return "D", "C", "B" in order
        XCTAssertEqual(queue.dequeueFront(), "D")
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertNil(queue.dequeueFront())
    }

    func testCapacityEvictionWithLRU() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Access "A" to make it most recently used
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        
        // Add "D" - should evict "B" (now least recently used)
        queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(), "D")
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertNil(queue.dequeueFront())
    }

    func testZeroCapacityQueue() {
        let queue = KeyQueue<String>(capacity: 0)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertTrue(queue.isFull)
        
        XCTAssertNil(queue.dequeueFront())
        XCTAssertNil(queue.dequeueBack())
    }

    // MARK: - Performance Tests

    func testLargeCapacityOperations() {
        let capacity = 1000
        let queue = KeyQueue<Int>(capacity: capacity)
        
        // Fill the queue
        for i in 1...capacity {
            queue.enqueueFront(key: i, evictedStrategy: .FIFO)
        }
        
        XCTAssertEqual(queue.count, capacity)
        XCTAssertTrue(queue.isFull)
        
        // Dequeue all elements
        for i in (1...capacity).reversed() {
            XCTAssertEqual(queue.dequeueFront(), i)
        }
        
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
    }

    func testRepeatedOperations() {
        let queue = KeyQueue<String>(capacity: 5)
        
        // Perform many operations
        for i in 1...100 {
            queue.enqueueFront(key: "key\(i % 5)", evictedStrategy: .FIFO)
        }
        
        XCTAssertEqual(queue.count, 5)
        XCTAssertTrue(queue.isFull)
        
        // Should contain the last 5 keys used
        let expectedKeys = ["key0", "key1", "key2", "key3", "key4"]
        for expectedKey in expectedKeys {
            XCTAssertNotNil(queue.remove(key: expectedKey))
        }
        
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: - Type Safety Tests

    func testStringKeys() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "hello", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "world", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(), "world")
        XCTAssertEqual(queue.dequeueFront(), "hello")
    }

    func testIntKeys() {
        let queue = KeyQueue<Int>(capacity: 3)
        
        queue.enqueueFront(key: 1, evictedStrategy: .FIFO)
        queue.enqueueFront(key: 2, evictedStrategy: .FIFO)
        queue.enqueueFront(key: 3, evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(), 3)
        XCTAssertEqual(queue.dequeueFront(), 2)
        XCTAssertEqual(queue.dequeueFront(), 1)
    }

    func testCustomHashableKeys() {
        struct TestKey: Hashable {
            let id: Int
            let name: String
        }
        
        let queue = KeyQueue<TestKey>(capacity: 3)
        
        let key1 = TestKey(id: 1, name: "A")
        let key2 = TestKey(id: 2, name: "B")
        
        queue.enqueueFront(key: key1, evictedStrategy: .FIFO)
        queue.enqueueFront(key: key2, evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(), key2)
        XCTAssertEqual(queue.dequeueFront(), key1)
    }

    // MARK: - Memory Management Tests

    func testNodeCleanup() {
        let queue = KeyQueue<String>(capacity: 2)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        // Remove and re-add to test node cleanup
        queue.remove(key: "A")
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertEqual(queue.dequeueFront(), "B")
    }

    func testMapConsistency() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        // Remove and verify map consistency
        queue.remove(key: "A")
        
        // Try to remove again - should have no effect
        queue.remove(key: "A")
        XCTAssertEqual(queue.count, 1)
        
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: - Complex Scenarios Tests

    func testComplexLRUScenario() {
        let queue = KeyQueue<String>(capacity: 4)
        
        // Initial state: [A, B, C, D]
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        
        // Access "B" to make it most recently used: [B, D, C, A]
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        // Access "A" to make it most recently used: [A, B, D, C]
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        
        // Add "E" - should evict "C": [E, A, B, D]
        queue.enqueueFront(key: "E", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(), "E")
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertEqual(queue.dequeueFront(), "D")
        XCTAssertNil(queue.dequeueFront())
    }

    func testRemoveAndReinsert() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Remove "B" and re-insert
        queue.remove(key: "B")
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        XCTAssertEqual(queue.dequeueFront(), "B")
        XCTAssertEqual(queue.dequeueFront(), "C")
        XCTAssertEqual(queue.dequeueFront(), "A")
        XCTAssertNil(queue.dequeueFront())
    }

    func testStressTest() {
        let queue = KeyQueue<Int>(capacity: 10)
        
        // Perform many random operations
        for i in 1...1000 {
            let operation = i % 4
            
            switch operation {
            case 0:
                queue.enqueueFront(key: i % 20, evictedStrategy: .FIFO)
            case 1:
                _ = queue.dequeueFront()
            case 2:
                _ = queue.dequeueBack()
            case 3:
                queue.remove(key: i % 20)
            default:
                break
            }
        }
        
        // Queue should still be in a valid state
        XCTAssertLessThanOrEqual(queue.count, queue.capacity)
        XCTAssertGreaterThanOrEqual(queue.count, 0)
    }
    
    // MARK: - Eviction and Contains Consistency Tests
    
    func testContainsAfterEvictionFIFO() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Fill the queue
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Verify all keys are present
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "C"))
        
        // Add new key with FIFO eviction - should evict "A" (oldest)
        let evictedKey = queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        
        // Verify evicted key is returned and no longer contained
        XCTAssertEqual(evictedKey, "A")
        XCTAssertFalse(queue.contains(key: "A"), "Evicted key 'A' should not be contained in queue")
        
        // Verify remaining keys are still present
        XCTAssertTrue(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "C"))
        XCTAssertTrue(queue.contains(key: "D"))
        
        // Verify count is correct
        XCTAssertEqual(queue.count, 3)
    }
    
    func testContainsAfterEvictionLIFO() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Fill the queue
        queue.enqueueFront(key: "A", evictedStrategy: .LIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .LIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .LIFO)
        
        // Verify all keys are present
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "C"))
        
        // Add new key with LIFO eviction - should evict "C" (newest/front)
        let evictedKey = queue.enqueueFront(key: "D", evictedStrategy: .LIFO)
        
        // Verify evicted key is returned and no longer contained
        XCTAssertEqual(evictedKey, "D")
        XCTAssertFalse(queue.contains(key: "D"), "Evicted key 'D' should not be contained in queue")
        
        // Verify remaining keys are still present
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "C"))
        
        // Verify count is correct
        XCTAssertEqual(queue.count, 3)
    }
    
    func testContainsAfterMultipleEvictions() {
        let queue = KeyQueue<String>(capacity: 2)
        
        // Initial state: [A, B]
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "B"))
        
        // Add C, evict A: [C, B]
        let evicted1 = queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        XCTAssertEqual(evicted1, "A")
        XCTAssertFalse(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "C"))
        
        // Add D, evict B: [D, C]
        let evicted2 = queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        XCTAssertEqual(evicted2, "B")
        XCTAssertFalse(queue.contains(key: "A"))
        XCTAssertFalse(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "C"))
        XCTAssertTrue(queue.contains(key: "D"))
        
        // Add E, evict C: [E, D]
        let evicted3 = queue.enqueueFront(key: "E", evictedStrategy: .FIFO)
        XCTAssertEqual(evicted3, "C")
        XCTAssertFalse(queue.contains(key: "A"))
        XCTAssertFalse(queue.contains(key: "B"))
        XCTAssertFalse(queue.contains(key: "C"))
        XCTAssertTrue(queue.contains(key: "D"))
        XCTAssertTrue(queue.contains(key: "E"))
    }
    
    func testContainsAfterEvictionWithLRUAccess() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Fill the queue: [A, B, C]
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Access "A" to make it most recently used: [A, C, B]
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        
        // Verify all keys still present
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "C"))
        
        // Add "D" with FIFO eviction - should evict "B" (now oldest): [D, A, C]
        let evictedKey = queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        XCTAssertEqual(evictedKey, "B")
        
        // Verify evicted key is no longer contained
        XCTAssertFalse(queue.contains(key: "B"), "Evicted key 'B' should not be contained in queue")
        
        // Verify remaining keys are still present
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "C"))
        XCTAssertTrue(queue.contains(key: "D"))
    }
    
    func testContainsConsistencyAfterMixedOperations() {
        let queue = KeyQueue<String>(capacity: 3)
        
        // Add initial keys
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Manual removal
        queue.remove(key: "B")
        XCTAssertFalse(queue.contains(key: "B"))
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "C"))
        
        // Add new key (no eviction since we have space)
        let noEviction = queue.enqueueFront(key: "D", evictedStrategy: .FIFO)
        XCTAssertNil(noEviction)
        XCTAssertTrue(queue.contains(key: "D"))
        
        // Fill to capacity again
        let evictedKey1 = queue.enqueueFront(key: "E", evictedStrategy: .FIFO)
        XCTAssertTrue(queue.contains(key: "E"))
        
        // Now eviction should occur
        let evictedKey2 = queue.enqueueFront(key: "F", evictedStrategy: .FIFO)
        XCTAssertEqual(evictedKey1, "A") // A should be evicted (oldest)
        XCTAssertEqual(evictedKey2, "C") // C should be evicted (oldest)
        XCTAssertFalse(queue.contains(key: "A"))
        XCTAssertFalse(queue.contains(key: "C"))
        XCTAssertTrue(queue.contains(key: "F"))
    }
    
    func testContainsAfterDequeue() {
        let queue = KeyQueue<String>(capacity: 3)
        
        queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "B", evictedStrategy: .FIFO)
        queue.enqueueFront(key: "C", evictedStrategy: .FIFO)
        
        // Dequeue from front
        let frontKey = queue.dequeueFront()
        XCTAssertEqual(frontKey, "C")
        XCTAssertFalse(queue.contains(key: "C"))
        XCTAssertTrue(queue.contains(key: "A"))
        XCTAssertTrue(queue.contains(key: "B"))
        
        // Dequeue from back
        let backKey = queue.dequeueBack()
        XCTAssertEqual(backKey, "A")
        XCTAssertFalse(queue.contains(key: "A"))
        XCTAssertFalse(queue.contains(key: "C"))
        XCTAssertTrue(queue.contains(key: "B"))
        
        // Final dequeue
        let lastKey = queue.dequeueFront()
        XCTAssertEqual(lastKey, "B")
        XCTAssertFalse(queue.contains(key: "A"))
        XCTAssertFalse(queue.contains(key: "B"))
        XCTAssertFalse(queue.contains(key: "C"))
        XCTAssertTrue(queue.isEmpty)
    }
    
    func testContainsWithZeroCapacityQueue() {
        let queue = KeyQueue<String>(capacity: 0)
        
        // All enqueue operations should immediately evict
        let evicted1 = queue.enqueueFront(key: "A", evictedStrategy: .FIFO)
        XCTAssertEqual(evicted1, "A")
        XCTAssertFalse(queue.contains(key: "A"))
        
        let evicted2 = queue.enqueueFront(key: "B", evictedStrategy: .LIFO)
        XCTAssertEqual(evicted2, "B")
        XCTAssertFalse(queue.contains(key: "B"))
        
        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(queue.count, 0)
    }
    
    func testContainsEvictionStressTest() {
        let queue = KeyQueue<Int>(capacity: 5)
        var expectedKeys = Set<Int>()
        
        // Perform many operations and track expected state
        for i in 1...100 {
            let key = i % 20 // Use keys 0-19 to create collisions
            
            if i % 3 == 0 {
                // Remove operation
                queue.remove(key: key)
                expectedKeys.remove(key)
            } else {
                // Enqueue operation
                let evictedKey = queue.enqueueFront(key: key, evictedStrategy: .FIFO)
                expectedKeys.insert(key)
                
                if let evicted = evictedKey {
                    expectedKeys.remove(evicted)
                }
                
                // Ensure we don't exceed capacity
                while expectedKeys.count > queue.capacity {
                    // This shouldn't happen with correct implementation
                    XCTFail("Expected keys exceeded capacity")
                    break
                }
            }
            
            // Verify contains consistency
            for testKey in 0..<20 {
                let shouldContain = expectedKeys.contains(testKey)
                let actuallyContains = queue.contains(key: testKey)
                XCTAssertEqual(shouldContain, actuallyContains, 
                              "Key \(testKey) contains mismatch at iteration \(i): expected \(shouldContain), got \(actuallyContains)")
            }
        }
    }
}
