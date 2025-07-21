//
//  CacheStatisticsTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/19.
//

import XCTest
@testable import Monstore

/// Tests for CacheStatistics functionality
final class CacheStatisticsTests: XCTestCase {
    
    var statistics: CacheStatistics!
    
    override func setUp() {
        super.setUp()
        statistics = CacheStatistics()
    }
    
    override func tearDown() {
        statistics = nil
        super.tearDown()
    }
    
    // MARK: - Basic Statistics Tests
    
    func testInitialState() {
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullElementHitCount, 0)
        XCTAssertEqual(statistics.nonNullElementHitCount, 0)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 0)
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
        XCTAssertGreaterThan(statistics.tracingID, 0)
        XCTAssertNil(statistics.report)
    }
    
    func testRecordInvalidKey() {
        statistics.record(.invalidKey)
        
        XCTAssertEqual(statistics.invalidKeyCount, 1)
        XCTAssertEqual(statistics.nullElementHitCount, 0)
        XCTAssertEqual(statistics.nonNullElementHitCount, 0)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 0.0) // No valid accesses
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    func testRecordNullElementHit() {
        statistics.record(.hitNullElement)
        
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullElementHitCount, 1)
        XCTAssertEqual(statistics.nonNullElementHitCount, 0)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 1.0)
        XCTAssertEqual(statistics.successRate, 1.0)
    }
    
    func testRecordNonNullElementHit() {
        statistics.record(.hitNonNullElement)
        
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullElementHitCount, 0)
        XCTAssertEqual(statistics.nonNullElementHitCount, 1)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 1.0)
        XCTAssertEqual(statistics.successRate, 1.0)
    }
    
    func testRecordMiss() {
        statistics.record(.miss)
        
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullElementHitCount, 0)
        XCTAssertEqual(statistics.nonNullElementHitCount, 0)
        XCTAssertEqual(statistics.missCount, 1)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    // MARK: - Report Callback Tests
    
    func testReportCallbackWithInvalidKey() {
        var reportedStatistics: CacheStatistics?
        var reportedResult: CacheRecord?
        
        statistics.report = { stats, result in
            reportedStatistics = stats
            reportedResult = result
        }
        
        statistics.record(.invalidKey)
        
        XCTAssertNotNil(reportedStatistics)
        XCTAssertEqual(reportedResult, .invalidKey)
        XCTAssertEqual(reportedStatistics?.invalidKeyCount, 1)
        XCTAssertEqual(reportedStatistics?.totalAccesses, 1)
    }
    
    func testReportCallbackWithHitNullElement() {
        var reportedStatistics: CacheStatistics?
        var reportedResult: CacheRecord?
        
        statistics.report = { stats, result in
            reportedStatistics = stats
            reportedResult = result
        }
        
        statistics.record(.hitNullElement)
        
        XCTAssertNotNil(reportedStatistics)
        XCTAssertEqual(reportedResult, .hitNullElement)
        XCTAssertEqual(reportedStatistics?.nullElementHitCount, 1)
        XCTAssertEqual(reportedStatistics?.totalAccesses, 1)
    }
    
    func testReportCallbackWithHitNonNullElement() {
        var reportedStatistics: CacheStatistics?
        var reportedResult: CacheRecord?
        
        statistics.report = { stats, result in
            reportedStatistics = stats
            reportedResult = result
        }
        
        statistics.record(.hitNonNullElement)
        
        XCTAssertNotNil(reportedStatistics)
        XCTAssertEqual(reportedResult, .hitNonNullElement)
        XCTAssertEqual(reportedStatistics?.nonNullElementHitCount, 1)
        XCTAssertEqual(reportedStatistics?.totalAccesses, 1)
    }
    
    func testReportCallbackWithMiss() {
        var reportedStatistics: CacheStatistics?
        var reportedResult: CacheRecord?
        
        statistics.report = { stats, result in
            reportedStatistics = stats
            reportedResult = result
        }
        
        statistics.record(.miss)
        
        XCTAssertNotNil(reportedStatistics)
        XCTAssertEqual(reportedResult, .miss)
        XCTAssertEqual(reportedStatistics?.missCount, 1)
        XCTAssertEqual(reportedStatistics?.totalAccesses, 1)
    }
    
    func testReportCallbackWithNilReport() {
        // Should not crash when report is nil
        statistics.report = nil
        
        statistics.record(.hitNullElement)
        statistics.record(.miss)
        statistics.record(.invalidKey)
        
        // Should still record statistics correctly
        XCTAssertEqual(statistics.totalAccesses, 3)
        XCTAssertEqual(statistics.nullElementHitCount, 1)
        XCTAssertEqual(statistics.missCount, 1)
        XCTAssertEqual(statistics.invalidKeyCount, 1)
    }
    
    func testReportCallbackWithMultipleRecords() {
        var callCount = 0
        var reportedResults: [CacheRecord] = []
        
        statistics.report = { stats, result in
            callCount += 1
            reportedResults.append(result)
        }
        
        statistics.record(.hitNullElement)
        statistics.record(.hitNonNullElement)
        statistics.record(.miss)
        statistics.record(.invalidKey)
        
        XCTAssertEqual(callCount, 4)
        XCTAssertEqual(reportedResults.count, 4)
        XCTAssertEqual(reportedResults[0], .hitNullElement)
        XCTAssertEqual(reportedResults[1], .hitNonNullElement)
        XCTAssertEqual(reportedResults[2], .miss)
        XCTAssertEqual(reportedResults[3], .invalidKey)
    }
    
    func testReportCallbackWithStatisticsUpdate() {
        var reportedTotalAccesses: [Int] = []
        
        statistics.report = { stats, result in
            reportedTotalAccesses.append(stats.totalAccesses)
        }
        
        statistics.record(.hitNullElement)
        statistics.record(.hitNonNullElement)
        statistics.record(.miss)
        
        XCTAssertEqual(reportedTotalAccesses.count, 3)
        XCTAssertEqual(reportedTotalAccesses[0], 1)
        XCTAssertEqual(reportedTotalAccesses[1], 2)
        XCTAssertEqual(reportedTotalAccesses[2], 3)
    }
    
    func testReportCallbackWithHitRateCalculation() {
        var reportedHitRates: [Double] = []
        
        statistics.report = { stats, result in
            reportedHitRates.append(stats.hitRate)
        }
        
        statistics.record(.hitNullElement) // 1.0
        statistics.record(.miss) // 0.5
        statistics.record(.hitNonNullElement) // 0.67
        
        XCTAssertEqual(reportedHitRates.count, 3)
        XCTAssertEqual(reportedHitRates[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(reportedHitRates[1], 0.5, accuracy: 0.01)
        XCTAssertEqual(reportedHitRates[2], 0.67, accuracy: 0.01)
    }
    
    func testReportCallbackWithSuccessRateCalculation() {
        var reportedSuccessRates: [Double] = []
        
        statistics.report = { stats, result in
            reportedSuccessRates.append(stats.successRate)
        }
        
        statistics.record(.hitNullElement) // 1.0
        statistics.record(.invalidKey) // 0.5
        statistics.record(.hitNonNullElement) // 0.67
        
        XCTAssertEqual(reportedSuccessRates.count, 3)
        XCTAssertEqual(reportedSuccessRates[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(reportedSuccessRates[1], 0.5, accuracy: 0.01)
        XCTAssertEqual(reportedSuccessRates[2], 0.67, accuracy: 0.01)
    }
    
    func testReportCallbackWithTracingID() {
        var reportedTracingIDs: [UInt64] = []
        
        statistics.report = { stats, result in
            reportedTracingIDs.append(stats.tracingID)
        }
        
        statistics.record(.hitNullElement)
        statistics.record(.miss)
        
        XCTAssertEqual(reportedTracingIDs.count, 2)
        XCTAssertEqual(reportedTracingIDs[0], reportedTracingIDs[1]) // Same tracing ID
        XCTAssertGreaterThan(reportedTracingIDs[0], 0)
    }
    
    func testReportCallbackAfterReset() {
        var callCount = 0
        
        statistics.report = { stats, result in
            callCount += 1
        }
        
        statistics.record(.hitNullElement)
        statistics.reset()
        statistics.record(.miss)
        
        XCTAssertEqual(callCount, 2) // Should be called for both records
    }
    
    func testReportCallbackWithConcurrentAccess() {
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        var callCount = 0
        let lock = NSLock()
        
        statistics.report = { stats, result in
            lock.lock()
            callCount += 1
            lock.unlock()
        }
        
        // Concurrent record operations
        for _ in 0..<100 {
            group.enter()
            queue.async {
                self.statistics.record(.hitNullElement)
                group.leave()
            }
        }
        
        group.wait()
        
        // Should have called report for all operations
        XCTAssertEqual(callCount, 100)
    }
    
    // MARK: - Hit Rate Calculation Tests
    
    func testHitRateWithMixedResults() {
        // 2 hits, 1 miss, 1 invalid key
        statistics.record(.hitNullElement)
        statistics.record(.hitNonNullElement)
        statistics.record(.miss)
        statistics.record(.invalidKey)
        
        // Hit rate should be 2/3 = 0.6667 (excluding invalid key)
        XCTAssertEqual(statistics.hitRate, 0.6667, accuracy: 0.0001)
        // Success rate should be 2/4 = 0.50 (including invalid key)
        XCTAssertEqual(statistics.successRate, 0.50, accuracy: 0.0001)
    }
    
    func testHitRateWithOnlyInvalidKeys() {
        statistics.record(.invalidKey)
        statistics.record(.invalidKey)
        statistics.record(.invalidKey)
        
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    func testHitRateWithOnlyHits() {
        statistics.record(.hitNullElement)
        statistics.record(.hitNonNullElement)
        statistics.record(.hitNonNullElement)
        
        XCTAssertEqual(statistics.hitRate, 1.0)
        XCTAssertEqual(statistics.successRate, 1.0)
    }
    
    func testHitRateWithOnlyMisses() {
        statistics.record(.miss)
        statistics.record(.miss)
        statistics.record(.miss)
        
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    func testHitRateWithEqualHitsAndMisses() {
        statistics.record(.hitNullElement)
        statistics.record(.hitNonNullElement)
        statistics.record(.miss)
        statistics.record(.miss)
        
        XCTAssertEqual(statistics.hitRate, 0.50)
        XCTAssertEqual(statistics.successRate, 0.50)
    }
    
    // MARK: - Reset Functionality Tests
    
    func testReset() {
        // Add some statistics
        statistics.record(.hitNullElement)
        statistics.record(.hitNonNullElement)
        statistics.record(.miss)
        statistics.record(.invalidKey)
        
        // Verify they were recorded
        XCTAssertEqual(statistics.totalAccesses, 4)
        let originalTracingID = statistics.tracingID
        
        // Reset
        statistics.reset()
        
        // Verify everything is reset
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullElementHitCount, 0)
        XCTAssertEqual(statistics.nonNullElementHitCount, 0)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 0)
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
        
        // Tracing ID should be updated
        XCTAssertNotEqual(statistics.tracingID, originalTracingID)
        XCTAssertGreaterThan(statistics.tracingID, 0)
    }
    
    func testResetMultipleTimes() {
        // Record some data
        statistics.record(.hitNullElement)
        statistics.record(.miss)
        
        // Reset multiple times
        statistics.reset()
        statistics.reset()
        statistics.reset()
        
        // Should still be reset
        XCTAssertEqual(statistics.totalAccesses, 0)
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    // MARK: - Total Accesses Calculation Tests
    
    func testTotalAccessesCalculation() {
        XCTAssertEqual(statistics.totalAccesses, 0)
        
        statistics.record(.invalidKey)
        XCTAssertEqual(statistics.totalAccesses, 1)
        
        statistics.record(.hitNullElement)
        XCTAssertEqual(statistics.totalAccesses, 2)
        
        statistics.record(.hitNonNullElement)
        XCTAssertEqual(statistics.totalAccesses, 3)
        
        statistics.record(.miss)
        XCTAssertEqual(statistics.totalAccesses, 4)
    }
    
    func testTotalAccessesWithLargeNumbers() {
        // Add large numbers of each type
        for _ in 0..<1000 {
            statistics.record(.hitNullElement)
        }
        for _ in 0..<500 {
            statistics.record(.hitNonNullElement)
        }
        for _ in 0..<300 {
            statistics.record(.miss)
        }
        for _ in 0..<200 {
            statistics.record(.invalidKey)
        }
        
        XCTAssertEqual(statistics.totalAccesses, 2000)
        XCTAssertEqual(statistics.invalidKeyCount, 200)
        XCTAssertEqual(statistics.nullElementHitCount, 1000)
        XCTAssertEqual(statistics.nonNullElementHitCount, 500)
        XCTAssertEqual(statistics.missCount, 300)
    }
    
    // MARK: - Edge Cases Tests
    
    func testLargeNumberOfRecords() {
        // Record 1000 of each type
        for _ in 0..<1000 {
            statistics.record(.hitNullElement)
            statistics.record(.hitNonNullElement)
            statistics.record(.miss)
            statistics.record(.invalidKey)
        }
        
        XCTAssertEqual(statistics.totalAccesses, 4000)
        XCTAssertEqual(statistics.hitRate, 0.6666, accuracy: 0.0001) // 2000 hits / 3000 valid accesses
        XCTAssertEqual(statistics.successRate, 0.50, accuracy: 0.0001) // 2000 hits / 4000 total accesses
    }
    
    func testPerformanceWithManyRecords() {
        measure {
            statistics.reset()
            for _ in 0..<10000 {
                statistics.record(.hitNonNullElement)
            }
        }
        
        XCTAssertEqual(statistics.totalAccesses, 10000)
        XCTAssertEqual(statistics.hitRate, 1.0)
    }
    
    // MARK: - Percentage Calculation Tests
    
    func testPercentageCalculation() {
        // 25% each type
        for _ in 0..<250 {
            statistics.record(.hitNullElement)
            statistics.record(.hitNonNullElement)
            statistics.record(.miss)
            statistics.record(.invalidKey)
        }
        
        XCTAssertEqual(statistics.totalAccesses, 1000)
        XCTAssertEqual(statistics.hitRate, 0.6667, accuracy: 0.0001) // 500 hits / 750 valid accesses
        XCTAssertEqual(statistics.successRate, 0.50, accuracy: 0.0001) // 500 hits / 1000 total accesses
    }
    
    func testPercentageCalculationWithZeroValidAccesses() {
        // Only invalid keys
        for _ in 0..<100 {
            statistics.record(.invalidKey)
        }
        
        XCTAssertEqual(statistics.totalAccesses, 100)
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    func testPercentageCalculationWithOnlyHits() {
        // Only hits
        for _ in 0..<100 {
            statistics.record(.hitNullElement)
            statistics.record(.hitNonNullElement)
        }
        
        XCTAssertEqual(statistics.totalAccesses, 200)
        XCTAssertEqual(statistics.hitRate, 1.0)
        XCTAssertEqual(statistics.successRate, 1.0)
    }
    
    // MARK: - Tracing ID Tests
    
    func testTracingIDGeneration() {
        let originalTracingID = statistics.tracingID
        XCTAssertGreaterThan(originalTracingID, 0)
        
        // Create another instance
        let newStatistics = CacheStatistics()
        XCTAssertGreaterThan(newStatistics.tracingID, 0)
        
        // IDs should be different
        XCTAssertNotEqual(originalTracingID, newStatistics.tracingID)
    }
    
    func testTracingIDAfterReset() {
        let originalTracingID = statistics.tracingID
        statistics.reset()
        let newTracingID = statistics.tracingID
        
        XCTAssertNotEqual(originalTracingID, newTracingID)
        XCTAssertGreaterThan(newTracingID, 0)
    }
    
    // MARK: - CacheRecord Enum Tests
    
    func testCacheRecordEnum() {
        // Test all enum cases exist
        let invalidKey: CacheRecord = .invalidKey
        let hitNullElement: CacheRecord = .hitNullElement
        let hitNonNullElement: CacheRecord = .hitNonNullElement
        let miss: CacheRecord = .miss
        
        XCTAssertNotNil(invalidKey)
        XCTAssertNotNil(hitNullElement)
        XCTAssertNotNil(hitNonNullElement)
        XCTAssertNotNil(miss)
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsage() {
        // Test that statistics don't grow indefinitely
        _ = MemoryLayout<CacheStatistics>.size
        
        // Create many instances
        var statisticsArray: [CacheStatistics] = []
        for _ in 0..<1000 {
            statisticsArray.append(CacheStatistics())
        }
        
        // Memory usage should be reasonable
        XCTAssertLessThan(statisticsArray.count * MemoryLayout<CacheStatistics>.size, 1000000)
    }
}
