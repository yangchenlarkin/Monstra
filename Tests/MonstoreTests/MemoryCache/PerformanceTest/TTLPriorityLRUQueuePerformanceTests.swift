//
//  TTLPriorityLRUQueuePerformanceTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/15.
//
//  Performance tests for TTLPriorityLRUQueue: measures throughput and latency for bulk operations,
//  expiration, eviction, and mixed workloads under load.

import XCTest
@testable import Monstore

/// Performance tests for TTLPriorityLRUQueue.
final class TTLPriorityLRUQueuePerformanceTests: XCTestCase {
    /// Measures bulk insertion and retrieval throughput.
    func testBulkInsertAndRetrievePerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: count)
        measure {
            for i in 0..<count {
                _ = cache.set(value: i, for: i, expiredIn: 1000)
            }
            for i in 0..<count {
                _ = cache.getValue(for: i)
            }
        }
    }

    /// Measures expiration performance under load.
    func testExpirationPerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: count)
        for i in 0..<count {
            _ = cache.set(value: i, for: i, expiredIn: 0.01)
        }
        sleep(1)
        measure {
            for i in 0..<count {
                _ = cache.getValue(for: i)
            }
        }
    }

    /// Measures priority-based eviction performance under load.
    func testPriorityEvictionPerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 1000)
        measure {
            for i in 0..<count {
                _ = cache.set(value: i, for: i, priority: Double(i % 10), expiredIn: 1000)
            }
        }
    }

    /// Measures LRU eviction performance under load.
    func testLRUEvictionPerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 1000)
        for i in 0..<1000 {
            _ = cache.set(value: i, for: i, expiredIn: 1000)
        }
        measure {
            for i in 1000..<count {
                _ = cache.set(value: i, for: i, expiredIn: 1000)
            }
        }
    }

    /// Measures performance of a mixed workload (insert, get, remove).
    func testMixedWorkloadPerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 2000)
        measure {
            for i in 0..<count {
                _ = cache.set(value: i, for: i, expiredIn: 1000)
                _ = cache.getValue(for: i)
                if i % 3 == 0 {
                    _ = cache.removeValue(for: i - 1)
                }
            }
        }
    }
} 