//
//  HeapPerformanceTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/15.
//
//  Performance tests for Heap: measures throughput for bulk insertions, removals, and mixed workloads.

import XCTest
@testable import Monstore

/// Performance tests for Heap.
final class HeapPerformanceTests: XCTestCase {
    /// Measures bulk insertion throughput.
    func testBulkInsertPerformance() {
        let count = 100_000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        measure {
            for i in 0..<count {
                _ = heap.insert(i)
            }
        }
    }

    /// Measures bulk removal throughput.
    func testBulkRemovePerformance() {
        let count = 100_000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        for i in 0..<count {
            _ = heap.insert(i)
        }
        measure {
            for _ in 0..<count {
                _ = heap.remove()
            }
        }
    }

    /// Measures performance of a mixed insert/remove workload.
    func testMixedInsertRemovePerformance() {
        let count = 100_000
        let heap = Heap<Int>(capacity: count) { $0 - $1 < 0 ? .moreTop : .moreBottom }
        measure {
            for i in 0..<count {
                _ = heap.insert(i)
                if i % 2 == 0 {
                    _ = heap.remove()
                }
            }
        }
    }
} 