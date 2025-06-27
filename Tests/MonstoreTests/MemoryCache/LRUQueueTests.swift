//
//  LRUQueueTests.swift
//
//
//  Created by Larkin on 2025/5/9.
//

import XCTest
@testable import Monstore

final class LRUQueueTests: XCTestCase {
    func testInsertWithinCapacity() {
        var queue = LRUQueue<String, Int>(capacity: 3)
        queue.unsafeSetValue(1, for: "a")
        queue.unsafeSetValue(2, for: "b")
        queue.unsafeSetValue(3, for: "c")
        
        XCTAssertEqual(queue.count, 3)
        XCTAssertEqual(Array(queue), [3, 2, 1])
    }

    func testOverwriteExistingValue() {
        var queue = LRUQueue<String, Int>(capacity: 2)
        queue.unsafeSetValue(1, for: "a")
        queue.unsafeSetValue(2, for: "b")
        queue.unsafeSetValue(9, for: "a") // update
        
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(Array(queue), [9, 2])
    }

    func testEvictionWhenFull() {
        var queue = LRUQueue<String, Int>(capacity: 2)
        queue.unsafeSetValue(1, for: "a")
        queue.unsafeSetValue(2, for: "b")
        queue.unsafeSetValue(3, for: "c") // should evict "a"
        
        XCTAssertNil(queue.unsafeGetValue(for: "a"))
        XCTAssertEqual(queue.count, 2)
        XCTAssertEqual(Array(queue), [3, 2])
    }

    func testAccessMovesToFront() {
        var queue = LRUQueue<String, Int>(capacity: 3)
        queue.unsafeSetValue(1, for: "a")
        queue.unsafeSetValue(2, for: "b")
        queue.unsafeSetValue(3, for: "c")
        
        let val = queue.unsafeGetValue(for: "a")
        XCTAssertEqual(val, 1)
        XCTAssertEqual(Array(queue), [1, 3, 2])
    }

    func testCapacityZero() {
        var queue = LRUQueue<String, Int>(capacity: 0)
        queue.unsafeSetValue(1, for: "a")
        XCTAssertEqual(queue.count, 0)
        XCTAssertTrue(queue.isEmpty)
        XCTAssertNil(queue.unsafeGetValue(for: "a"))
    }

    func testRepeatInsertSameKey() {
        var queue = LRUQueue<String, Int>(capacity: 2)
        queue.unsafeSetValue(1, for: "a")
        queue.unsafeSetValue(2, for: "a") // overwrite + move to front
        
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(Array(queue), [2])
    }

    func testIterationOrder() {
        var queue = LRUQueue<String, Int>(capacity: 3)
        queue.unsafeSetValue(10, for: "x")
        queue.unsafeSetValue(20, for: "y")
        queue.unsafeSetValue(30, for: "z")
        
        let values = Array(queue)
        XCTAssertEqual(values, [30, 20, 10])
    }

    func testDescriptionFormat() {
        var queue = LRUQueue<String, Int>(capacity: 2)
        queue.unsafeSetValue(100, for: "a")
        queue.unsafeSetValue(200, for: "b")
        XCTAssertEqual(queue.description, "[200, 100]")
    }
    
    func testUnsafeGetValueMovesToFront() {
        var queue = LRUQueue<String, Int>(capacity: 3)
        queue.unsafeSetValue(1, for: "a")
        queue.unsafeSetValue(2, for: "b")
        queue.unsafeSetValue(3, for: "c")
        
        let value = queue.unsafeGetValue(for: "a")
        XCTAssertEqual(value, 1)
        XCTAssertEqual(Array(queue), [1, 3, 2])
    }

    func testUnsafeGetValueForNonexistentKeyReturnsNil() {
        var queue = LRUQueue<String, Int>(capacity: 2)
        queue.unsafeSetValue(1, for: "a")
        
        let value = queue.unsafeGetValue(for: "b")
        XCTAssertNil(value)
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(Array(queue), [1])
    }

    func testMixedSetAndGetBehavior() {
        var queue = LRUQueue<String, Int>(capacity: 3)
        
        queue.unsafeSetValue(1, for: "a")   // a
        queue.unsafeSetValue(2, for: "b")   // b, a
        queue.unsafeSetValue(3, for: "c")   // c, b, a
        
        XCTAssertEqual(Array(queue), [3, 2, 1])
        
        // Access "a", moves to front
        XCTAssertEqual(queue.unsafeGetValue(for: "a"), 1) // a, c, b
        XCTAssertEqual(Array(queue), [1, 3, 2])
        
        // Insert new element, "b" should be evicted (least recently used)
        queue.unsafeSetValue(4, for: "d") // d, a, c
        
        XCTAssertNil(queue.unsafeGetValue(for: "b"))
        XCTAssertEqual(Array(queue), [4, 1, 3])
    }
    
    func testCapacityOneEviction() {
        var queue = LRUQueue<String, Int>(capacity: 1)
        queue.unsafeSetValue(1, for: "a")
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(Array(queue), [1])
        
        queue.unsafeSetValue(2, for: "b") // evicts "a"
        XCTAssertNil(queue.unsafeGetValue(for: "a"))
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(Array(queue), [2])
    }
    
    func testInitializationWithNegativeCapacity() {
        let queue = LRUQueue<String, Int>(capacity: -5)
        XCTAssertEqual(queue.capacity, 0)
        XCTAssertTrue(queue.isEmpty)
    }
}
