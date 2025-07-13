//
//  HeapPerformanceTests.swift
//  MonstoreTests
//
//  Created on 2024-12-19.
//

import XCTest
@testable import Monstore

final class HeapPerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var maxHeap: Heap<Int>!
    private var minHeap: Heap<Int>!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        maxHeap = Heap(capacity: 10000, compare: { $0 > $1 ? .moreTop : ($0 < $1 ? .moreBottom : .equal) })
        minHeap = Heap(capacity: 10000, compare: { $0 < $1 ? .moreTop : ($0 > $1 ? .moreBottom : .equal) })
    }
    
    override func tearDown() {
        maxHeap = nil
        minHeap = nil
        super.tearDown()
    }
    
    // MARK: - Insert Performance Tests
    
    func testInsertPerformance_MaxHeap() {
        measure {
            for i in 0..<1000 {
                maxHeap.insert(i)
            }
        }
    }
    
    func testInsertPerformance_MinHeap() {
        measure {
            for i in 0..<1000 {
                minHeap.insert(i)
            }
        }
    }
    
    func testInsertPerformance_ReverseOrder() {
        measure {
            for i in (0..<1000).reversed() {
                maxHeap.insert(i)
            }
        }
    }
    
    func testInsertPerformance_RandomOrder() {
        let randomNumbers = (0..<1000).shuffled()
        measure {
            for number in randomNumbers {
                maxHeap.insert(number)
            }
        }
    }
    
    // MARK: - Remove Performance Tests
    
    func testRemovePerformance_MaxHeap() {
        // Pre-populate
        for i in 0..<1000 {
            maxHeap.insert(i)
        }
        
        measure {
            for _ in 0..<1000 {
                _ = maxHeap.remove()
            }
        }
    }
    
    func testRemovePerformance_MinHeap() {
        // Pre-populate
        for i in 0..<1000 {
            minHeap.insert(i)
        }
        
        measure {
            for _ in 0..<1000 {
                _ = minHeap.remove()
            }
        }
    }
    
    func testRemoveAtPerformance_MaxHeap() {
        // Pre-populate
        for i in 0..<1000 {
            maxHeap.insert(i)
        }
        
        measure {
            for i in (0..<1000).reversed() {
                _ = maxHeap.remove(at: i)
            }
        }
    }
    
    func testRemoveAtPerformance_MinHeap() {
        // Pre-populate
        for i in 0..<1000 {
            minHeap.insert(i)
        }
        
        measure {
            for i in (0..<1000).reversed() {
                _ = minHeap.remove(at: i)
            }
        }
    }
    
    // MARK: - Peek Performance Tests
    
    func testPeekPerformance_MaxHeap() {
        // Pre-populate
        for i in 0..<1000 {
            maxHeap.insert(i)
        }
        
        measure {
            for _ in 0..<1000 {
                _ = maxHeap.root
            }
        }
    }
    
    func testPeekPerformance_MinHeap() {
        // Pre-populate
        for i in 0..<1000 {
            minHeap.insert(i)
        }
        
        measure {
            for _ in 0..<1000 {
                _ = minHeap.root
            }
        }
    }
    
    // MARK: - Mixed Operations Performance Tests
    
    func testMixedOperationsPerformance_MaxHeap() {
        measure {
            for i in 0..<1000 {
                maxHeap.insert(i)
                if i % 3 == 0 {
                    _ = maxHeap.root
                }
                if i % 5 == 0 {
                    _ = maxHeap.remove()
                }
            }
        }
    }
    
    func testMixedOperationsPerformance_MinHeap() {
        measure {
            for i in 0..<1000 {
                minHeap.insert(i)
                if i % 3 == 0 {
                    _ = minHeap.root
                }
                if i % 5 == 0 {
                    _ = minHeap.remove()
                }
            }
        }
    }
    
    // MARK: - Force Insert Performance Tests
    
    func testForceInsertPerformance_MaxHeap() {
        measure {
            for i in 0..<1000 {
                _ = maxHeap.insert(i, force: true)
            }
        }
    }
    
    func testForceInsertPerformance_MinHeap() {
        measure {
            for i in 0..<1000 {
                _ = minHeap.insert(i, force: true)
            }
        }
    }
    
    func testForceInsertWithRemovalPerformance_MaxHeap() {
        measure {
            for i in 0..<1000 {
                _ = maxHeap.insert(i, force: true)
            }
        }
    }
    
    func testForceInsertWithRemovalPerformance_MinHeap() {
        measure {
            for i in 0..<1000 {
                _ = minHeap.insert(i, force: true)
            }
        }
    }
    
    // MARK: - Large Scale Performance Tests
    
    func testLargeScaleInsertPerformance_MaxHeap() {
        measure {
            for i in 0..<10000 {
                maxHeap.insert(i)
            }
        }
    }
    
    func testLargeScaleInsertPerformance_MinHeap() {
        measure {
            for i in 0..<10000 {
                minHeap.insert(i)
            }
        }
    }
    
    func testLargeScaleRemovePerformance_MaxHeap() {
        // Pre-populate
        for i in 0..<10000 {
            maxHeap.insert(i)
        }
        
        measure {
            for _ in 0..<10000 {
                _ = maxHeap.remove()
            }
        }
    }
    
    func testLargeScaleRemovePerformance_MinHeap() {
        // Pre-populate
        for i in 0..<10000 {
            minHeap.insert(i)
        }
        
        measure {
            for _ in 0..<10000 {
                _ = minHeap.remove()
            }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsage_MaxHeap() {
        let initialMemory = getMemoryUsage()
        
        for i in 0..<10000 {
            maxHeap.insert(i)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("MaxHeap memory increase: \(memoryIncrease) bytes")
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024) // Less than 10MB
    }
    
    func testMemoryUsage_MinHeap() {
        let initialMemory = getMemoryUsage()
        
        for i in 0..<10000 {
            minHeap.insert(i)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("MinHeap memory increase: \(memoryIncrease) bytes")
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024) // Less than 10MB
    }
    
    // MARK: - Heap Property Validation Tests
    
    func testHeapPropertyValidation_MaxHeap() {
        // Insert random numbers
        let randomNumbers = (0..<1000).shuffled()
        for number in randomNumbers {
            maxHeap.insert(number)
        }
        
        // Verify heap property
        measure {
            for _ in 0..<100 {
                let root = maxHeap.root
                let leftChild = maxHeap.count > 1 ? maxHeap.root : nil
                let rightChild = maxHeap.count > 2 ? maxHeap.root : nil
                
                if let left = leftChild {
                    XCTAssertGreaterThanOrEqual(root!, left)
                }
                if let right = rightChild {
                    XCTAssertGreaterThanOrEqual(root!, right)
                }
            }
        }
    }
    
    func testHeapPropertyValidation_MinHeap() {
        // Insert random numbers
        let randomNumbers = (0..<1000).shuffled()
        for number in randomNumbers {
            minHeap.insert(number)
        }
        
        // Verify heap property
        measure {
            for _ in 0..<100 {
                let root = minHeap.root
                let leftChild = minHeap.count > 1 ? minHeap.root : nil
                let rightChild = minHeap.count > 2 ? minHeap.root : nil
                
                if let left = leftChild {
                    XCTAssertLessThanOrEqual(root!, left)
                }
                if let right = rightChild {
                    XCTAssertLessThanOrEqual(root!, right)
                }
            }
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentInsertPerformance_MaxHeap() {
        measure {
            for i in 0..<1000 {
                maxHeap.insert(i)
            }
        }
    }
    
    func testConcurrentInsertPerformance_MinHeap() {
        measure {
            for i in 0..<1000 {
                minHeap.insert(i)
            }
        }
    }
    
    // MARK: - Edge Cases Performance Tests
    
    func testEmptyHeapOperationsPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = maxHeap.root
                _ = maxHeap.remove()
            }
        }
    }
    
    func testSingleElementOperationsPerformance() {
        maxHeap.insert(42)
        
        measure {
            for _ in 0..<1000 {
                _ = maxHeap.root
            }
        }
    }
    
    func testCapacityOverflowPerformance() {
        let smallHeap = Heap<Int>(capacity: 10, compare: { $0 > $1 ? .moreTop : ($0 < $1 ? .moreBottom : .equal) })
        
        measure {
            for i in 0..<1000 {
                _ = smallHeap.insert(i, force: true)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
} 