//
//  LRUQueueScaleTests.swift
//  MonstoreTests
//
//  Created on 2024-12-19.
//

import XCTest
@testable import Monstore

final class LRUQueueScaleTests: XCTestCase {
    
    // MARK: - Small Scale Tests (100 operations)
    
    func testSmallScaleInsertions() {
        let queue = LRUQueue<Int, String>(capacity: 1000)
        
        measure {
            for i in 0..<100 {
                queue.setValue("value\(i)", for: i)
            }
        }
    }
    
    func testSmallScaleMixedOperations() {
        let queue = LRUQueue<Int, String>(capacity: 1000)
        
        // Pre-populate
        for i in 0..<50 {
            queue.setValue("value\(i)", for: i)
        }
        
        measure {
            // Mixed operations: 50 gets, 50 puts
            for i in 0..<50 {
                _ = queue.getValue(for: i)
            }
            for i in 50..<100 {
                queue.setValue("value\(i)", for: i)
            }
        }
    }
    
    func testSmallScaleEvictions() {
        let queue = LRUQueue<Int, String>(capacity: 50)
        
        measure {
            // Insert 100 items, causing 50 evictions
            for i in 0..<100 {
                queue.setValue("value\(i)", for: i)
            }
        }
    }
    
    // MARK: - Large Scale Tests (10,000 operations)
    
    func testLargeScaleInsertions() {
        let queue = LRUQueue<Int, String>(capacity: 10000)
        
        measure {
            for i in 0..<10000 {
                queue.setValue("value\(i)", for: i)
            }
        }
    }
    
    func testLargeScaleMixedOperations() {
        let queue = LRUQueue<Int, String>(capacity: 10000)
        
        // Pre-populate
        for i in 0..<5000 {
            queue.setValue("value\(i)", for: i)
        }
        
        measure {
            // Mixed operations: 5000 gets, 5000 puts
            for i in 0..<5000 {
                _ = queue.getValue(for: i)
            }
            for i in 5000..<10000 {
                queue.setValue("value\(i)", for: i)
            }
        }
    }
    
    func testLargeScaleEvictions() {
        let queue = LRUQueue<Int, String>(capacity: 5000)
        
        measure {
            // Insert 10,000 items, causing 5,000 evictions
            for i in 0..<10000 {
                queue.setValue("value\(i)", for: i)
            }
        }
    }
    
    func testLargeScaleSequentialAccess() {
        let queue = LRUQueue<Int, String>(capacity: 10000)
        
        // Pre-populate
        for i in 0..<10000 {
            queue.setValue("value\(i)", for: i)
        }
        
        measure {
            // Sequential access pattern
            for i in 0..<10000 {
                _ = queue.getValue(for: i)
            }
        }
    }
    
    func testLargeScaleRandomAccess() {
        let queue = LRUQueue<Int, String>(capacity: 10000)
        
        // Pre-populate
        for i in 0..<10000 {
            queue.setValue("value\(i)", for: i)
        }
        
        measure {
            // Random access pattern
            for _ in 0..<10000 {
                let randomKey = Int.random(in: 0..<10000)
                _ = queue.getValue(for: randomKey)
            }
        }
    }
    
    // MARK: - Time Complexity Comparison Tests
    
    func testTimeComplexityComparison() {
        let smallQueue = LRUQueue<Int, String>(capacity: 1000)
        let largeQueue = LRUQueue<Int, String>(capacity: 10000)
        
        var smallTime: TimeInterval = 0
        var largeTime: TimeInterval = 0
        
        // Small scale operations
        let smallStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<100 {
            smallQueue.setValue("value\(i)", for: i)
        }
        smallTime = CFAbsoluteTimeGetCurrent() - smallStart
        
        // Large scale operations
        let largeStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<10000 {
            largeQueue.setValue("value\(i)", for: i)
        }
        largeTime = CFAbsoluteTimeGetCurrent() - largeStart
        
        // Calculate operations per second
        let smallOpsPerSecond = 100.0 / smallTime
        let largeOpsPerSecond = 10000.0 / largeTime
        
        print("=== LRUQueue Time Complexity Analysis ===")
        print("Small scale (100 ops): \(smallTime * 1000) ms, \(smallOpsPerSecond) ops/sec")
        print("Large scale (10,000 ops): \(largeTime * 1000) ms, \(largeOpsPerSecond) ops/sec")
        print("Scale factor: \(Double(10000) / Double(100))x operations")
        print("Time factor: \(largeTime / smallTime)x time")
        print("Efficiency ratio: \((largeOpsPerSecond / smallOpsPerSecond) * 100)%")
        
        // Verify O(1) behavior - time should scale linearly with operations
        let expectedTimeRatio = Double(10000) / Double(100) // 100x
        let actualTimeRatio = largeTime / smallTime
        let efficiencyRatio = expectedTimeRatio / actualTimeRatio
        
        XCTAssertGreaterThan(efficiencyRatio, 0.5, "Time complexity should be close to O(1)")
    }
} 