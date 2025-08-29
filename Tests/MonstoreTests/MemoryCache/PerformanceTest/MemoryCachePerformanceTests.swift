@testable import Monstra
import XCTest

/// Performance tests for MemoryCache.
final class MemoryCachePerformanceTests: XCTestCase {
    /// Measures bulk insertion and retrieval throughput.
    func testBulkInsertAndRetrievePerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: count)))
        measure {
            for i in 0 ..< count {
                cache.set(element: i, for: i)
            }
            for i in 0 ..< count {
                _ = cache.getElement(for: i)
            }
        }
    }

    /// Measures expiration performance under load.
    func testExpirationPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: count)))
        for i in 0 ..< count {
            cache.set(element: i, for: i, expiredIn: 0.01)
        }
        sleep(1)
        measure {
            for i in 0 ..< count {
                _ = cache.getElement(for: i)
            }
        }
    }

    /// Measures priority-based eviction performance under load.
    func testPriorityEvictionPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 1000)))
        measure {
            for i in 0 ..< count {
                cache.set(element: i, for: i, priority: Double(i % 10))
            }
        }
    }

    /// Measures LRU eviction performance under load.
    func testLRUEvictionPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 1000)))
        for i in 0 ..< 1000 {
            cache.set(element: i, for: i)
        }
        measure {
            for i in 1000 ..< count {
                cache.set(element: i, for: i)
            }
        }
    }

    /// Measures performance of a mixed workload (insert, get, remove).
    func testMixedWorkloadPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 2000)))
        measure {
            for i in 0 ..< count {
                cache.set(element: i, for: i)
                _ = cache.getElement(for: i)
                if i % 3 == 0 {
                    _ = cache.removeElement(for: i - 1)
                }
            }
        }
    }

    // MARK: - New Function Performance Tests

    /// Measures performance of removing least recently used elements.
    func testRemoveElementPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: count)))

        // Pre-populate cache
        for i in 0 ..< count {
            cache.set(element: i, for: i)
        }

        measure {
            // ✅ LIGHTWEIGHT DEAD LOOP PROTECTION (minimal performance impact)
            var removeAttempts = 0
            let maxAttempts = count * 2 // Safety limit to prevent infinite loops

            // Remove all elements using removeElement()
            while !cache.isEmpty, removeAttempts < maxAttempts {
                _ = cache.removeElement()
                removeAttempts += 1
            }

            // Quick verification after performance measurement
            XCTAssertTrue(
                cache.isEmpty || removeAttempts >= maxAttempts,
                "Cache should be empty or hit safety limit. count=\(cache.count), attempts=\(removeAttempts)"
            )
        }

        // ✅ POST-MEASUREMENT DIAGNOSTICS (outside measure block)
        if !cache.isEmpty {
            print("⚠️ DIAGNOSTIC: testRemoveElementPerformance did not complete normally")
            print("   - Cache count: \(cache.count)")
            print("   - Cache isEmpty: \(cache.isEmpty)")
            print("   - This suggests a potential infinite loop condition")
            XCTFail("Performance test hit safety limit - possible infinite loop detected")
        }
    }

    /// Measures performance of removing expired elements.
    func testRemoveExpiredElementsPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: count)))

        // Add elements with short TTL
        for i in 0 ..< count {
            cache.set(element: i, for: i, expiredIn: 0.01)
        }

        // Wait for expiration
        sleep(1)

        measure {
            cache.removeExpiredElements()
        }
    }

    /// Measures performance of removing elements to reach target percentage.
    func testRemoveElementsToPercentPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: count)))

        // Pre-populate cache
        for i in 0 ..< count {
            cache.set(element: i, for: i)
        }

        measure {
            // Test different percentage reductions
            cache.removeElements(toPercent: 0.8) // Remove to 80%
            cache.removeElements(toPercent: 0.5) // Remove to 50%
            cache.removeElements(toPercent: 0.2) // Remove to 20%
            cache.removeElements(toPercent: 0.0) // Remove to 0%
        }
    }

    /// Measures performance of mixed cache operations including new functions.
    func testMixedCacheOperationsPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 2000)))

        measure {
            for i in 0 ..< count {
                cache.set(element: i, for: i, expiredIn: i % 2 == 0 ? 0.01 : 1000)
                _ = cache.getElement(for: i)

                if i % 5 == 0 {
                    _ = cache.removeElement() // Remove LRU
                }

                if i % 10 == 0 {
                    cache.removeExpiredElements() // Remove expired
                }

                if i % 20 == 0 {
                    cache.removeElements(toPercent: 0.8) // Reduce to 80%
                }
            }
        }
    }

    // MARK: - Small Capacity Edge Case Performance

    /// Measures performance for cache with capacity 1.
    func testSmallCapacity1Performance() {
        let cap = 1
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: cap)))
        measure {
            for i in 0 ..< (cap * 1000) {
                cache.set(element: i, for: "key\(i)")
                _ = cache.getElement(for: "key\(i)")
                _ = cache.removeElement(for: "key\(i)")
            }
        }
    }

    /// Measures performance for cache with capacity 10.
    func testSmallCapacity10Performance() {
        let cap = 10
        let cache = MemoryCache<String, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: cap)))
        measure {
            for i in 0 ..< (cap * 1000) {
                cache.set(element: i, for: "key\(i)")
                _ = cache.getElement(for: "key\(i)")
                _ = cache.removeElement(for: "key\(i)")
            }
        }
    }

    // MARK: - Randomized Workload Performance

    /// Measures performance under a randomized insert/get/remove workload.
    func testRandomizedWorkloadPerformance() {
        let count = 10000
        let cache = MemoryCache<Int, String>(configuration: .init(memoryUsageLimitation: .init(capacity: 1000)))
        var inserted = 0
        var removed = 0
        measure {
            for _ in 0 ..< (count * 2) {
                let op = Int.random(in: 0 ..< 4)
                if op == 0, inserted < count {
                    cache.set(element: "val\(inserted)", for: inserted)
                    inserted += 1
                } else if op == 1 {
                    _ = cache.getElement(for: Int.random(in: 0 ..< count))
                } else if op == 2, removed < inserted {
                    _ = cache.removeElement(for: removed)
                    removed += 1
                } else if op == 3 {
                    _ = cache.removeElement() // Remove LRU
                }
            }
        }
    }

    // MARK: - Stress/Long-Running Performance

    /// Measures performance under long-running, high-churn workload.
    func testStressLongRunningPerformance() {
        let count = 50000
        let cache = MemoryCache<Int, Int>(configuration: .init(memoryUsageLimitation: .init(capacity: 1000)))
        measure {
            for i in 0 ..< count {
                cache.set(element: i, for: i, expiredIn: i % 3 == 0 ? 0.01 : 1000)
                if i % 2 == 0 {
                    _ = cache.removeElement(for: i - 1)
                }
                if i % 100 == 0 {
                    cache.removeExpiredElements()
                }
                if i % 500 == 0 {
                    cache.removeElements(toPercent: 0.8)
                }
            }
        }
    }
}
