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
} 