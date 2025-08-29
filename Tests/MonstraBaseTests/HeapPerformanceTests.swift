@testable import Monstra
import XCTest

/// Performance tests for Heap.
final class HeapPerformanceTests: XCTestCase {
    /// Measures bulk insertion throughput.
    func testBulkInsertPerformance() {
        let count = 100_000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        measure {
            for i in 0 ..< count {
                _ = heap.insert(i)
            }
        }
    }

    /// Measures bulk removal throughput.
    func testBulkRemovePerformance() {
        let count = 100_000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        for i in 0 ..< count {
            _ = heap.insert(i)
        }
        measure {
            for _ in 0 ..< count {
                _ = heap.remove()
            }
        }
    }

    /// Measures performance of a mixed insert/remove workload.
    func testMixedInsertRemovePerformance() {
        let count = 100_000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        measure {
            for i in 0 ..< count {
                _ = heap.insert(i)
                if i % 2 == 0 {
                    _ = heap.remove()
                }
            }
        }
    }

    // MARK: - Force Insertion (Eviction) Performance

    /// Measures performance of force-inserting into a full heap (eviction path).
    func testForceInsertPerformance() {
        let capacity = 10000
        let heap = Heap<Int>(capacity: capacity) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        for i in 0 ..< capacity {
            _ = heap.insert(i)
        }
        measure {
            for i in capacity ..< (capacity * 2) {
                _ = heap.insert(i, force: true)
            }
        }
    }

    // MARK: - Small Capacity Edge Case Performance

    /// Measures performance for heap with capacity 1.
    func testSmallCapacity1Performance() {
        let cap = 1
        let heap = Heap<Int>(capacity: cap) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        measure {
            for i in 0 ..< (cap * 1000) {
                _ = heap.insert(i)
                _ = heap.remove()
            }
        }
    }

    /// Measures performance for heap with capacity 2.
    func testSmallCapacity2Performance() {
        let cap = 2
        let heap = Heap<Int>(capacity: cap) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        measure {
            for i in 0 ..< (cap * 1000) {
                _ = heap.insert(i)
                _ = heap.remove()
            }
        }
    }

    /// Measures performance for heap with capacity 10.
    func testSmallCapacity10Performance() {
        let cap = 10
        let heap = Heap<Int>(capacity: cap) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        measure {
            for i in 0 ..< (cap * 1000) {
                _ = heap.insert(i)
                _ = heap.remove()
            }
        }
    }

    // MARK: - MinHeap vs MaxHeap Performance

    /// Measures performance of min-heap and max-heap static initializers.
    func testMinMaxHeapPerformance() {
        let count = 50000
        let minHeap = Heap<Int>.minHeap(capacity: count)
        let maxHeap = Heap<Int>.maxHeap(capacity: count)
        measure {
            for i in 0 ..< count {
                _ = minHeap.insert(i)
                _ = maxHeap.insert(i)
            }
        }
    }

    // MARK: - Custom Comparator Performance

    /// Measures performance with a custom comparator (e.g., even numbers prioritized).
    func testCustomComparatorPerformance() {
        let count = 50000
        let heap = Heap<Int>(capacity: count) { a, b in
            // Even numbers are more top, then by value
            if a % 2 == 0 && b % 2 != 0 { return .moreTop }
            if a % 2 != 0 && b % 2 == 0 { return .moreBottom }
            if a < b { return .moreTop }
            if a > b { return .moreBottom }
            return .equal
        }
        measure {
            for i in 0 ..< count {
                _ = heap.insert(i)
            }
        }
    }

    // MARK: - Event Callback Overhead

    /// Measures the overhead of the onEvent callback during heap operations.
    func testEventCallbackOverhead() {
        let count = 10000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        heap.onEvent = { _ in /* Simulate event handling */ }
        measure {
            for i in 0 ..< count {
                _ = heap.insert(i)
            }
            for _ in 0 ..< count {
                _ = heap.remove()
            }
        }
    }

    // MARK: - Randomized Workload Performance

    /// Measures performance under a randomized insert/remove workload.
    func testRandomizedWorkloadPerformance() {
        let count = 50000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        var inserted = 0
        var removed = 0
        measure {
            for _ in 0 ..< (count * 2) {
                if Bool.random(), inserted < count {
                    _ = heap.insert(inserted)
                    inserted += 1
                } else if removed < inserted {
                    _ = heap.remove()
                    removed += 1
                }
            }
        }
    }

    // MARK: - Remove at Random Index Performance

    /// Measures performance of removing elements at random indices (non-root removals).
    func testRemoveAtRandomIndexPerformance() {
        let count = 50000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        for i in 0 ..< count {
            _ = heap.insert(i)
        }
        var indices = Array(0 ..< count)
        indices.shuffle()
        var removeIdx = 0
        measure {
            // Remove at random indices until heap is empty
            while heap.count > 0, removeIdx < indices.count {
                let idx = heap.count == 1 ? 0 : indices[removeIdx] % heap.count
                _ = heap.remove(at: idx)
                removeIdx += 1
            }
        }
    }
}
