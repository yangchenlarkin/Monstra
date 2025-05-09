//
//  DoublyLinkedListQueueTests.swift
//
//
//  Created by Larkin on 2025/5/9.
//

import XCTest
@testable import Monstore

extension DoublyLinkedListQueueTests {
    /// Represents heap operations for testing
    enum Operation: CustomStringConvertible {
        case enqueue(value: Int, expectedResult: (Int?, Int?))
        case dequeue(expectedResult: Int?)
        
        var description: String {
            switch self {
            case .enqueue(let value, _):
                return "Insert \(value)"
            case .dequeue(_):
                return "Remove"
            }
        }
    }
    
    struct TestCase {
        let title: String
        var failMessage: String? = nil
        var description: String {
            guard let failMessage else { return title }
            return """
                            >>>>
                            >>>> TEST CASE: \(title)
                            >>>> FAIL INFO:
                            \(failMessage)
                            """
        }
        let capacity: Int
        let operations: [Operation]
        let expectedElements: [Int]
        
        mutating func run() {
            XCTAssertTrue(
                validate(),
                "Failed test case: \(description)"
            )
        }
        
        /// Validates heap operations and heap property
        mutating func validate() -> Bool {
            var target = DoublyLinkedListQueue<Int>(capacity: capacity)
            for operation in operations {
                switch operation {
                case .enqueue(let value, let expectedResult):
                    let res = target.unsafeEnqueue(value)
                    guard
                        res.0?.value == expectedResult.0,
                        res.1?.value == expectedResult.1
                    else {
                        failMessage = "enqueue<\(value)>, result: \(res), expectedResult: \(expectedResult)"
                        return false
                    }
                case .dequeue(let expectedResult):
                    let res = target.unsafeDequeue()
                    guard res?.value == expectedResult else {
                        failMessage = "dequeue, result: \(String(describing: res)), expectedResult: \(String(describing: expectedResult))"
                        return false
                    }
                    guard res?.next == nil, res?.previous == nil else {
                        failMessage = "dequeue, res.next: \(String(describing: res?.next)), res.previous: \(String(describing: res?.previous))"
                        return false
                    }
                }
            }
            
            if target.isEmpty {
                return true
            }
            
            guard
                target.front?.previous == nil,
                target.back?.next == nil
            else {
                self.failMessage = "front.previous: \(String(describing: target.front?.previous)), back.next: \(String(describing: target.back?.next))"
                return false
            }
            
            // Check for cycles in both directions
            var slow: ListNode<Int>?
            var fast: ListNode<Int>?
            
            // Check forward direction
            slow = target.front
            fast = target.front
            while slow?.next != nil || fast?.next != nil {
                slow = slow?.next
                fast = slow?.next
                if slow === fast {
                    failMessage = """
                        Invalid list structure:
                        Forward cycle detected
                        Current count: \(target.count)
                        """
                    return false
                }
            }
            
            // Validate list structure by traversing from front to back
            var cur = target.front
            var next = cur?.next
            if next == nil {
                return cur === target.back
            }
            
            while true {
                if next === target.back {
                    // Successfully validated forward links up to back node
                    return true
                }
                
                if cur !== next?.previous {
                    // Broken link detected: current node is not the previous node of next
                    failMessage = """
                        Invalid list structure:
                        Broken bidirectional link detected during forward traversal
                        Current node: \(String(describing: cur?.value))
                        Next node: \(String(describing: next?.value))
                        Next.previous: \(String(describing: next?.previous?.value))
                        Current count: \(target.count)
                        """
                    return false
                }
                
                if next == nil {
                    // Next node is nil but haven't reached back node yet
                    failMessage = """
                        Invalid list structure:
                        Unexpected end of list during forward traversal
                        Current node: \(String(describing: cur?.value))
                        Expected back node: \(String(describing: target.back?.value))
                        Current count: \(target.count)
                        """
                    return false
                }
                
                // Advance to next pair of nodes
                next = next?.next
                cur = next
            }
        }
    }
}

final class DoublyLinkedListQueueTests: XCTestCase {
    func testBasicOperations() {
        var testCase = TestCase(
            title: "Basic enqueue and dequeue operations",
            capacity: 3,
            operations: [
                .enqueue(value: 1, expectedResult: (1, nil)),
                .enqueue(value: 2, expectedResult: (2, nil)),
                .enqueue(value: 3, expectedResult: (3, nil)),
                .dequeue(expectedResult: 1)
            ],
            expectedElements: [3,2]
        )
        testCase.run()
    }
    
