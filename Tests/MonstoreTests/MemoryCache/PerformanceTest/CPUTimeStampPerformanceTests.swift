//
//  CPUTimeStampPerformanceTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/15.
//
//  Performance tests for CPUTimeStamp: measures overhead of timestamp creation, arithmetic, and comparison.

import XCTest
@testable import Monstore

/// Performance tests for CPUTimeStamp.
final class CPUTimeStampPerformanceTests: XCTestCase {
    /// Measures the overhead of creating timestamps with now().
    func testNowPerformance() {
        measure {
            for _ in 0..<100_000 {
                _ = CPUTimeStamp.now()
            }
        }
    }

    /// Measures performance of arithmetic operations (add, subtract).
    func testArithmeticPerformance() {
        let t0 = CPUTimeStamp.now()
        measure {
            var t = t0
            for _ in 0..<100_000 {
                t = t + 1.0
                t = t - 0.5
            }
        }
    }

    /// Measures performance of comparison operations.
    func testComparisonPerformance() {
        let t0 = CPUTimeStamp.now()
        let t1 = t0 + 1.0
        measure {
            for _ in 0..<100_000 {
                _ = t0 < t1
                _ = t1 > t0
                _ = t0 == t1
            }
        }
    }

// MARK: - Edge Case Performance
    /// Measures performance of operations with infinity and zero timestamps.
    func testEdgeCasePerformance() {
        let inf = CPUTimeStamp.infinity
        let zero = CPUTimeStamp.zero
        measure {
            for _ in 0..<100_000 {
                _ = inf > zero
                _ = zero < inf
                _ = inf == CPUTimeStamp.infinity
                _ = zero == CPUTimeStamp.zero
            }
        }
    }

// MARK: - Bulk Operations Performance
    /// Measures performance of bulk creation and mapping of timestamps.
    func testBulkCreationAndMappingPerformance() {
        measure {
            let arr = (0..<10_000).map { _ in CPUTimeStamp.now() }
            let mapped = arr.map { $0 + 1.0 }
            _ = mapped
        }
    }

// MARK: - Hashing Performance
    /// Measures performance of hashing timestamps for use in sets/dictionaries.
    func testHashingPerformance() {
        let arr = (0..<10_000).map { _ in CPUTimeStamp.now() }
        measure {
            var set = Set<CPUTimeStamp>()
            for t in arr {
                set.insert(t)
            }
        }
    }

// MARK: - Randomized Arithmetic/Comparison Performance
    /// Measures performance of randomized arithmetic and comparison operations.
    func testRandomizedArithmeticComparisonPerformance() {
        let arr = (0..<10_000).map { _ in CPUTimeStamp.now() }
        measure {
            for _ in 0..<10_000 {
                let i = Int.random(in: 0..<arr.count)
                let j = Int.random(in: 0..<arr.count)
                _ = arr[i] + Double(i)
                _ = arr[j] - Double(j)
                _ = arr[i] < arr[j]
                _ = arr[i] == arr[j]
            }
        }
    }
} 