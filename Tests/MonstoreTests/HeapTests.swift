import XCTest
@testable import Monstore

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
    struct HeapTestCase {
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
        
        mutating func run() {
            XCTAssertTrue(
                validate(),
                "Failed test case: \(description)"
            )
        }
        
        /// Validates heap operations and heap property
        mutating func validate() -> Bool {
            var heap: Heap<Int>
            switch heapType {
            case .max:
                heap = .maxHeap(capacity: capacity)
            case .min:
                heap = .minHeap(capacity: capacity)
            }
            
            // Execute operations
            for operation in operations {
                switch operation {
                case .insertion(let value, let forceInsert, let expectedResult):
                    guard heap.insert(value, forceInsert: forceInsert) == expectedResult else {
                        self.failMessage = "\(operation)"
                        return false
                    }
                case .removal(let index, let expectedResult):
                    guard heap.remove(at: index) == expectedResult else {
                        self.failMessage = "\(operation)"
                        return false
                    }
                }
            }
            
            // Validate count
            guard heap.elements == expectedElements else {
                self.failMessage = """
                            heap.elements = \(heap.elements);
                            expectedElements = \(expectedElements);
                            """
                return false
            }
            
            // Validate heap property
            return validateHeapProperty(elements: heap.elements, type: heapType)
        }
        
        /// Validates if array satisfies heap property
        private mutating func validateHeapProperty(elements: [Int], type: HeapType) -> Bool {
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
            title: "Force insert edge cases",
            heapType: .min,
            capacity: 1,
            operations: [
                .insertion(value: 10, expectedResult: nil),
                // Force insert into single element heap (replaces root)
                .insertion(value: 5, forceInsert: true, expectedResult: 10),
                // Another force insert (replaces root again)
                .insertion(value: 15, forceInsert: true, expectedResult: 5)
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
        var testCase = HeapTestCase(
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
        var testCase = HeapTestCase(
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
}
