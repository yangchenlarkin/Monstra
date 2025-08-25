//
//  CPUTimeStampTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/5/10.
//

import XCTest
@testable import MonstraBase

final class CPUTimeStampTests: XCTestCase {
    
    // MARK: - Basic Initialization Tests
    
    func testCPUTimeStampInit() {
        let timestamp = CPUTimeStamp()
        XCTAssertGreaterThan(timestamp.timeIntervalSinceCPUStart(), 0, "Timestamp should be positive")
    }
    
    func testCPUTimeStampNow() {
        let timestamp1 = CPUTimeStamp.now()
        let timestamp2 = CPUTimeStamp.now()
        
        XCTAssertGreaterThanOrEqual(timestamp2.timeIntervalSinceCPUStart(), timestamp1.timeIntervalSinceCPUStart(), "Second timestamp should be greater than or equal to first")
    }
    
    func testCPUTimeStampZero() {
        let zero = CPUTimeStamp.zero
        XCTAssertEqual(zero.timeIntervalSinceCPUStart(), 0.0, "Zero timestamp should have zero seconds")
    }
    
    func testCPUTimeStampInfinity() {
        let infinity = CPUTimeStamp.infinity
        XCTAssertEqual(infinity.timeIntervalSinceCPUStart(), TimeInterval.infinity, "Infinity timestamp should have infinite seconds")
    }
    
    // MARK: - Comparison Tests
    
    func testCPUTimeStampComparison() {
        let timestamp1 = CPUTimeStamp.now()
        Thread.sleep(forTimeInterval: 0.001) // Small delay
        let timestamp2 = CPUTimeStamp.now()
        
        XCTAssertLessThan(timestamp1, timestamp2, "First timestamp should be less than second")
        XCTAssertGreaterThan(timestamp2, timestamp1, "Second timestamp should be greater than first")
        XCTAssertEqual(timestamp1, timestamp1, "Same timestamp should be equal")
    }
    
    func testCPUTimeStampComparisonWithInfinity() {
        let timestamp = CPUTimeStamp.now()
        let infinity = CPUTimeStamp.infinity
        
        XCTAssertLessThan(timestamp, infinity, "Regular timestamp should be less than infinity")
        XCTAssertGreaterThan(infinity, timestamp, "Infinity should be greater than regular timestamp")
    }
    
    func testCPUTimeStampComparisonWithZero() {
        let timestamp = CPUTimeStamp.now()
        let zero = CPUTimeStamp.zero
        
        XCTAssertGreaterThan(timestamp, zero, "Regular timestamp should be greater than zero")
        XCTAssertLessThan(zero, timestamp, "Zero should be less than regular timestamp")
    }
    
    // MARK: - Arithmetic Operations Tests
    
    func testCPUTimeStampAddition() {
        let timestamp = CPUTimeStamp.now()
        let interval: TimeInterval = 1.5
        let result = timestamp + interval
        
        XCTAssertEqual(result.timeIntervalSince(timestamp), interval, accuracy: 0.001, "Addition should work correctly")
    }
    
    func testCPUTimeStampSubtraction() {
        let timestamp = CPUTimeStamp.now()
        let interval: TimeInterval = 1.5
        let result = timestamp - interval
        
        XCTAssertEqual(timestamp.timeIntervalSince(result), interval, accuracy: 0.001, "Subtraction should work correctly")
    }
    
    func testCPUTimeStampSubtractionBetweenTimestamps() {
        let timestamp1 = CPUTimeStamp.now()
        Thread.sleep(forTimeInterval: 0.001) // Small delay
        let timestamp2 = CPUTimeStamp.now()
        
        let interval = timestamp2 - timestamp1
        XCTAssertGreaterThan(interval, 0, "Interval should be positive")
        
        let reverseInterval = timestamp1 - timestamp2
        XCTAssertLessThan(reverseInterval, 0, "Reverse interval should be negative")
    }
    
    func testCPUTimeStampTimeIntervalSince() {
        let timestamp1 = CPUTimeStamp.now()
        Thread.sleep(forTimeInterval: 0.001) // Small delay
        let timestamp2 = CPUTimeStamp.now()
        
        let interval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertGreaterThan(interval, 0, "Interval should be positive")
        
        let reverseInterval = timestamp1.timeIntervalSince(timestamp2)
        XCTAssertLessThan(reverseInterval, 0, "Reverse interval should be negative")
    }
    
    // MARK: - Arithmetic Operations Tests
    
    func testCPUTimeStampArithmeticOperations() {
        let timestamp1 = CPUTimeStamp.now()
        let interval: TimeInterval = 1.0
        let timestamp2 = timestamp1 + interval
        
        // Test arithmetic operations
        let actualInterval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertEqual(actualInterval, interval, accuracy: 0.001, "Arithmetic operations should work correctly")
    }
    
