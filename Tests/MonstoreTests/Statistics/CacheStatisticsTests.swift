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
        XCTAssertEqual(statistics.nullValueHitCount, 0)
        XCTAssertEqual(statistics.nonNullValueHitCount, 0)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 0)
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
        XCTAssertGreaterThan(statistics.tracingID, 0)
    }
    
    func testRecordInvalidKey() {
        statistics.record(.invalidKey)
        
        XCTAssertEqual(statistics.invalidKeyCount, 1)
        XCTAssertEqual(statistics.nullValueHitCount, 0)
        XCTAssertEqual(statistics.nonNullValueHitCount, 0)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 0.0) // No valid accesses
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    func testRecordNullValueHit() {
        statistics.record(.hitNullValue)
        
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullValueHitCount, 1)
        XCTAssertEqual(statistics.nonNullValueHitCount, 0)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 1.0)
        XCTAssertEqual(statistics.successRate, 1.0)
    }
    
    func testRecordNonNullValueHit() {
        statistics.record(.hitNonNullValue)
        
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullValueHitCount, 0)
        XCTAssertEqual(statistics.nonNullValueHitCount, 1)
        XCTAssertEqual(statistics.missCount, 0)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 1.0)
        XCTAssertEqual(statistics.successRate, 1.0)
    }
    
    func testRecordMiss() {
        statistics.record(.miss)
        
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullValueHitCount, 0)
        XCTAssertEqual(statistics.nonNullValueHitCount, 0)
        XCTAssertEqual(statistics.missCount, 1)
        XCTAssertEqual(statistics.totalAccesses, 1)
        XCTAssertEqual(statistics.hitRate, 0.0)
        XCTAssertEqual(statistics.successRate, 0.0)
    }
    
    // MARK: - Hit Rate Calculation Tests
    
    func testHitRateWithMixedResults() {
        // 2 hits, 1 miss, 1 invalid key
        statistics.record(.hitNullValue)
        statistics.record(.hitNonNullValue)
        statistics.record(.miss)
        statistics.record(.invalidKey)
        
        // Hit rate should be 2/3 = 66.67% (excluding invalid key)
        XCTAssertEqual(statistics.hitRate, 0.6667, accuracy: 0.0001)
        // Success rate should be 2/4 = 50% (including invalid key)
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
        statistics.record(.hitNullValue)
        statistics.record(.hitNonNullValue)
        statistics.record(.hitNonNullValue)
        
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
        statistics.record(.hitNullValue)
        statistics.record(.hitNonNullValue)
        statistics.record(.miss)
        statistics.record(.miss)
        
        XCTAssertEqual(statistics.hitRate, 0.50)
        XCTAssertEqual(statistics.successRate, 0.50)
    }
    
    // MARK: - Reset Functionality Tests
    
    func testReset() {
        // Add some statistics
        statistics.record(.hitNullValue)
        statistics.record(.hitNonNullValue)
        statistics.record(.miss)
        statistics.record(.invalidKey)
        
        // Verify they were recorded
        XCTAssertEqual(statistics.totalAccesses, 4)
        let originalTracingID = statistics.tracingID
        
        // Reset
        statistics.reset()
        
        // Verify everything is reset
        XCTAssertEqual(statistics.invalidKeyCount, 0)
        XCTAssertEqual(statistics.nullValueHitCount, 0)
        XCTAssertEqual(statistics.nonNullValueHitCount, 0)
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
        statistics.record(.hitNullValue)
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
        
        statistics.record(.hitNullValue)
        XCTAssertEqual(statistics.totalAccesses, 2)
        
        statistics.record(.hitNonNullValue)
        XCTAssertEqual(statistics.totalAccesses, 3)
        
        statistics.record(.miss)
        XCTAssertEqual(statistics.totalAccesses, 4)
    }
    
    func testTotalAccessesWithLargeNumbers() {
        // Add large numbers of each type
        for _ in 0..<1000 {
            statistics.record(.hitNullValue)
        }
        for _ in 0..<500 {
            statistics.record(.hitNonNullValue)
        }
        for _ in 0..<300 {
            statistics.record(.miss)
        }
        for _ in 0..<200 {
            statistics.record(.invalidKey)
        }
        
        XCTAssertEqual(statistics.totalAccesses, 2000)
        XCTAssertEqual(statistics.invalidKeyCount, 200)
        XCTAssertEqual(statistics.nullValueHitCount, 1000)
        XCTAssertEqual(statistics.nonNullValueHitCount, 500)
        XCTAssertEqual(statistics.missCount, 300)
    }
    
    // MARK: - Edge Cases Tests
    
    func testLargeNumberOfRecords() {
        // Record 1000 of each type
        for _ in 0..<1000 {
            statistics.record(.hitNullValue)
            statistics.record(.hitNonNullValue)
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
            for i in 0..<10000 {
                statistics.record(.hitNonNullValue)
            }
        }
        
        XCTAssertEqual(statistics.totalAccesses, 10000)
        XCTAssertEqual(statistics.hitRate, 1.0)
    }
    
    // MARK: - Percentage Calculation Tests
    
    func testPercentageCalculation() {
        // 25% each type
        for _ in 0..<250 {
            statistics.record(.hitNullValue)
            statistics.record(.hitNonNullValue)
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
            statistics.record(.hitNullValue)
            statistics.record(.hitNonNullValue)
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
    
    // MARK: - CacheResult Enum Tests
    
    func testCacheResultEnum() {
        // Test all enum cases exist
        let invalidKey: CacheResult = .invalidKey
        let hitNullValue: CacheResult = .hitNullValue
        let hitNonNullValue: CacheResult = .hitNonNullValue
        let miss: CacheResult = .miss
        
        XCTAssertNotNil(invalidKey)
        XCTAssertNotNil(hitNullValue)
        XCTAssertNotNil(hitNonNullValue)
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
