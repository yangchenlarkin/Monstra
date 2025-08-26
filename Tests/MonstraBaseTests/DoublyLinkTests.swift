//
//  DoublyLinkTests.swift
//  MonstraTests
//
//  Created by Larkin on 2025/7/21.
//

import XCTest
@testable import Monstra

final class DoublyLinkTests: XCTestCase {
    
    // MARK: - Basic Operations Tests
    
    func testEnqueueElement() {
        let link = DoublyLink<Int>(with: 3)
        
        let result = link.enqueueFront(element: 1)
        XCTAssertNotNil(result.newNode)
        XCTAssertNil(result.evictedNode)
        XCTAssertEqual(link.count, 1)
        XCTAssertEqual(link.front?.element, 1)
        XCTAssertEqual(link.back?.element, 1)
    }
    
    func testEnqueueMultipleElements() {
        let link = DoublyLink<Int>(with: 3)
        
        let result1 = link.enqueueFront(element: 1)
        let result2 = link.enqueueFront(element: 2)
        let result3 = link.enqueueFront(element: 3)
        
        XCTAssertEqual(link.count, 3)
        XCTAssertEqual(link.front?.element, 3) // Most recent at front
        XCTAssertEqual(link.back?.element, 1)  // Least recent at back
        XCTAssertNil(result1.evictedNode)
        XCTAssertNil(result2.evictedNode)
        XCTAssertNil(result3.evictedNode)
    }
    
    func testEnqueueNode() {
        let link = DoublyLink<Int>(with: 3)
        let node = DoublyLink<Int>.Node(element: 1)
        
        let evicted = link.enqueueFront(node: node)
        XCTAssertNil(evicted)
        XCTAssertEqual(link.count, 1)
        XCTAssertEqual(link.front?.element, 1)
        XCTAssertEqual(link.back?.element, 1)
    }
    
    func testDequeueBack() {
        let link = DoublyLink<Int>(with: 3)
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        link.enqueueFront(element: 3)
        
        let removed = link.dequeueBack()
        XCTAssertEqual(removed?.element, 1) // Least recent
        XCTAssertEqual(link.count, 2)
        XCTAssertEqual(link.front?.element, 3)
        XCTAssertEqual(link.back?.element, 2)
    }
    
    func testDequeueFront() {
        let link = DoublyLink<Int>(with: 3)
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        link.enqueueFront(element: 3)
        
        let removed = link.dequeueFront()
        XCTAssertEqual(removed?.element, 3) // Most recent
        XCTAssertEqual(link.count, 2)
        XCTAssertEqual(link.front?.element, 2)
        XCTAssertEqual(link.back?.element, 1)
    }
    
    func testRemoveNode() {
        let link = DoublyLink<Int>(with: 3)
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        link.enqueueFront(element: 3)
        
        let middleNode = link.front?.next
        XCTAssertNotNil(middleNode)
        XCTAssertEqual(middleNode?.element, 2)
        
        link.removeNode(middleNode!)
        XCTAssertEqual(link.count, 2)
        XCTAssertEqual(link.front?.element, 3)
        XCTAssertEqual(link.back?.element, 1)
    }
    
    // MARK: - Capacity Management Tests
    
    func testCapacityExceeded() {
        let link = DoublyLink<Int>(with: 2)
        
        let result1 = link.enqueueFront(element: 1)
        let result2 = link.enqueueFront(element: 2)
        let result3 = link.enqueueFront(element: 3)
        
        XCTAssertEqual(link.count, 2)
        XCTAssertEqual(link.front?.element, 3)
        XCTAssertEqual(link.back?.element, 2)
        XCTAssertNil(result1.evictedNode)
        XCTAssertNil(result2.evictedNode)
        XCTAssertNotNil(result3.evictedNode)
        XCTAssertEqual(result3.evictedNode?.element, 1)
    }
    
    func testZeroCapacity() {
        let link = DoublyLink<Int>(with: 0)
        
        let result = link.enqueueFront(element: 1)
        XCTAssertNil(result.newNode)
        XCTAssertNotNil(result.evictedNode)
        XCTAssertEqual(result.evictedNode?.element, 1)
        XCTAssertEqual(link.count, 0)
    }
    