    func testCPUTimeStampWithZeroInterval() {
        let timestamp1 = CPUTimeStamp.now()
        let timestamp2 = timestamp1 + 0.0
        
        // Adding zero should not change the timestamp
        XCTAssertEqual(timestamp2.timeIntervalSince(timestamp1), 0.0, accuracy: 0.001, "Zero interval should work correctly")
    }
    
    func testCPUTimeStampWithSmallValues() {
        let timestamp1 = CPUTimeStamp.now()
        let smallInterval: TimeInterval = 0.001
        let timestamp2 = timestamp1 + smallInterval
        
        let actualInterval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertEqual(actualInterval, smallInterval, accuracy: 0.0001, "Small values should work correctly")
    }
    
    func testCPUTimeStampWithLargeValues() {
        let timestamp1 = CPUTimeStamp.now()
        let largeInterval: TimeInterval = 1000.0
        let timestamp2 = timestamp1 + largeInterval
        
        let actualInterval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertEqual(actualInterval, largeInterval, accuracy: 0.001, "Large values should work correctly")
    }
    
    func testCPUTimeStampWithNegativeValues() {
        let timestamp1 = CPUTimeStamp.now()
        let negativeInterval: TimeInterval = -1.0
        let timestamp2 = timestamp1 + negativeInterval
        
        let actualInterval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertEqual(actualInterval, negativeInterval, accuracy: 0.001, "Negative values should work correctly")
    }
    
    func testCPUTimeStampWithFractionalValues() {
        let timestamp1 = CPUTimeStamp.now()
        let fractionalInterval: TimeInterval = 1.5
        let timestamp2 = timestamp1 + fractionalInterval
        
        let actualInterval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertEqual(actualInterval, fractionalInterval, accuracy: 0.001, "Fractional values should work correctly")
    }
    
    func testCPUTimeStampWithVerySmallValues() {
        let timestamp1 = CPUTimeStamp.now()
        let verySmallInterval: TimeInterval = 0.000001 // 1 microsecond
        let timestamp2 = timestamp1 + verySmallInterval
        
        let actualInterval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertEqual(actualInterval, verySmallInterval, accuracy: 0.000001, "Very small values should work correctly")
    }
    
    func testCPUTimeStampWithVeryLargeValues() {
        let timestamp1 = CPUTimeStamp.now()
        let veryLargeInterval: TimeInterval = 1000000.0 // 1 million seconds
        let timestamp2 = timestamp1 + veryLargeInterval
        
        let actualInterval = timestamp2.timeIntervalSince(timestamp1)
        XCTAssertEqual(actualInterval, veryLargeInterval, accuracy: 0.001, "Very large values should work correctly")
    }
    
    func testCPUTimeStampWithInfinity() {
        let timestamp1 = CPUTimeStamp.now()
        let infinityInterval: TimeInterval = TimeInterval.infinity
        let timestamp2 = timestamp1 + infinityInterval
        
        // Should handle infinity gracefully
        XCTAssertEqual(timestamp2.timeIntervalSinceCPUStart(), TimeInterval.infinity, "Infinity should be preserved")
    }
    
    func testCPUTimeStampWithNegativeInfinity() {
        let timestamp1 = CPUTimeStamp.now()
        let negativeInfinityInterval: TimeInterval = -TimeInterval.infinity
        let timestamp2 = timestamp1 + negativeInfinityInterval
        
        // Should handle negative infinity gracefully
        XCTAssertEqual(timestamp2.timeIntervalSinceCPUStart(), -TimeInterval.infinity, "Negative infinity should be preserved")
    }
    
    func testCPUTimeStampWithNaN() {
        let timestamp1 = CPUTimeStamp.now()
        let nanInterval: TimeInterval = TimeInterval.nan
        let timestamp2 = timestamp1 + nanInterval
        
        // Should handle NaN gracefully
        XCTAssertTrue(timestamp2.timeIntervalSinceCPUStart().isNaN, "NaN should be preserved")
    }
    
    func testCPUTimeStampWithMaxValues() {
        let timestamp1 = CPUTimeStamp.now()
        let maxInterval: TimeInterval = TimeInterval.greatestFiniteMagnitude
        let timestamp2 = timestamp1 + maxInterval
        
        // Should handle maximum values gracefully
        XCTAssertGreaterThan(timestamp2.timeIntervalSinceCPUStart(), timestamp1.timeIntervalSinceCPUStart(), "Maximum values should work correctly")
    }
    
    func testCPUTimeStampWithMinValues() {
        let timestamp1 = CPUTimeStamp.now()
        let minInterval: TimeInterval = -TimeInterval.greatestFiniteMagnitude
        let timestamp2 = timestamp1 + minInterval
        
        // Should handle minimum values gracefully
        XCTAssertLessThan(timestamp2.timeIntervalSinceCPUStart(), timestamp1.timeIntervalSinceCPUStart(), "Minimum values should work correctly")
    }
    
