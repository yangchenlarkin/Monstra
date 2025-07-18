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

// MARK: - Small Capacity Edge Case Performance
    /// Measures performance for cache with capacity 1.
    func testSmallCapacity1Performance() {
        let cap = 1
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = cache.set(value: i, for: "key\(i)", expiredIn: 1000)
                _ = cache.getValue(for: "key\(i)")
                _ = cache.removeValue(for: "key\(i)")
            }
        }
    }
    /// Measures performance for cache with capacity 2.
    func testSmallCapacity2Performance() {
        let cap = 2
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = cache.set(value: i, for: "key\(i)", expiredIn: 1000)
                _ = cache.getValue(for: "key\(i)")
                _ = cache.removeValue(for: "key\(i)")
            }
        }
    }
    /// Measures performance for cache with capacity 10.
    func testSmallCapacity10Performance() {
        let cap = 10
        let cache = TTLPriorityLRUQueue<String, Int>(capacity: cap)
        measure {
            for i in 0..<(cap * 1000) {
                _ = cache.set(value: i, for: "key\(i)", expiredIn: 1000)
                _ = cache.getValue(for: "key\(i)")
                _ = cache.removeValue(for: "key\(i)")
            }
        }
    }

// MARK: - Randomized Workload Performance
    /// Measures performance under a randomized insert/get/remove workload.
    func testRandomizedWorkloadPerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, String>(capacity: 1000)
        var inserted = 0
        var removed = 0
        measure {
            for _ in 0..<(count * 2) {
                let op = Int.random(in: 0..<3)
                if op == 0 && inserted < count {
                    _ = cache.set(value: "val\(inserted)", for: inserted, expiredIn: 1000)
                    inserted += 1
                } else if op == 1 {
                    _ = cache.getValue(for: Int.random(in: 0..<count))
                } else if removed < inserted {
                    _ = cache.removeValue(for: removed)
                    removed += 1
                }
            }
        }
    }

// MARK: - Remove at Random Key Performance
    /// Measures performance of removing elements at random keys.
    func testRemoveAtRandomKeyPerformance() {
        let count = 5000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: count)
        for i in 0..<count {
            _ = cache.set(value: i, for: i, expiredIn: 1000)
        }
        var keys = Array(0..<count)
        keys.shuffle()
        var removeIdx = 0
        measure {
            while cache.count > 0 && removeIdx < keys.count {
                let key = keys[removeIdx]
                _ = cache.removeValue(for: key)
                removeIdx += 1
            }
        }
    }

// MARK: - Expired Entries Under High Churn
    /// Measures performance when many entries are expired under high churn.
    func testExpiredEntriesHighChurnPerformance() {
        let count = 5000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 1000)
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

    // MARK: - Remove Expired Values Performance Tests

    /// Measures performance of removing expired values.
    func testRemoveExpiredValuesPerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: count)
        
        // Add values with short TTL
        for i in 0..<count {
            _ = cache.set(value: i, for: i, expiredIn: 0.01)
        }
        
        // Wait for expiration
        sleep(1)
        
        measure {
            cache.removeExpiredValues()
        }
    }

    /// Measures performance of mixed workload including removeExpiredValues().
    func testMixedWorkloadWithExpirationPerformance() {
        let count = 10_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 2000)
        measure {
            for i in 0..<count {
                _ = cache.set(value: i, for: i, expiredIn: i % 2 == 0 ? 0.01 : 1000)
                _ = cache.getValue(for: i)
                if i % 3 == 0 {
                    _ = cache.removeValue(for: i - 1)
                }
                if i % 10 == 0 {
                    cache.removeExpiredValues() // Remove expired
                }
            }
        }
    }

    // MARK: - Stress/Long-Running Performance
    /// Measures performance under long-running, high-churn workload.
    func testStressLongRunningPerformance() {
        let count = 50_000
        let cache = TTLPriorityLRUQueue<Int, Int>(capacity: 1000)
        measure {
            for i in 0..<count {
                _ = cache.set(value: i, for: i, expiredIn: 1000)
                if i % 2 == 0 {
                    _ = cache.removeValue(for: i - 1)
                }
                if i % 100 == 0 {
                    cache.removeExpiredValues() // Remove expired
                }
            }
        }
    }
} 