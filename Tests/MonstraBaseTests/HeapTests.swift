//
//  HeapTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/5/6.
//

import XCTest
@testable import Monstra

// MARK: - Types
extension HeapTests {
    /// Represents heap operations for testing
    enum Operation: CustomStringConvertible {
        case insertion(value: Int, forceInsert: Bool = false, expectedResult: Int?)
        case removal(index: Int = 0, expectedResult: Int?)
        
        var description: String {
            switch self {
            case .insertion(let value, _, _):
                return "Insert \(value)"
            case .removal(let index, _):
                return "Remove at index \(index)"
            }
        }
    }
    
    /// Test case configuration for heap validation
    class TestCase {
        class Node: Comparable, ExpressibleByIntegerLiteral {
            required init(integerLiteral value: Int) {
                self.index = nil
                self.value = value
            }
            
            static func < (lhs: HeapTests.TestCase.Node, rhs: HeapTests.TestCase.Node) -> Bool {
                lhs.value < rhs.value
            }
            
            static func == (lhs: HeapTests.TestCase.Node, rhs: HeapTests.TestCase.Node) -> Bool {
                lhs.value == rhs.value
            }
            
            var index: Int?
            var value: Int
            
            init(index: Int? = nil, value: Int) {
                self.index = index
                self.value = value
            }
        }
        
        enum HeapType {
            case max
            case min
        }
        
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
        let heapType: HeapType
        let capacity: Int
        let operations: [Operation]
        let expectedElements: [Int]
        
        init(title: String, failMessage: String? = nil, heapType: HeapType, capacity: Int, operations: [Operation], expectedElements: [Int]) {
            self.title = title
            self.failMessage = failMessage
            self.heapType = heapType
            self.capacity = capacity
            self.operations = operations
            self.expectedElements = expectedElements
        }
        
        func run() {
            XCTAssertTrue(
                validate(),
                "Failed test case: \(description)"
            )
        }
        
        /// Validates heap operations and heap property
        func validate() -> Bool {
            var heap: Heap<Node>
            switch heapType {
            case .max:
                heap = .maxHeap(capacity: capacity)
            case .min:
                heap = .minHeap(capacity: capacity)
            }
            
            heap.onEvent = {
                switch $0 {
                case .insert(element: let element, at: let to):
                    element.index = to
                case .remove:
                    break
                case .move(element: let element, to: let to):
                    element.index = to
                }
            }
            
            // Execute operations
            for operation in operations {
                switch operation {
                case .insertion(let value, let forceInsert, let expectedResult):
                    guard heap.insert(.init(value: value), force: forceInsert)?.value == expectedResult else {
                        self.failMessage = "\(operation)"
                        return false
                    }
                case .removal(let index, let expectedResult):
                    guard heap.remove(at: index)?.value == expectedResult else {
                        self.failMessage = "\(operation)"
                        return false
                    }
                }
            }
            
            // Validate count
            guard heap.elements.map({$0.value}) == expectedElements else {
                self.failMessage = """
                            heap.elements = \(heap.elements);
                            expectedElements = \(expectedElements);
                            """
                return false
            }
            
            for i in 0..<heap.elements.count {
                guard heap.elements[i].index == i else {
                    self.failMessage = """
                                event notification verificatio failed at: \(i), \(String(describing: heap.elements[i].index));
                                heap.elements = \(heap.elements);
                                expectedElements = \(expectedElements);
                                """
                    return false
                }
            }
            
            // Validate heap property
            return validateHeapProperty(elements: heap.elements, type: heapType)
        }
        