    func testCPUTimeStampPrecision() {
        let testValues: [TimeInterval] = [0.1, 0.01, 0.001, 0.0001, 0.00001]
        
        for interval in testValues {
            let timestamp1 = CPUTimeStamp.now()
            let timestamp2 = timestamp1 + interval
            let actualInterval = timestamp2.timeIntervalSince(timestamp1)
            
            XCTAssertEqual(actualInterval, interval, accuracy: 0.000001, "Precision should be maintained for \(interval)")
        }
    }
    
    func testCPUTimeStampRoundTrip() {
        let originalTimestamp = CPUTimeStamp.now()
        let interval: TimeInterval = 1.0
        let timestamp2 = originalTimestamp + interval
        let actualInterval = timestamp2.timeIntervalSince(originalTimestamp)
        
        // Should be close to original (allowing for rounding)
        XCTAssertEqual(actualInterval, interval, accuracy: 0.001, "Round trip should be accurate")
    }
    
    func testCPUTimeStampWithOverflowPrevention() {
        let veryLargeInterval: TimeInterval = 1e15 // Very large value
        let timestamp1 = CPUTimeStamp.now()
        let timestamp2 = timestamp1 + veryLargeInterval
        
        // Should not overflow
        XCTAssertGreaterThan(timestamp2.timeIntervalSinceCPUStart(), timestamp1.timeIntervalSinceCPUStart(), "Should handle very large values without overflow")
    }
    
    func testCPUTimeStampWithUnderflowPrevention() {
        let verySmallInterval: TimeInterval = 1e-15 // Very small value
        let timestamp1 = CPUTimeStamp.now()
        let timestamp2 = timestamp1 + verySmallInterval
        
        // Should handle very small values gracefully
        XCTAssertGreaterThanOrEqual(timestamp2.timeIntervalSinceCPUStart(), timestamp1.timeIntervalSinceCPUStart(), "Should handle very small values gracefully")
    }
    
    // MARK: - Edge Cases and Stress Tests
    
    func testCPUTimeStampHashable() {
        let timestamp1 = CPUTimeStamp.now()
        Thread.sleep(forTimeInterval: 0.001) // Ensure different timestamps
        let timestamp2 = CPUTimeStamp.now()
        Thread.sleep(forTimeInterval: 0.001) // Ensure different timestamps
        let timestamp3 = CPUTimeStamp.now()
        
        let set = Set([timestamp1, timestamp2, timestamp3])
        XCTAssertEqual(set.count, 3, "All timestamps should be unique in set")
    }
    
    func testCPUTimeStampEquatable() {
        let timestamp1 = CPUTimeStamp.now()
        let timestamp2 = CPUTimeStamp.now()
        
        XCTAssertEqual(timestamp1, timestamp1, "Same timestamp should be equal")
        XCTAssertNotEqual(timestamp1, timestamp2, "Different timestamps should not be equal")
    }
    
    func testCPUTimeStampWithArithmeticEdgeCases() {
        let timestamp = CPUTimeStamp.now()
        
        // Test with zero interval
        let result1 = timestamp + 0.0
        XCTAssertEqual(result1, timestamp, "Adding zero should not change timestamp")
        
        let result2 = timestamp - 0.0
        XCTAssertEqual(result2, timestamp, "Subtracting zero should not change timestamp")
        
        // Test with negative interval
        let result3 = timestamp + (-1.0)
        XCTAssertEqual(result3, timestamp - 1.0, "Adding negative should equal subtracting positive")
    }
    
    func testCPUTimeStampPerformance() {
        let iterations = 10000
        
        measure {
            for _ in 0..<iterations {
                let timestamp = CPUTimeStamp.now()
                let _ = timestamp.timeIntervalSinceCPUStart()
            }
        }
    }
    
    func testCPUTimeStampArithmeticPerformance() {
        let testValues: [TimeInterval] = [0.1, 1.0, 10.0, 100.0, 1000.0]
        
        measure {
            for interval in testValues {
                let timestamp1 = CPUTimeStamp.now()
                let _ = timestamp1 + interval
            }
        }
    }
    
    func testCPUTimeStampConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent timestamp creation")
        expectation.expectedFulfillmentCount = 100
        
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let timestamp = CPUTimeStamp.now()
            XCTAssertGreaterThan(timestamp.timeIntervalSinceCPUStart(), 0, "Timestamp should be valid")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCPUTimeStampTimebaseInfoConsistency() {
        // Test that timebase info is consistent across multiple calls
        let timestamp1 = CPUTimeStamp.now()
        let timestamp2 = CPUTimeStamp.now()
        
        // Both timestamps should use the same timebase info
        XCTAssertGreaterThan(timestamp2.timeIntervalSinceCPUStart(), timestamp1.timeIntervalSinceCPUStart(), "Timestamps should be monotonically increasing")
    }
}



