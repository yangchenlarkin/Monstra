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
} 