        /// Validates if array satisfies heap property
        private func validateHeapProperty(elements: [Node], type: HeapType) -> Bool {
            guard !elements.isEmpty else { return true }
            
            for i in 0..<elements.count {
                let leftChild = 2 * i + 1
                let rightChild = 2 * i + 2
                
                if leftChild < elements.count {
                    switch type {
                    case .max:
                        guard elements[i] >= elements[leftChild] else {
                            self.failMessage = """
                            maxHeap:
                            node(\(i)) = \(elements[i])
                            l(\(i)) = \(elements[leftChild])
                            \(elements)
                            """
                            return false
                        }
                    case .min:
                        guard elements[i] <= elements[leftChild] else {
                            self.failMessage = """
                            minHeap:
                            node(\(i)) = \(elements[i])
                            l(\(i)) = \(elements[leftChild])
                            \(elements)
                            """
                            return false
                        }
                    }
                }
                
                if rightChild < elements.count {
                    switch type {
                    case .max:
                        guard elements[i] >= elements[rightChild] else {
                            self.failMessage = """
                            maxHeap:
                            node(\(i)) = \(elements[i])
                            r(\(i)) = \(elements[rightChild])
                            \(elements)
                            """
                            return false
                        }
                    case .min:
                        guard elements[i] <= elements[rightChild] else {
                            self.failMessage = """
                            minHeap:
                            node(\(i)) = \(elements[i])
                            r(\(i)) = \(elements[rightChild])
                            \(elements)
                            """
                            return false
                        }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - Basic Operations Tests
final class HeapTests: XCTestCase {
    func testBasicMaxHeapInsertion() {
        let testCase = TestCase(
            title: "Basic max heap insertion",
            heapType: .max,
            capacity: 5,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 20, expectedResult: nil),
                .insertion(value: 15, expectedResult: nil)
            ],
            expectedElements: [20, 10, 15]
        )
        testCase.run()
    }
    
    func testMaxHeapOverflow() {
        let testCase = TestCase(
            title: "Max heap overflow handling",
            heapType: .max,
            capacity: 3,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 20, expectedResult: nil),
                .insertion(value: 30, expectedResult: nil),
                .insertion(value: 40, expectedResult: 40)
            ],
            expectedElements: [30, 10, 20]
        )
        testCase.run()
    }
    
    func testMaxHeapBasicRemoval() {
        let testCase = TestCase(
            title: "Max heap basic removal operations",
            heapType: .max,
            capacity: 5,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 20, expectedResult: nil),
                .insertion(value: 15, expectedResult: nil),
                .removal(expectedResult: 20),
                .removal(expectedResult: 15)
            ],
            expectedElements: [10]
        )
        testCase.run()
    }
    
    // MARK: - Min Heap Tests
    
