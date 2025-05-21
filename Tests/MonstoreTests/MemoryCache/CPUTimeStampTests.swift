//
//  CPUTimeStampTests.swift
//  
//
//  Created by Larkin on 2025/5/10.
//

import XCTest
@testable import Monstore

final class CPUTimeStampTests: XCTestCase {
    
    // MARK: - Basic Properties Tests
    
    func testZeroTimestamp() {
        let zero = CPUTimeStamp.zero
        XCTAssertEqual(zero.timeIntervalSinceCPUStart(), 0.0)
    }
    
    func testCurrentTimestamp() {
        let timestamp = CPUTimeStamp.now()
        XCTAssertGreaterThan(timestamp.timeIntervalSinceCPUStart(), 0.0)
    }
    
    // MARK: - Comparison Tests
    
    func testComparison() {
        let earlier = CPUTimeStamp.now()
        Thread.sleep(forTimeInterval: 0.001) // Small delay
        let later = CPUTimeStamp.now()
        
        XCTAssertLessThan(earlier, later)
        XCTAssertGreaterThan(later, earlier)
        XCTAssertNotEqual(earlier, later)
    }
    
    func testEqualityAndHashing() {
        let timestamp1 = CPUTimeStamp.zero
        let timestamp2 = CPUTimeStamp.zero
        
        XCTAssertEqual(timestamp1, timestamp2)
        XCTAssertEqual(timestamp1.hashValue, timestamp2.hashValue)
    }
    
    // MARK: - Arithmetic Operation Tests
    
    func testAddition() {
        let original = CPUTimeStamp.now()
        let interval: TimeInterval = 1.0
        let added = original + interval
        
        XCTAssertEqual(
            added.timeIntervalSinceCPUStart(),
            original.timeIntervalSinceCPUStart() + interval,
            accuracy: 0.0001
        )
    }
    
    func testSubtraction() {
        let original = CPUTimeStamp.now()
        let interval: TimeInterval = 1.0
        let subtracted = original - interval
        
        XCTAssertEqual(
            subtracted.timeIntervalSinceCPUStart(),
            original.timeIntervalSinceCPUStart() - interval,
            accuracy: 0.0001
        )
    }
    
    func testTimeIntervalBetweenTimestamps() {
        let start = CPUTimeStamp.now()
        Thread.sleep(forTimeInterval: 0.1)
        let end = CPUTimeStamp.now()
        
        let interval1 = end.timeIntervalSince(start)
        let interval2 = end - start
        
        XCTAssertEqual(interval1, interval2)
        XCTAssertGreaterThan(interval1, 0.09) // Allow for some timing variation
        XCTAssertLessThan(interval1, 0.2)     // Allow for some timing variation
    }
    
    // MARK: - Performance Tests
    
    func testTimestampCreationPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = CPUTimeStamp.now()
            }
        }
    }
    
    func testArithmeticOperationsPerformance() {
        let timestamp = CPUTimeStamp.now()
        measure {
            for i in 0..<10000 {
                _ = timestamp + TimeInterval(i)
                _ = timestamp - TimeInterval(i)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testVerySmallTimeIntervals() {
        let start = CPUTimeStamp.now()
        let end = start + 0.000001 // 1 microsecond
        
        XCTAssertGreaterThan(end, start)
        XCTAssertEqual(end - start, 0.000001, accuracy: 0.0000001)
    }
    
    func testLargeTimeIntervals() {
        let start = CPUTimeStamp.now()
        let end = start + 86400 // 1 day in seconds
        
        XCTAssertGreaterThan(end, start)
        XCTAssertEqual(end - start, 86400, accuracy: 0.0001)
    }
    
    // MARK: - Sequence Tests
    
    func testMonotonicityOfTimestamps() {
        var timestamps: [CPUTimeStamp] = []
        for _ in 0..<5 {
            timestamps.append(CPUTimeStamp.now())
            Thread.sleep(forTimeInterval: 0.001)
        }
        
        // Verify timestamps are strictly increasing
        for i in 0..<timestamps.count-1 {
            XCTAssertLessThan(timestamps[i], timestamps[i+1])
        }
    }
}

