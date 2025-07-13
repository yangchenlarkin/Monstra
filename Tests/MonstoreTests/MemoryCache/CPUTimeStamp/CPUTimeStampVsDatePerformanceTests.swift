//
//  CPUTimeStampVsDatePerformanceTests.swift
//  MonstoreTests
//
//  Created on 2024-12-19.
//

import XCTest
import Foundation
@testable import Monstore

final class CPUTimeStampVsDatePerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var cpuTimeStamp: CPUTimeStamp!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        cpuTimeStamp = CPUTimeStamp()
    }
    
    override func tearDown() {
        cpuTimeStamp = nil
        super.tearDown()
    }
    
    // MARK: - Creation Performance Tests
    
    func testCreationPerformance_CPUTimeStamp() {
        measure {
            for _ in 0..<10000 {
                _ = CPUTimeStamp()
            }
        }
    }
    
    func testCreationPerformance_Date() {
        measure {
            for _ in 0..<10000 {
                _ = Date()
            }
        }
    }
    
    // MARK: - Time Measurement Performance Tests
    
    func testTimeMeasurementPerformance_CPUTimeStamp() {
        measure {
            for _ in 0..<1000 {
                let start = CPUTimeStamp()
                // Simulate some work
                var sum = 0
                for i in 0..<1000 {
                    sum += i
                }
                let end = CPUTimeStamp()
                _ = end.timeIntervalSince(start)
            }
        }
    }
    
    func testTimeMeasurementPerformance_Date() {
        measure {
            for _ in 0..<1000 {
                let start = Date()
                // Simulate some work
                var sum = 0
                for i in 0..<1000 {
                    sum += i
                }
                let end = Date()
                _ = end.timeIntervalSince(start)
            }
        }
    }
    
    // MARK: - Precision Tests
    
    func testPrecision_CPUTimeStamp() {
        let iterations = 1000
        var measurements: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let start = CPUTimeStamp()
            let end = CPUTimeStamp()
            measurements.append(end.timeIntervalSince(start))
        }
        
        let minInterval = measurements.min() ?? 0
        let maxInterval = measurements.max() ?? 0
        let avgInterval = measurements.reduce(0, +) / Double(measurements.count)
        
        print("CPUTimeStamp precision test:")
        print("  Min interval: \(minInterval) seconds")
        print("  Max interval: \(maxInterval) seconds")
        print("  Avg interval: \(avgInterval) seconds")
        
        // CPUTimeStamp should have very high precision (microsecond level)
        XCTAssertLessThan(avgInterval, 0.0001) // Less than 0.1ms
    }
    
    func testPrecision_Date() {
        let iterations = 1000
        var measurements: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let start = Date()
            let end = Date()
            measurements.append(end.timeIntervalSince(start))
        }
        
        let minInterval = measurements.min() ?? 0
        let maxInterval = measurements.max() ?? 0
        let avgInterval = measurements.reduce(0, +) / Double(measurements.count)
        
        print("Date precision test:")
        print("  Min interval: \(minInterval) seconds")
        print("  Max interval: \(maxInterval) seconds")
        print("  Avg interval: \(avgInterval) seconds")
        
        // Date has lower precision (millisecond level)
        XCTAssertLessThan(avgInterval, 0.001) // Less than 1ms
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsage_CPUTimeStamp() {
        let initialMemory = getMemoryUsage()
        
        var timestamps: [CPUTimeStamp] = []
        for _ in 0..<10000 {
            timestamps.append(CPUTimeStamp())
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("CPUTimeStamp memory increase: \(memoryIncrease) bytes")
        XCTAssertLessThan(memoryIncrease, 1024 * 1024) // Less than 1MB
    }
    
    func testMemoryUsage_Date() {
        let initialMemory = getMemoryUsage()
        
        var dates: [Date] = []
        for _ in 0..<10000 {
            dates.append(Date())
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("Date memory increase: \(memoryIncrease) bytes")
        XCTAssertLessThan(memoryIncrease, 1024 * 1024) // Less than 1MB
    }
    
    // MARK: - Comparison Tests
    
    func testComparisonPerformance_CPUTimeStamp() {
        let timestamps = (0..<1000).map { _ in CPUTimeStamp() }
        
        measure {
            for i in 0..<timestamps.count - 1 {
                _ = timestamps[i] < timestamps[i + 1]
            }
        }
    }
    
    func testComparisonPerformance_Date() {
        let dates = (0..<1000).map { _ in Date() }
        
        measure {
            for i in 0..<dates.count - 1 {
                _ = dates[i].compare(dates[i + 1])
            }
        }
    }
    
    // MARK: - Arithmetic Operations Tests
    
    func testArithmeticOperations_CPUTimeStamp() {
        let timestamps = (0..<1000).map { _ in CPUTimeStamp() }
        
        measure {
            for i in 0..<timestamps.count - 1 {
                _ = timestamps[i + 1].timeIntervalSince(timestamps[i])
            }
        }
    }
    
    func testArithmeticOperations_Date() {
        let dates = (0..<1000).map { _ in Date() }
        
        measure {
            for i in 0..<dates.count - 1 {
                _ = dates[i + 1].timeIntervalSince(dates[i])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
} 