    func testQueueOverflow() {
        var testCase = TestCase(
            title: "Queue overflow handling",
            capacity: 3,
            operations: [
                .enqueue(value: 1, expectedResult: (1, nil)),
                .enqueue(value: 2, expectedResult: (2, nil)),
                .enqueue(value: 3, expectedResult: (3, nil)),
                .enqueue(value: 4, expectedResult: (4, 3)), // Should displace 3
                .enqueue(value: 5, expectedResult: (5, 2))  // Should displace 2
            ],
            expectedElements: [5, 4, 1]
        )
        testCase.run()
    }
    
    func testEmptyQueueOperations() {
        var testCase = TestCase(
            title: "Empty queue operations",
            capacity: 3,
            operations: [
                .dequeue(expectedResult: nil),
                .enqueue(value: 1, expectedResult: (1, nil)),
                .dequeue(expectedResult: 1),
                .dequeue(expectedResult: nil)
            ],
            expectedElements: []
        )
        testCase.run()
    }
    
    func testSingleElementOperations() {
        var testCase = TestCase(
            title: "Single element operations",
            capacity: 1,
            operations: [
                .enqueue(value: 1, expectedResult: (1, nil)),
                .enqueue(value: 2, expectedResult: (2, 1)), // Should replace 1
                .dequeue(expectedResult: 2),
                .enqueue(value: 3, expectedResult: (3, nil))
            ],
            expectedElements: [3]
        )
        testCase.run()
    }
    
    func testZeroCapacity() {
        var testCase = TestCase(
            title: "Zero capacity operations",
            capacity: 0,
            operations: [
                .enqueue(value: 1, expectedResult: (nil, nil)),
                .dequeue(expectedResult: nil)
            ],
            expectedElements: []
        )
        testCase.run()
    }
    
    func testAlternatingOperations() {
        var testCase = TestCase(
            title: "Alternating enqueue and dequeue",
            capacity: 3,
            operations: [
                .enqueue(value: 1, expectedResult: (1, nil)),
                .dequeue(expectedResult: 1),
                .enqueue(value: 2, expectedResult: (2, nil)),
                .enqueue(value: 3, expectedResult: (3, nil)),
                .dequeue(expectedResult: 3),
                .enqueue(value: 4, expectedResult: (4, nil))
            ],
            expectedElements: [4, 2]
        )
        testCase.run()
    }
    
    func testSequentialDequeue() {
        var testCase = TestCase(
            title: "Sequential dequeue operations",
            capacity: 4,
            operations: [
                .enqueue(value: 1, expectedResult: (1, nil)),
                .enqueue(value: 2, expectedResult: (2, nil)),
                .enqueue(value: 3, expectedResult: (3, nil)),
                .enqueue(value: 4, expectedResult: (4, nil)),
                .dequeue(expectedResult: 4),
                .dequeue(expectedResult: 3),
                .dequeue(expectedResult: 2),
                .dequeue(expectedResult: 1)
            ],
            expectedElements: []
        )
        testCase.run()
    }
    
    func testBoundaryConditions() {
        var testCase = TestCase(
            title: "Boundary conditions",
            capacity: 2,
            operations: [
                .enqueue(value: Int.max, expectedResult: (Int.max, nil)),
                .enqueue(value: Int.min, expectedResult: (Int.min, nil)),
                .dequeue(expectedResult: Int.min),
                .dequeue(expectedResult: Int.max)
            ],
            expectedElements: []
        )
        testCase.run()
    }
    
    func testRapidOperations() {
        var testCase = TestCase(
            title: "Rapid enqueue/dequeue operations",
            capacity: 3,
            operations: [
                .enqueue(value: 1, expectedResult: (1, nil)),
                .dequeue(expectedResult: 1),
                .enqueue(value: 2, expectedResult: (2, nil)),
                .dequeue(expectedResult: 2),
                .enqueue(value: 3, expectedResult: (3, nil)),
                .enqueue(value: 4, expectedResult: (4, nil)),
                .enqueue(value: 5, expectedResult: (5, nil)),
                .dequeue(expectedResult: 5),
                .dequeue(expectedResult: 4),
                .dequeue(expectedResult: 3)
            ],
            expectedElements: []
        )
        testCase.run()
    }
}
