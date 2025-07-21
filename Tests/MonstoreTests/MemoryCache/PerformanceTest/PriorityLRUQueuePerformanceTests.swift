//
//  PriorityLRUQueuePerformanceTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/15.
//
//  Performance tests for PriorityLRUQueue: measures throughput and latency for bulk operations,
//  eviction, and mixed workloads under load.

import XCTest
@testable import Monstore

/// Performance tests for PriorityLRUQueue.
final class PriorityLRUQueuePerformanceTests: XCTestCase {
    /// Measures bulk insertion and retrieval throughput.
    func testBulkInsertAndRetrievePerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: count)
        measure {
            for i in 0..<count {
                _ = queue.setElement(i, for: i, with: Double(i % 10))
            }
            for i in 0..<count {
                _ = queue.getElement(for: i)
            }
        }
    }

    /// Measures LRU eviction performance under load.
    func testLRUEvictionPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 1000)
        for i in 0..<1000 {
            _ = queue.setElement(i, for: i, with: Double(i % 10))
        }
        measure {
            for i in 1000..<count {
                _ = queue.setElement(i, for: i, with: Double(i % 10))
            }
        }
    }

    /// Measures priority-based eviction performance under load.
    func testPriorityEvictionPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 1000)
        measure {
            for i in 0..<count {
                _ = queue.setElement(i, for: i, with: Double(i % 100))
            }
        }
    }

    /// Measures performance of a mixed workload (insert, get, remove).
    func testMixedWorkloadPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 2000)
        measure {
            for i in 0..<count {
                _ = queue.setElement(i, for: i, with: Double(i % 10))
                _ = queue.getElement(for: i)
                if i % 3 == 0 {
                    _ = queue.removeElement(for: i - 1)
                }
            }
        }
    }

// MARK: - Small Capacity Edge Case Performance
    /// Measures performance for queue with capacity 1.
    func testSmallCapacity1Performance() {
        let cap = 1
        let queue = PriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = queue.setElement(i, for: "key\(i)", with: Double(i % 2))
                _ = queue.getElement(for: "key\(i)")
                _ = queue.removeElement(for: "key\(i)")
            }
        }
    }
    /// Measures performance for queue with capacity 2.
    func testSmallCapacity2Performance() {
        let cap = 2
        let queue = PriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = queue.setElement(i, for: "key\(i)", with: Double(i % 2))
                _ = queue.getElement(for: "key\(i)")
                _ = queue.removeElement(for: "key\(i)")
            }
        }
    }
    /// Measures performance for queue with capacity 10.
    func testSmallCapacity10Performance() {
        let cap = 10
        let queue = PriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = queue.setElement(i, for: "key\(i)", with: Double(i % 2))
                _ = queue.getElement(for: "key\(i)")
                _ = queue.removeElement(for: "key\(i)")
            }
        }
    }

// MARK: - Randomized Workload Performance
    /// Measures performance under a randomized insert/get/remove workload.
    func testRandomizedWorkloadPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, String>(capacity: 1000)
        var inserted = 0
        var removed = 0
        measure {
            for _ in 0..<(count * 2) {
                let op = Int.random(in: 0..<3)
                if op == 0 && inserted < count {
                    _ = queue.setElement("val\(inserted)", for: inserted, with: Double(inserted % 10))
                    inserted += 1
                } else if op == 1 {
                    _ = queue.getElement(for: Int.random(in: 0..<count))
                } else if removed < inserted {
                    _ = queue.removeElement(for: removed)
                    removed += 1
                }
            }
        }
    }

// MARK: - Remove at Random Key Performance
    /// Measures performance of removing elements at random keys.
    func testRemoveAtRandomKeyPerformance() {
        let count = 5000
        let queue = PriorityLRUQueue<Int, Int>(capacity: count)
        for i in 0..<count {
            _ = queue.setElement(i, for: i, with: Double(i % 10))
        }
        var keys = Array(0..<count)
        keys.shuffle()
        var removeIdx = 0
        measure {
            while queue.count > 0 && removeIdx < keys.count {
                let key = keys[removeIdx]
                _ = queue.removeElement(for: key)
                removeIdx += 1
            }
        }
    }

    // MARK: - Remove Element (No Parameter) Performance Tests

    /// Measures performance of removing least recently used elements.
    func testRemoveElementNoParameterPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: count)
        
        // Pre-populate queue
        for i in 0..<count {
            _ = queue.setElement(i, for: i, with: Double(i % 10))
        }
        
        measure {
            // Remove all elements using removeElement()
            while queue.count > 0 {
                _ = queue.removeElement()
            }
        }
    }

    /// Measures performance of mixed workload including removeElement().
    func testMixedWorkloadWithRemoveElementPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 2000)
        measure {
            for i in 0..<count {
                _ = queue.setElement(i, for: i, with: Double(i % 10))
                _ = queue.getElement(for: i)
                if i % 3 == 0 {
                    _ = queue.removeElement(for: i - 1)
                }
                if i % 5 == 0 {
                    _ = queue.removeElement() // Remove LRU
                }
            }
        }
    }

    // MARK: - Stress/Long-Running Performance
    /// Measures performance under long-running, high-churn workload.
    func testStressLongRunningPerformance() {
        let count = 50_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 1000)
        measure {
            for i in 0..<count {
                _ = queue.setElement(i, for: i, with: Double(i % 10))
                if i % 2 == 0 {
                    _ = queue.removeElement(for: i - 1)
                }
                if i % 100 == 0 {
                    _ = queue.removeElement() // Remove LRU
                }
            }
        }
    }
} 