    func testBasicMinHeapInsertion() {
        let testCase = TestCase(
            title: "Basic min heap insertion",
            heapType: .min,
            capacity: 5,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 5, expectedResult: nil),
                .insertion(value: 15, expectedResult: nil)
            ],
            expectedElements: [5, 10, 15]
        )
        testCase.run()
    }
    
    func testMinHeapOverflow() {
        let testCase = TestCase(
            title: "Min heap overflow handling",
            heapType: .min,
            capacity: 3,
            operations: [
                .insertion(value: 15, expectedResult: nil),
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 5, expectedResult: nil),
                .insertion(value: 1, expectedResult: 1)
            ],
            expectedElements: [5, 15, 10]
        )
        testCase.run()
    }
    
    // MARK: - Specific Index Removal Tests
    
    func testMaxHeapMiddleRemoval() {
        let testCase = TestCase(
            title: "Max heap middle index removal",
            heapType: .max,
            capacity: 7,
            operations: [
                .insertion(value: 100, expectedResult: nil),
                .insertion(value: 80, expectedResult: nil),
                .insertion(value: 90, expectedResult: nil),
                .insertion(value: 50, expectedResult: nil),
                .insertion(value: 60, expectedResult: nil),
                .insertion(value: 70, expectedResult: nil),
                .removal(index: 2, expectedResult: 90),
                .removal(index: 1, expectedResult: 80)
            ],
            expectedElements: [100, 60, 70, 50]
        )
        testCase.run()
    }
    
    func testMinHeapLeafRemoval() {
        let testCase = TestCase(
            title: "Min heap leaf removal",
            heapType: .min,
            capacity: 6,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 20, expectedResult: nil),
                .insertion(value: 15, expectedResult: nil),
                .insertion(value: 40, expectedResult: nil),
                .insertion(value: 50, expectedResult: nil),
                .removal(index: 4, expectedResult: 50),
                .removal(index: 3, expectedResult: 40)
            ],
            expectedElements: [10, 20, 15]
        )
        testCase.run()
    }
    
    func testMixedIndexRemovalPattern() {
        let testCase = TestCase(
            title: "Mixed index removal pattern",
            heapType: .max,
            capacity: 5,
            operations: [
                .insertion(value: 50, expectedResult: nil),
                .insertion(value: 40, expectedResult: nil),
                .insertion(value: 30, expectedResult: nil),
                .insertion(value: 20, expectedResult: nil),
                .insertion(value: 10, expectedResult: nil),
                .removal(index: 0, expectedResult: 50),
                .removal(index: 2, expectedResult: 30),
                .removal(index: 0, expectedResult: 40)
            ],
            expectedElements: [20, 10]
        )
        testCase.run()
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyHeapOperations() {
        let testCase = TestCase(
            title: "Empty heap operations",
            heapType: .max,
            capacity: 0,
            operations: [
                .insertion(value: 10, expectedResult: 10),
                .removal(expectedResult: nil)
            ],
            expectedElements: []
        )
        testCase.run()
    }
    
    func testSingleElementOperations() {
        let testCase = TestCase(
            title: "Single element operations",
            heapType: .min,
            capacity: 1,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 5, expectedResult: 5)
            ],
            expectedElements: [10]
        )
        testCase.run()
    }
    
    func testInvalidIndexRemoval() {
        let testCase = TestCase(
            title: "Invalid index removal",
            heapType: .min,
            capacity: 3,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 20, expectedResult: nil),
                .removal(index: 5, expectedResult: nil),
                .removal(index: -1, expectedResult: nil),
                .removal(index: 1, expectedResult: 20)
            ],
            expectedElements: [10]
        )
        testCase.run()
    }
    
    func testComplexReheapification() {
        let testCase = TestCase(
            title: "Complex reheapification after removal",
            heapType: .max,
            capacity: 8,
            operations: [
                .insertion(value: 100, expectedResult: nil),
                .insertion(value: 90, expectedResult: nil),
                .insertion(value: 80, expectedResult: nil),
                .insertion(value: 70, expectedResult: nil),
                .insertion(value: 60, expectedResult: nil),
                .insertion(value: 50, expectedResult: nil),
                .insertion(value: 40, expectedResult: nil),
                .removal(index: 1, expectedResult: 90),
                .removal(index: 2, expectedResult: 80)
            ],
            expectedElements: [100, 70, 50, 40, 60]
        )
        testCase.run()
    }
    
    func testMaxHeapForceInsert() {
        /*
        Initial:     After force insert 95:
            100            95
           90  80    ->    90  80
          70 60 50        70 60 50
        
        Since heap is full, force insert replaces root (100)
        and returns 100 as expectedResult
        */
        let testCase = TestCase(
            title: "Max heap force insert - replace root",
            heapType: .max,
            capacity: 6,
            operations: [
                .insertion(value: 100, expectedResult: nil),
                .insertion(value: 90, expectedResult: nil),
                .insertion(value: 80, expectedResult: nil),
                .insertion(value: 70, expectedResult: nil),
                .insertion(value: 60, expectedResult: nil),
                .insertion(value: 50, expectedResult: nil),
                // Force insert should replace root and return its value
                .insertion(value: 95, forceInsert: true, expectedResult: 100)
            ],
            expectedElements: [95, 90, 80, 70, 60, 50]
        )
        testCase.run()
    }
    
    func testMinHeapForceInsert() {
        /*
        Initial:     After force insert 8:
            5            8
           10  15    ->  10  15
          20 25 30      20 25 30
        
        Since heap is full, force insert replaces root (5)
        and returns 5 as expectedResult
        */
        let testCase = TestCase(
            title: "Min heap force insert - replace root",
            heapType: .min,
            capacity: 6,
            operations: [
                .insertion(value: 5, expectedResult: nil),
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 15, expectedResult: nil),
                .insertion(value: 20, expectedResult: nil),
                .insertion(value: 25, expectedResult: nil),
                .insertion(value: 30, expectedResult: nil),
                // Force insert should replace root and return its value
                .insertion(value: 8, forceInsert: true, expectedResult: 5)
            ],
            expectedElements: [8, 10, 15, 20, 25, 30]
        )
        testCase.run()
    }
    
    func testForceInsertSequence() {
        /*
        Sequence of force inserts in max heap:
        1. [50]
        2. [60,50]
        3. [60,50,40]
        4. [30,50,40] (replace 60) -> [50,30,40]
        5. [20,30,40] (replace 50) -> [40,30,20]
        */
        let testCase = TestCase(
            title: "Sequence of force inserts",
            heapType: .max,
            capacity: 3,
            operations: [
                .insertion(value: 50, expectedResult: nil),
                .insertion(value: 60, expectedResult: nil),
                .insertion(value: 40, expectedResult: nil),
                // Force inserts after heap is full
                .insertion(value: 30, forceInsert: true, expectedResult: 60),
                .insertion(value: 20, forceInsert: true, expectedResult: 50)
            ],
            expectedElements: [40,30,20]
        )
        testCase.run()
    }
    
    func testForceInsertEdgeCases() {
        let testCase = TestCase(
            title: "Force insert edge cases",
            heapType: .min,
            capacity: 1,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                // Force insert into single element heap (replaces root)
                .insertion(value: 5, forceInsert: true, expectedResult: 5),
                // Another force insert (replaces root again)
                .insertion(value: 15, forceInsert: true, expectedResult: 10)
            ],
            expectedElements: [15]
        )
        testCase.run()
    }
    
    func testMaxHeapForceInsertWithRemoval() {
        /*
        Operations sequence:
        1. Build heap: [100,90,80]
        2. Force insert 60 -> [60,90,80] (returns 100) -> [90,60,80]
        3. Remove root -> [80,60]
        4. Force insert 70 -> [80,60,70]
        */
        let testCase = TestCase(
            title: "Force insert combined with removal in max heap",
            heapType: .max,
            capacity: 3,
            operations: [
                .insertion(value: 100, expectedResult: nil),
                .insertion(value: 90, expectedResult: nil),
                .insertion(value: 80, expectedResult: nil),
                .insertion(value: 60, forceInsert: true, expectedResult: 100),
                .removal(index: 0, expectedResult: 90),
                .insertion(value: 70, forceInsert: true, expectedResult: nil)
            ],
            expectedElements: [80,60,70]
        )
        testCase.run()
    }
    
    func testMinHeapForceInsertWithRemoval() {
        /*
        Operations sequence:
        1. Build heap: [5,10,15]
        2. Force insert 20 -> [20,10,15] (returns 5) -> [10,20,15]
        3. Remove root -> [15,20]
        4. Force insert 12 -> [15,20,12] -> [12,20,15]
        */
        let testCase = TestCase(
            title: "Force insert combined with removal in min heap",
            heapType: .min,
            capacity: 3,
            operations: [
                .insertion(value: 5, expectedResult: nil),
                .insertion(value: 10, expectedResult: nil),
                .insertion(value: 15, expectedResult: nil),
                .insertion(value: 20, forceInsert: true, expectedResult: 5),
                .removal(index: 0, expectedResult: 10),
                .insertion(value: 12, forceInsert: true, expectedResult: nil)
            ],
            expectedElements: [12,20,15]
        )
        testCase.run()
    }
    
    // MARK: - Dynamic Storage Tests
    
    func testDynamicStorageExpansion() {
        let testCase = TestCase(
            title: "",
            heapType: .max,
            capacity: 2,
            operations: [
                .insertion(value: 1, expectedResult: nil),
                .insertion(value: 2, expectedResult: nil),
                .insertion(value: 3, expectedResult: 3),
            ],
            expectedElements: [2, 1]
        )
        testCase.run()
    }
    
    func testDynamicStorageContraction() {
        let testCase = TestCase(
            title: "",
            heapType: .min,
            capacity: 10,
            operations: [
                .insertion(value: 1, expectedResult: nil),
                .insertion(value: 2, expectedResult: nil),
                .insertion(value: 3, expectedResult: nil),
                .insertion(value: 4, expectedResult: nil),
                .insertion(value: 5, expectedResult: nil),
                .insertion(value: 6, expectedResult: nil),
                .insertion(value: 7, expectedResult: nil),
                .insertion(value: 8, expectedResult: nil),
                .removal(expectedResult: 1),
                .removal(expectedResult: 2),
                .removal(expectedResult: 3),
                .removal(expectedResult: 4),
            ],
            expectedElements: [5, 7, 6, 8]
        )
        testCase.run()
    }
    
    func testDynamicStorageContraction2() {
        let testCase = TestCase(
            title: "",
            heapType: .min,
            capacity: 10,
            operations: [
                .insertion(value: 1, expectedResult: nil),
                .insertion(value: 2, expectedResult: nil),
                .insertion(value: 3, expectedResult: nil),
                .insertion(value: 4, expectedResult: nil),
                .insertion(value: 5, expectedResult: nil),
                .insertion(value: 6, expectedResult: nil),
                .insertion(value: 7, expectedResult: nil),
                .insertion(value: 8, expectedResult: nil),
                .removal(expectedResult: 1),
                .removal(expectedResult: 2),
                .removal(expectedResult: 3),
                .removal(expectedResult: 4),
                .removal(expectedResult: 5),
            ],
            expectedElements: [6, 7, 8]
        )
        testCase.run()
    }
    
    func testXXX() {
        let heap = Heap<Int>.minHeap(capacity: 3)
        XCTAssertNil(heap.insert(1))
        XCTAssertNil(heap.insert(2))
        XCTAssertNil(heap.insert(3))
        XCTAssertEqual(heap.remove(at: 0), 1)
        XCTAssertNil(heap.insert(4))
        XCTAssertEqual(heap.insert(5), 2)
        XCTAssertEqual(heap.insert(6), 3)
        XCTAssertEqual(heap.insert(7), 4)
    }
    
    // MARK: - SiftDown Tests (Focusing on uncovered scenarios)
    
    func testSiftDownIndirectlyThroughRemove() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        
        // Create a heap where siftDown will be triggered during remove
        heap.insert(20) // Root
        heap.insert(15) // Left child
        heap.insert(10) // Right child
        heap.insert(5)  // Will be moved down
        
        // Remove root, which triggers siftDown
        let removed = heap.remove()
        XCTAssertEqual(removed, 20, "Should remove the root")
        
        // Should choose the larger child (15) to become new root
        XCTAssertEqual(heap.root, 15, "Should promote larger child to root")
    }
    
    func testSiftDownWithEqualChildrenIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        
        heap.insert(20) // Root
        heap.insert(15) // Left child
        heap.insert(15) // Right child (equal to left)
        heap.insert(10) // Will be moved down
        
        // Remove root, which triggers siftDown
        let removed = heap.remove()
        XCTAssertEqual(removed, 20, "Should remove the root")
        
        // Should choose one of the equal children (implementation dependent)
        XCTAssertEqual(heap.root, 15, "Should promote one of the equal children to root")
    }
    
    func testSiftDownWithInvalidIndexIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(10)
        
        // Try to remove from invalid index
        let result = heap.remove(at: 5)
        
        // Should return nil for invalid index
        XCTAssertNil(result, "Should return nil for invalid index")
        XCTAssertEqual(heap.root, 10, "Heap should remain unchanged")
    }
    
    func testSiftDownWithNegativeIndexIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(10)
        
        // Try to remove from negative index
        let result = heap.remove(at: -1)
        
        // Should return nil for negative index
        XCTAssertNil(result, "Should return nil for negative index")
        XCTAssertEqual(heap.root, 10, "Heap should remain unchanged")
    }
    
    // MARK: - SiftUp Tests (Focusing on uncovered scenarios)
    
    func testSiftUpIndirectlyThroughInsert() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        
        // Create a heap with multiple levels
        heap.insert(10) // Root
        heap.insert(5)  // Left child
        heap.insert(3)  // Right child
        heap.insert(2)  // Left-left child
        heap.insert(1)  // Left-right child
        
        // Insert a large value, which triggers siftUp
        heap.insert(20)
        
        // Should bubble up to root
        XCTAssertEqual(heap.root, 20, "Large value should bubble up to root")
    }
    
    func testSiftUpWithEqualParentIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        
        heap.insert(10) // Root
        heap.insert(10) // Left child (equal to parent)
        
        // Insert another equal value
        heap.insert(10)
        
        // Should handle equal values correctly
        XCTAssertEqual(heap.root, 10, "Root should remain the same")
    }
    
    func testSiftUpWithInvalidIndexIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(10)
        
        // Try to remove from invalid index (which might trigger siftUp internally)
        let result = heap.remove(at: 5)
        
        // Should return nil for invalid index
        XCTAssertNil(result, "Should return nil for invalid index")
        XCTAssertEqual(heap.root, 10, "Heap should remain unchanged")
    }
    
    func testSiftUpWithNegativeIndexIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(10)
        
        // Try to remove from negative index (which might trigger siftUp internally)
        let result = heap.remove(at: -1)
        
        // Should return nil for negative index
        XCTAssertNil(result, "Should return nil for negative index")
        XCTAssertEqual(heap.root, 10, "Heap should remain unchanged")
    }
    
    func testSiftUpWithRootIndexIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(10)
        
        // Remove and re-insert root (which might trigger siftUp internally)
        let removed = heap.remove()
        heap.insert(removed!)
        
        // Should maintain the same root
        XCTAssertEqual(heap.root, 10, "Root should remain the same")
    }
    
    // MARK: - Insert with Force Tests (Focusing on uncovered scenarios)
    
    func testInsertWithForceAndHigherPriority() {
        let heap = Heap<Int>.maxHeap(capacity: 2)
        
        heap.insert(10) // Root
        heap.insert(5)  // Second element
        
        // Try to force insert a higher priority element
        let result = heap.insert(20, force: true)
        
        // Should reject higher priority element when force is true
        XCTAssertEqual(result, 20, "Should reject higher priority element")
        XCTAssertEqual(heap.root, 10, "Root should remain unchanged")
    }
    
    func testInsertWithForceAndLowerPriority() {
        let heap = Heap<Int>.maxHeap(capacity: 2)
        
        heap.insert(10) // Root
        heap.insert(5)  // Second element
        
        // Try to force insert a lower priority element
        let result = heap.insert(3, force: true)
        
        // Should accept lower priority element and replace root
        XCTAssertEqual(result, 10, "Should return displaced root")
        XCTAssertEqual(heap.root, 5, "Root should be replaced")
    }
    
    func testInsertWithForceAndEqualPriority() {
        let heap = Heap<Int>.maxHeap(capacity: 2)
        
        heap.insert(10) // Root
        heap.insert(5)  // Second element
        
        // Try to force insert an equal priority element
        let result = heap.insert(10, force: true)
        
        // Should reject equal priority element when force is true
        XCTAssertEqual(result, 10, "Should reject equal priority element")
        XCTAssertEqual(heap.root, 10, "Root should remain unchanged")
    }
    
    func testInsertWithForceAndEmptyHeap() {
        let heap = Heap<Int>.maxHeap(capacity: 2)
        
        // Try to force insert into empty heap
        let result = heap.insert(10, force: true)
        
        // Should insert normally
        XCTAssertNil(result, "Should insert normally into empty heap")
        XCTAssertEqual(heap.root, 10, "Should insert the element")
    }
    
    func testInsertWithForceAndZeroCapacity() {
        let heap = Heap<Int>.maxHeap(capacity: 0)
        
        // Try to force insert into zero capacity heap
        let result = heap.insert(10, force: true)
        
        // Should return the element without inserting
        XCTAssertEqual(result, 10, "Should return element without inserting")
    }
    
    // MARK: - CompareAt Tests (Focusing on uncovered scenarios)
    
    func testCompareAtIndirectlyThroughHeapOperations() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(20) // Root
        heap.insert(10) // Left child
        
        // The compareAt method is used internally during heap operations
        // We can test it indirectly by verifying heap properties are maintained
        
        // Remove root and verify heap property is maintained
        let removed = heap.remove()
        XCTAssertEqual(removed, 20, "Should remove the root")
        XCTAssertEqual(heap.root, 10, "Should promote child to root")
        
        // Insert a new element and verify heap property is maintained
        heap.insert(15)
        XCTAssertEqual(heap.root, 15, "Should maintain heap property")
    }
    
    // MARK: - Heapify Tests (Focusing on uncovered scenarios)
    
    func testHeapifyIndirectlyThroughRemove() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(20) // Root
        heap.insert(10) // Left child
        heap.insert(5)  // Right child
        
        // Remove root, which triggers heapify internally
        let removed = heap.remove()
        XCTAssertEqual(removed, 20, "Should remove the root")
        
        // Should maintain heap property after removal
        XCTAssertEqual(heap.root, 10, "Should promote child to root")
    }
    
    func testHeapifyWithInvalidIndexIndirectly() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.insert(10)
        
        // Try to remove from invalid index (which triggers heapify internally)
        let result = heap.remove(at: 5)
        
        // Should return nil for invalid index
        XCTAssertNil(result, "Should return nil for invalid index")
        XCTAssertEqual(heap.root, 10, "Heap should remain unchanged")
    }
    
    // MARK: - Edge Cases and Stress Tests
    
    func testHeapWithCustomComparison() {
        let heap = Heap<String>(capacity: 10) { str1, str2 in
            if str1.count > str2.count { return .moreTop }
            if str1.count < str2.count { return .moreBottom }
            return .equal
        }
        
        heap.insert("a")      // 1 character
        heap.insert("abc")    // 3 characters
        heap.insert("ab")     // 2 characters
        
        // Should prioritize longer strings
        XCTAssertEqual(heap.root, "abc", "Longest string should be at root")
    }
    
    func testHeapWithEventCallbacks() {
        var events: [Heap<Int>.Event] = []
        let heap = Heap<Int>.maxHeap(capacity: 10)
        heap.onEvent = { event in
            events.append(event)
        }
        
        heap.insert(10)
        heap.insert(20)
        heap.remove()
        
        // Should have recorded events
        XCTAssertGreaterThan(events.count, 0, "Should record events")
        
        // Verify event types
        let insertEvents = events.filter { if case .insert = $0 { return true }; return false }
        let removeEvents = events.filter { if case .remove = $0 { return true }; return false }
        let moveEvents = events.filter { if case .move = $0 { return true }; return false }
        
        XCTAssertGreaterThan(insertEvents.count, 0, "Should have insert events")
        XCTAssertGreaterThan(removeEvents.count, 0, "Should have remove events")
        XCTAssertGreaterThanOrEqual(moveEvents.count, 0, "May have move events")
    }
    
    func testHeapPerformanceWithLargeDataset() {
        let heap = Heap<Int>.maxHeap(capacity: 10000)
        
        measure {
            for i in 0..<1000 {
                heap.insert(i)
            }
            
            for _ in 0..<1000 {
                heap.remove()
            }
        }
    }
    
    func testHeapWithRepeatedElements() {
        let heap = Heap<Int>.maxHeap(capacity: 10)
        
        // Insert same element multiple times
        heap.insert(10)
        heap.insert(10)
        heap.insert(10)
        
        // Should handle repeated elements correctly
        XCTAssertEqual(heap.count, 3, "Should count repeated elements")
        XCTAssertEqual(heap.root, 10, "Root should be the repeated element")
    }
    
    func testHeapWithNegativeCapacity() {
        let heap = Heap<Int>.maxHeap(capacity: -5)
        
        // Should handle negative capacity gracefully
        let result = heap.insert(10)
        XCTAssertEqual(result, 10, "Should return element without inserting")
    }
    
    func testHeapWithZeroCapacity() {
        let heap = Heap<Int>.maxHeap(capacity: 0)
        
        let result = heap.insert(10)
        XCTAssertEqual(result, 10, "Should return element without inserting")
        
        let removed = heap.remove()
        XCTAssertNil(removed, "Should not remove from zero capacity heap")
    }
    
    func testHeapWithSingleElement() {
        let heap = Heap<Int>.maxHeap(capacity: 1)
        
        heap.insert(10)
        XCTAssertEqual(heap.root, 10, "Should have single element as root")
        
        let removed = heap.remove()
        XCTAssertEqual(removed, 10, "Should remove the single element")
        XCTAssertNil(heap.root, "Should be empty after removal")
    }
    
    func testHeapWithSequentialAccess() {
        let heap = Heap<Int>.maxHeap(capacity: 1000)
        
        // Test sequential access instead of concurrent access
        for i in 0..<10 {
            heap.insert(i)
        }
        
        XCTAssertEqual(heap.count, 10, "Should have inserted all elements")
        
        // Verify heap property is maintained
        var previous = heap.remove()
        while let current = heap.remove() {
            XCTAssertGreaterThanOrEqual(previous!, current, "Should maintain heap property")
            previous = current
        }
    }
}
