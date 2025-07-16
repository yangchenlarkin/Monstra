//
//  TTLPriorityLRUQueueScaleTests.swift
//  MonstoreTests
//
//  Created on 2024-12-19.
//

import XCTest
@testable import Monstore

final class TTLPriorityLRUQueueScaleTests: XCTestCase {
    
    // MARK: - Small Scale Tests (100 operations)
    
    func testSmallScaleInsertions() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 1000)
        
        measure {
            for i in 0..<100 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
            }
        }
    }
    
    func testSmallScaleMixedOperations() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 1000)
        
        // Pre-populate
        for i in 0..<50 {
            queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
        }
        
        measure {
            // Mixed operations: 50 gets, 50 puts
            for i in 0..<50 {
                _ = queue.getValue(for: i)
            }
            for i in 50..<100 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
            }
        }
    }
    
    func testSmallScaleEvictions() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 50)
        
        measure {
            // Insert 100 items, causing 50 evictions
            for i in 0..<100 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
            }
        }
    }
    
    func testSmallScaleTTLExpirations() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 1000)
        
        measure {
            // Insert items with very short TTL
            for i in 0..<100 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 0.001) // 1ms TTL
            }
            // Force expiration check - note: TTLPriorityLRUQueue doesn't have cleanup method
        }
    }
    
    // MARK: - Large Scale Tests (10,000 operations)
    
    func testLargeScaleInsertions() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        measure {
            for i in 0..<10000 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
            }
        }
    }
    
    func testLargeScaleMixedOperations() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        // Pre-populate
        for i in 0..<5000 {
            queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
        }
        
        measure {
            // Mixed operations: 5000 gets, 5000 puts
            for i in 0..<5000 {
                _ = queue.getValue(for: i)
            }
            for i in 5000..<10000 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
            }
        }
    }
    
    func testLargeScaleEvictions() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 5000)
        
        measure {
            // Insert 10,000 items, causing 5,000 evictions
            for i in 0..<10000 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
            }
        }
    }
    
    func testLargeScaleSequentialAccess() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        // Pre-populate
        for i in 0..<10000 {
            queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
        }
        
        measure {
            // Sequential access pattern
            for i in 0..<10000 {
                _ = queue.getValue(for: i)
            }
        }
    }
    
    func testLargeScaleRandomAccess() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        // Pre-populate
        for i in 0..<10000 {
            queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
        }
        
        measure {
            // Random access pattern
            for _ in 0..<10000 {
                let randomKey = Int.random(in: 0..<10000)
                _ = queue.getValue(for: randomKey)
            }
        }
    }
    
    func testLargeScaleTTLExpirations() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        measure {
            // Insert items with very short TTL
            for i in 0..<10000 {
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: 0.001) // 1ms TTL
            }
            // Force expiration check - note: TTLPriorityLRUQueue doesn't have cleanup method
        }
    }
    
    func testLargeScaleMixedTTLOperations() {
        let queue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        measure {
            // Mixed operations with different TTLs
            for i in 0..<10000 {
                let ttl = Double(i % 10) * 0.1 // Different TTLs
                queue.unsafeSet(value: "value\(i)", for: i, expiredIn: ttl)
            }
        }
    }
    
    // MARK: - Time Complexity Comparison Tests
    
    func testTimeComplexityComparison() {
        let smallQueue = TTLPriorityLRUQueue<Int, String>(capacity: 1000)
        let largeQueue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        var smallTime: TimeInterval = 0
        var largeTime: TimeInterval = 0
        
        // Small scale operations
        let smallStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<100 {
            smallQueue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
        }
        smallTime = CFAbsoluteTimeGetCurrent() - smallStart
        
        // Large scale operations
        let largeStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<10000 {
            largeQueue.unsafeSet(value: "value\(i)", for: i, expiredIn: 1.0)
        }
        largeTime = CFAbsoluteTimeGetCurrent() - largeStart
        
        // Calculate operations per second
        let smallOpsPerSecond = 100.0 / smallTime
        let largeOpsPerSecond = 10000.0 / largeTime
        
        print("=== TTLPriorityLRUQueue Time Complexity Analysis ===")
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
    
    func testTTLComplexityComparison() {
        let smallQueue = TTLPriorityLRUQueue<Int, String>(capacity: 1000)
        let largeQueue = TTLPriorityLRUQueue<Int, String>(capacity: 10000)
        
        var smallTime: TimeInterval = 0
        var largeTime: TimeInterval = 0
        
        // Small scale TTL operations with expiration
        let smallStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<100 {
            smallQueue.unsafeSet(value: "value\(i)", for: i, expiredIn: 0.001)
        }
        smallTime = CFAbsoluteTimeGetCurrent() - smallStart
        
        // Large scale TTL operations with expiration
        let largeStart = CFAbsoluteTimeGetCurrent()
        for i in 0..<10000 {
            largeQueue.unsafeSet(value: "value\(i)", for: i, expiredIn: 0.001)
        }
        largeTime = CFAbsoluteTimeGetCurrent() - largeStart
        
        print("=== TTLPriorityLRUQueue TTL Complexity Analysis ===")
        print("Small scale TTL setup (100 items): \(smallTime * 1000) ms")
        print("Large scale TTL setup (10,000 items): \(largeTime * 1000) ms")
        print("Scale factor: \(Double(10000) / Double(100))x items")
        print("Time factor: \(largeTime / smallTime)x time")
        
        // TTL setup should scale reasonably with operations
        let expectedTimeRatio = Double(10000) / Double(100) // 100x
        let actualTimeRatio = largeTime / smallTime
        let efficiencyRatio = expectedTimeRatio / actualTimeRatio
        
        XCTAssertGreaterThan(efficiencyRatio, 0.3, "TTL setup complexity should be reasonable")
    }
} 