    func testNegativeCapacity() {
        let link = DoublyLink<Int>(with: -1)
        
        let result = link.enqueueFront(element: 1)
        XCTAssertNil(result.newNode)
        XCTAssertNotNil(result.evictedNode)
        XCTAssertEqual(result.evictedNode?.element, 1)
        XCTAssertEqual(link.count, 0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyQueueOperations() {
        let link = DoublyLink<Int>(with: 3)
        
        XCTAssertEqual(link.count, 0)
        XCTAssertNil(link.front)
        XCTAssertNil(link.back)
        
        let removedBack = link.dequeueBack()
        XCTAssertNil(removedBack)
        
        let removedFront = link.dequeueFront()
        XCTAssertNil(removedFront)
    }
    
    func testSingleElementOperations() {
        let link = DoublyLink<Int>(with: 3)
        link.enqueueFront(element: 1)
        
        XCTAssertEqual(link.count, 1)
        XCTAssertEqual(link.front?.element, 1)
        XCTAssertEqual(link.back?.element, 1)
        XCTAssertTrue(link.front === link.back)
        
        let removedBack = link.dequeueBack()
        XCTAssertEqual(removedBack?.element, 1)
        XCTAssertEqual(link.count, 0)
        XCTAssertNil(link.front)
        XCTAssertNil(link.back)
    }
    
    func testRemoveFrontNode() {
        let link = DoublyLink<Int>(with: 3)
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        
        let frontNode = link.front
        link.removeNode(frontNode!)
        
        XCTAssertEqual(link.count, 1)
        XCTAssertEqual(link.front?.element, 1)
        XCTAssertEqual(link.back?.element, 1)
    }
    
    func testRemoveBackNode() {
        let link = DoublyLink<Int>(with: 3)
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        
        let backNode = link.back
        link.removeNode(backNode!)
        
        XCTAssertEqual(link.count, 1)
        XCTAssertEqual(link.front?.element, 2)
        XCTAssertEqual(link.back?.element, 2)
    }
    
    func testRemoveMiddleNode() {
        let link = DoublyLink<Int>(with: 3)
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        link.enqueueFront(element: 3)
        
        let middleNode = link.front?.next
        link.removeNode(middleNode!)
        
        XCTAssertEqual(link.count, 2)
        XCTAssertEqual(link.front?.element, 3)
        XCTAssertEqual(link.back?.element, 1)
        XCTAssertEqual(link.front?.next?.element, 1)
        XCTAssertEqual(link.back?.previous?.element, 3)
    }
    
    // MARK: - Node Properties Tests
    
    func testNodeProperties() {
        let node1 = DoublyLink<Int>.Node(element: 1)
        let node2 = DoublyLink<Int>.Node(element: 2)
        let node3 = DoublyLink<Int>.Node(element: 3)
        
        // Test initial state
        XCTAssertEqual(node1.element, 1)
        XCTAssertNil(node1.next)
        XCTAssertNil(node1.previous)
        
        // Test linking
        node1.next = node2
        node2.previous = node1
        node2.next = node3
        node3.previous = node2
        
        XCTAssertEqual(node1.next?.element, 2)
        XCTAssertEqual(node2.previous?.element, 1)
        XCTAssertEqual(node2.next?.element, 3)
        XCTAssertEqual(node3.previous?.element, 2)
    }
    
    func testNodeInitialization() {
        let node1 = DoublyLink<Int>.Node(element: 1)
        let node2 = DoublyLink<Int>.Node(element: 2, next: node1, previous: nil)
        let node3 = DoublyLink<Int>.Node(element: 3, next: nil, previous: node2)
        
        XCTAssertEqual(node1.element, 1)
        XCTAssertEqual(node2.element, 2)
        XCTAssertEqual(node3.element, 3)
        
        XCTAssertEqual(node2.next?.element, 1)
        XCTAssertEqual(node3.previous?.element, 2)
    }
    
    // MARK: - Complex Operations Tests
    
    func testMultipleEnqueueDequeueOperations() {
        let link = DoublyLink<Int>(with: 3)
        
        // Enqueue 3 elements
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        link.enqueueFront(element: 3)
        
        XCTAssertEqual(link.count, 3)
        XCTAssertEqual(link.front?.element, 3)
        XCTAssertEqual(link.back?.element, 1)
        
        // Dequeue back
        let removed1 = link.dequeueBack()
        XCTAssertEqual(removed1?.element, 1)
        XCTAssertEqual(link.count, 2)
        
        // Enqueue new element
        link.enqueueFront(element: 4)
        XCTAssertEqual(link.count, 3)
        XCTAssertEqual(link.front?.element, 4)
        XCTAssertEqual(link.back?.element, 2)
        
        // Dequeue front
        let removed2 = link.dequeueFront()
        XCTAssertEqual(removed2?.element, 4)
        XCTAssertEqual(link.count, 2)
        XCTAssertEqual(link.front?.element, 3)
        XCTAssertEqual(link.back?.element, 2)
    }
    
    func testRemoveAndReinsertNode() {
        let link = DoublyLink<Int>(with: 3)
        
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        link.enqueueFront(element: 3)
        
        let middleNode = link.front?.next
        link.removeNode(middleNode!)
        
        // Reinsert the removed node
        let evicted = link.enqueueFront(node: middleNode!)
        XCTAssertNil(evicted)
        XCTAssertEqual(link.count, 3)
        XCTAssertEqual(link.front?.element, 2)
        XCTAssertEqual(link.back?.element, 1)
    }
    
    // MARK: - Large Capacity Tests
    
    func testLargeCapacity() {
        let link = DoublyLink<Int>(with: 1000)
        
        // Enqueue many elements
        for i in 1...500 {
            let result = link.enqueueFront(element: i)
            XCTAssertNotNil(result.newNode)
            XCTAssertNil(result.evictedNode)
        }
        
        XCTAssertEqual(link.count, 500)
        XCTAssertEqual(link.front?.element, 500)
        XCTAssertEqual(link.back?.element, 1)
        
        // Enqueue more to trigger eviction
        for i in 501...1000 {
            let result = link.enqueueFront(element: i)
            XCTAssertNotNil(result.newNode)
            // After capacity is reached, eviction should occur
            XCTAssertNil(result.evictedNode)
        }
        
        XCTAssertEqual(link.count, 1000)
        XCTAssertEqual(link.front?.element, 1000)
        XCTAssertEqual(link.back?.element, 1)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceEnqueue() {
        let link = DoublyLink<Int>(with: 1000)
        
        measure {
            for i in 1...1000 {
                link.enqueueFront(element: i)
            }
        }
    }
    
    func testPerformanceDequeueBack() {
        let link = DoublyLink<Int>(with: 1000)
        
        // Pre-populate
        for i in 1...1000 {
            link.enqueueFront(element: i)
        }
        
        measure {
            for _ in 1...1000 {
                _ = link.dequeueBack()
            }
        }
    }
    
    func testPerformanceRemoveNode() {
        let link = DoublyLink<Int>(with: 1000)
        
        // Pre-populate
        for i in 1...1000 {
            link.enqueueFront(element: i)
        }
        
        measure {
            var node = link.front
            while let currentNode = node {
                let nextNode = currentNode.next
                link.removeNode(currentNode)
                node = nextNode
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testNodeReferences() {
        let link = DoublyLink<Int>(with: 3)
        
        link.enqueueFront(element: 1)
        link.enqueueFront(element: 2)
        link.enqueueFront(element: 3)
        
        let frontNode = link.front
        let backNode = link.back
        let middleNode = frontNode?.next
        
        // Verify references
        XCTAssertTrue(frontNode === link.front)
        XCTAssertTrue(backNode === link.back)
        XCTAssertTrue(middleNode === frontNode?.next)
        XCTAssertTrue(middleNode === backNode?.previous)
        
        // Remove middle node
        link.removeNode(middleNode!)
        
        // Verify references are updated
        XCTAssertTrue(frontNode === link.front)
        XCTAssertTrue(backNode === link.back)
        XCTAssertNil(middleNode?.next)
        XCTAssertNil(middleNode?.previous)
    }
    
    // MARK: - Generic Type Tests
    
    func testStringElements() {
        let link = DoublyLink<String>(with: 3)
        
        link.enqueueFront(element: "first")
        link.enqueueFront(element: "second")
        link.enqueueFront(element: "third")
        
        XCTAssertEqual(link.count, 3)
        XCTAssertEqual(link.front?.element, "third")
        XCTAssertEqual(link.back?.element, "first")
    }
    
    func testCustomStructElements() {
        struct TestStruct {
            let id: Int
            let name: String
        }
        
        let link = DoublyLink<TestStruct>(with: 3)
        
        let element1 = TestStruct(id: 1, name: "one")
        let element2 = TestStruct(id: 2, name: "two")
        let element3 = TestStruct(id: 3, name: "three")
        
        link.enqueueFront(element: element1)
        link.enqueueFront(element: element2)
        link.enqueueFront(element: element3)
        
        XCTAssertEqual(link.count, 3)
        XCTAssertEqual(link.front?.element.id, 3)
        XCTAssertEqual(link.back?.element.id, 1)
    }
    
    // MARK: - Error Handling Tests
    
    func testRemoveNodeNotInQueue() {
        let link = DoublyLink<Int>(with: 3)
        
        // Create a node that's not in the queue
        let externalNode = DoublyLink<Int>.Node(element: 999)
        
        // This should not crash, but will decrease count even if node is not in queue
        link.removeNode(externalNode)
        XCTAssertEqual(link.count, -1) // count becomes negative when removing non-existent node
    }
    
    func testRemoveNodeFromEmptyQueue() {
        let link = DoublyLink<Int>(with: 3)
        
        let node = DoublyLink<Int>.Node(element: 1)
        link.enqueueFront(node: node)
        link.removeNode(node)
        
        XCTAssertEqual(link.count, 0)
        XCTAssertNil(link.front)
        XCTAssertNil(link.back)
    }
}
