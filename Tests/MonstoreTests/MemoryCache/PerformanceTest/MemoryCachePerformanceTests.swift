//
//  MemoryCachePerformanceTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/15.
//
//  Performance tests for MemoryCache: measures throughput and latency for bulk operations,
//  expiration, eviction, and mixed workloads under load.

import XCTest
@testable import Monstore

/// Performance tests for MemoryCache.
final class MemoryCachePerformanceTests: XCTestCase {
    /// Measures bulk insertion and retrieval throughput.
    func testBulkInsertAndRetrievePerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: count)))
        measure {
            for i in 0..<count {
                cache.set(value: i, for: i)
            }
            for i in 0..<count {
                _ = cache.getValue(for: i)
            }
        }
    }

    /// Measures expiration performance under load.
    func testExpirationPerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: count)))
        for i in 0..<count {
            cache.set(value: i, for: i, expiredIn: 0.01)
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
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: 1000)))
        measure {
            for i in 0..<count {
                cache.set(value: i, for: i, priority: Double(i % 10))
            }
        }
    }

    /// Measures LRU eviction performance under load.
    func testLRUEvictionPerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: 1000)))
        for i in 0..<1000 {
            cache.set(value: i, for: i)
        }
        measure {
            for i in 1000..<count {
                cache.set(value: i, for: i)
            }
        }
    }

    /// Measures performance of a mixed workload (insert, get, remove).
    func testMixedWorkloadPerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: 2000)))
        measure {
            for i in 0..<count {
                cache.set(value: i, for: i)
                _ = cache.getValue(for: i)
                if i % 3 == 0 {
                    _ = cache.removeValue(for: i - 1)
                }
            }
        }
    }

    // MARK: - New Function Performance Tests

    /// Measures performance of removing least recently used values.
    func testRemoveValuePerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: count)))
        
        // Pre-populate cache
        for i in 0..<count {
            cache.set(value: i, for: i)
        }
        
        measure {
            // Remove all values using removeValue()
            while !cache.isEmpty {
                _ = cache.removeValue()
            }
        }
    }

    /// Measures performance of removing expired values.
    func testRemoveExpiredValuesPerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: count)))
        
        // Add values with short TTL
        for i in 0..<count {
            cache.set(value: i, for: i, expiredIn: 0.01)
        }
        
        // Wait for expiration
        sleep(1)
        
        measure {
            cache.removeExpiredValues()
        }
    }

    /// Measures performance of removing values to reach target percentage.
    func testRemoveValuesToPercentPerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: count)))
        
        // Pre-populate cache
        for i in 0..<count {
            cache.set(value: i, for: i)
        }
        
        measure {
            // Test different percentage reductions
            cache.removeValues(toPercent: 0.8) // Remove to 80%
            cache.removeValues(toPercent: 0.5) // Remove to 50%
            cache.removeValues(toPercent: 0.2) // Remove to 20%
            cache.removeValues(toPercent: 0.0) // Remove to 0%
        }
    }

    /// Measures performance of mixed cache operations including new functions.
    func testMixedCacheOperationsPerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: 2000)))
        
        measure {
            for i in 0..<count {
                cache.set(value: i, for: i, expiredIn: i % 2 == 0 ? 0.01 : 1000)
                _ = cache.getValue(for: i)
                
                if i % 5 == 0 {
                    _ = cache.removeValue() // Remove LRU
                }
                
                if i % 10 == 0 {
                    cache.removeExpiredValues() // Remove expired
                }
                
                if i % 20 == 0 {
                    cache.removeValues(toPercent: 0.8) // Reduce to 80%
                }
            }
        }
    }

    // MARK: - Small Capacity Edge Case Performance

    /// Measures performance for cache with capacity 1.
    func testSmallCapacity1Performance() {
        let cap = 1
        let cache = MemoryCache<String, Int>(configuration: .init(usageLimitation: .init(capacity: cap)))
        measure {
            for i in 0..<(cap * 1000) {
                cache.set(value: i, for: "key\(i)")
                _ = cache.getValue(for: "key\(i)")
                _ = cache.removeValue(for: "key\(i)")
            }
        }
    }

    /// Measures performance for cache with capacity 10.
    func testSmallCapacity10Performance() {
        let cap = 10
        let cache = MemoryCache<String, Int>(configuration: .init(usageLimitation: .init(capacity: cap)))
        measure {
            for i in 0..<(cap * 1000) {
                cache.set(value: i, for: "key\(i)")
                _ = cache.getValue(for: "key\(i)")
                _ = cache.removeValue(for: "key\(i)")
            }
        }
    }

    // MARK: - Randomized Workload Performance

    /// Measures performance under a randomized insert/get/remove workload.
    func testRandomizedWorkloadPerformance() {
        let count = 10_000
        let cache = MemoryCache<Int, String>(configuration: .init(usageLimitation: .init(capacity: 1000)))
        var inserted = 0
        var removed = 0
        measure {
            for _ in 0..<(count * 2) {
                let op = Int.random(in: 0..<4)
                if op == 0 && inserted < count {
                    cache.set(value: "val\(inserted)", for: inserted)
                    inserted += 1
                } else if op == 1 {
                    _ = cache.getValue(for: Int.random(in: 0..<count))
                } else if op == 2 && removed < inserted {
                    _ = cache.removeValue(for: removed)
                    removed += 1
                } else if op == 3 {
                    _ = cache.removeValue() // Remove LRU
                }
            }
        }
    }

    // MARK: - Stress/Long-Running Performance

    /// Measures performance under long-running, high-churn workload.
    func testStressLongRunningPerformance() {
        let count = 50_000
        let cache = MemoryCache<Int, Int>(configuration: .init(usageLimitation: .init(capacity: 1000)))
        measure {
            for i in 0..<count {
                cache.set(value: i, for: i, expiredIn: i % 3 == 0 ? 0.01 : 1000)
                if i % 2 == 0 {
                    _ = cache.removeValue(for: i - 1)
                }
                if i % 100 == 0 {
                    cache.removeExpiredValues()
                }
                if i % 500 == 0 {
                    cache.removeValues(toPercent: 0.8)
                }
            }
        }
    }
} 