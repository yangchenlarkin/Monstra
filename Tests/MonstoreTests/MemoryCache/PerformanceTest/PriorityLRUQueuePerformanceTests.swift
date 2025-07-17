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
                _ = queue.setValue(i, for: i, with: Double(i % 10))
            }
            for i in 0..<count {
                _ = queue.getValue(for: i)
            }
        }
    }

    /// Measures LRU eviction performance under load.
    func testLRUEvictionPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 1000)
        for i in 0..<1000 {
            _ = queue.setValue(i, for: i, with: Double(i % 10))
        }
        measure {
            for i in 1000..<count {
                _ = queue.setValue(i, for: i, with: Double(i % 10))
            }
        }
    }

    /// Measures priority-based eviction performance under load.
    func testPriorityEvictionPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 1000)
        measure {
            for i in 0..<count {
                _ = queue.setValue(i, for: i, with: Double(i % 100))
            }
        }
    }

    /// Measures performance of a mixed workload (insert, get, remove).
    func testMixedWorkloadPerformance() {
        let count = 10_000
        let queue = PriorityLRUQueue<Int, Int>(capacity: 2000)
        measure {
            for i in 0..<count {
                _ = queue.setValue(i, for: i, with: Double(i % 10))
                _ = queue.getValue(for: i)
                if i % 3 == 0 {
                    _ = queue.removeValue(for: i - 1)
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
                _ = queue.setValue(i, for: "key\(i)", with: Double(i % 2))
                _ = queue.getValue(for: "key\(i)")
                _ = queue.removeValue(for: "key\(i)")
            }
        }
    }
    /// Measures performance for queue with capacity 2.
    func testSmallCapacity2Performance() {
        let cap = 2
        let queue = PriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = queue.setValue(i, for: "key\(i)", with: Double(i % 2))
                _ = queue.getValue(for: "key\(i)")
                _ = queue.removeValue(for: "key\(i)")
            }
        }
    }
    /// Measures performance for queue with capacity 10.
    func testSmallCapacity10Performance() {
        let cap = 10
        let queue = PriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = queue.setValue(i, for: "key\(i)", with: Double(i % 2))
                _ = queue.getValue(for: "key\(i)")
                _ = queue.removeValue(for: "key\(i)")
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
                    _ = queue.setValue("val\(inserted)", for: inserted, with: Double(inserted % 10))
                    inserted += 1
                } else if op == 1 {
                    _ = queue.getValue(for: Int.random(in: 0..<count))
                } else if removed < inserted {
                    _ = queue.removeValue(for: removed)
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
            _ = queue.setValue(i, for: i, with: Double(i % 10))
        }
        var keys = Array(0..<count)
        keys.shuffle()
        var removeIdx = 0
        measure {
            while queue.count > 0 && removeIdx < keys.count {
                let key = keys[removeIdx]
                _ = queue.removeValue(for: key)
                removeIdx += 1
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
                _ = queue.setValue(i, for: i, with: Double(i % 10))
                if i % 2 == 0 {
                    _ = queue.removeValue(for: i - 1)
                }
            }
        }
    }
} 