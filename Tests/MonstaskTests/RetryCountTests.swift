//
//  RetryCountTests.swift
//  MonstaskTests
//
//  Created by Larkin on 2025/7/21.
//

import Foundation
import XCTest
@testable import Monstask

final class RetryCountTests: XCTestCase {
    
    // MARK: - Basic RetryCount Tests
    
    func testRetryCountInfinity() {
        let retryCount = RetryCount.infinity()
        XCTAssertEqual(retryCount.timeInterval, 0.0) // Default fixed interval
        
        let next = retryCount.next()
        XCTAssertEqual(next.timeInterval, 0.0) // Should remain fixed
    }
    
    func testRetryCountCount() {
        let retryCount = RetryCount.count(count: 3)
        XCTAssertEqual(retryCount.timeInterval, 0.0)
        
        let next1 = retryCount.next()
        XCTAssertEqual(next1.timeInterval, 0.0)
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 0.0)
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, nil) // Should be .never
    }
    
    func testRetryCountNever() {
        let retryCount = RetryCount.never
        XCTAssertEqual(retryCount.timeInterval, nil)
        
        let next = retryCount.next()
        XCTAssertEqual(next.timeInterval, nil) // Should remain .never
    }
    
    // MARK: - Integer Literal Tests
    
    func testRetryCountIntegerLiteral() {
        let retryCount: RetryCount = 5
        XCTAssertEqual(retryCount.timeInterval, 0.0)
        
        var current = retryCount
        for _ in 0..<4 {
            current = current.next()
            XCTAssertNotNil(current.timeInterval)
            XCTAssertEqual(current.timeInterval!, 0.0)
        }
        
        current = current.next()
        XCTAssertEqual(current.timeInterval, nil) // Should be .never
    }
    
    // MARK: - Fixed Interval Tests
    
    func testFixedInterval() {
        let interval = RetryCount.IntervalProxy.fixed(timeInterval: 2.5)
        XCTAssertEqual(interval.timeInterval, 2.5)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, 2.5) // Should remain the same
    }
    
    // MARK: - Exponential Backoff Tests
    
    func testExponentialBackoff() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next1 = interval.next()
        XCTAssertEqual(next1.timeInterval, 2.0) // 1.0 * 2.0
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 4.0) // 2.0 * 2.0
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 8.0) // 4.0 * 2.0
    }
    
    func testExponentialBackoffWithDifferentScaleRate() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 1.5)
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next1 = interval.next()
        XCTAssertEqual(next1.timeInterval, 1.5) // 1.0 * 1.5
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 2.25) // 1.5 * 1.5
    }
    
    func testExponentialBackoffWithScaleRateLessThanOne() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.5)
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next1 = interval.next()
        XCTAssertEqual(next1.timeInterval, 1.0)
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 1.0)
    }
    
    // MARK: - Exponential Backoff Before Fixed Tests
    
    func testExponentialBackoffBeforeFixed() {
        let interval = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            maxExponentialBackoffCount: 2,
            scaleRate: 2.0
        )
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next1 = interval.next()
        XCTAssertEqual(next1.timeInterval, 2.0) // Exponential backoff
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 4.0) // Exponential backoff
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 1.0) // Should be fixed now (original interval)
    }
    
    func testExponentialBackoffBeforeFixedWithZeroCount() {
        let interval = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            maxExponentialBackoffCount: 0,
            scaleRate: 2.0
        )
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, 1.0) // Should be fixed immediately
    }
    
    // MARK: - Exponential Backoff After Fixed Tests
    
    func testExponentialBackoffAfterFixed() {
        let interval = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            maxFixedCount: 2,
            scaleRate: 2.0
        )
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next1 = interval.next()
        XCTAssertEqual(next1.timeInterval, 1.0) // Fixed interval
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 1.0) // Fixed interval
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 2.0) // Should be exponential backoff now
    }
    
    func testExponentialBackoffAfterFixedWithZeroCount() {
        let interval = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            maxFixedCount: 0,
            scaleRate: 2.0
        )
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, 2.0) // Should be exponential backoff immediately
    }
    
    // MARK: - Complex RetryCount Tests
    
    func testRetryCountWithExponentialBackoff() {
        let retryCount = RetryCount.count(
            count: 3,
            intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)
        )
        XCTAssertEqual(retryCount.timeInterval, 1.0)
        
        let next1 = retryCount.next()
        XCTAssertEqual(next1.timeInterval, 2.0)
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 4.0)
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, nil) // Should be .never
    }
    
    func testRetryCountWithExponentialBackoffBeforeFixed() {
        let retryCount = RetryCount.count(
            count: 5,
            intervalProxy: .exponentialBackoffBeforeFixed(
                initialTimeInterval: 1.0,
                maxExponentialBackoffCount: 2,
                scaleRate: 2.0
            )
        )
        XCTAssertEqual(retryCount.timeInterval, 1.0)
        
        let next1 = retryCount.next()
        XCTAssertEqual(next1.timeInterval, 2.0) // Exponential backoff
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 4.0) // Exponential backoff
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 1.0) // Fixed (original interval)
        
        let next4 = next3.next()
        XCTAssertEqual(next4.timeInterval, 1.0) // Fixed
        
        let next5 = next4.next()
        XCTAssertEqual(next5.timeInterval, nil) // Should be .never
    }
    
    // MARK: - Edge Cases
    
    func testRetryCountWithCountOne() {
        let retryCount = RetryCount.count(count: 1)
        XCTAssertEqual(retryCount.timeInterval, 0.0)
        
        let next = retryCount.next()
        XCTAssertEqual(next.timeInterval, nil) // Should be .never immediately
    }
    
    func testRetryCountWithCountZero() {
        let retryCount = RetryCount.count(count: 0)
        XCTAssertEqual(retryCount.timeInterval, 0.0)
        
        let next = retryCount.next()
        XCTAssertEqual(next.timeInterval, nil) // Should be .never immediately
    }
    
    func testExponentialBackoffWithZeroInitialInterval() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 0.0, scaleRate: 2.0)
        XCTAssertEqual(interval.timeInterval, 0.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, 0.0) // 0.0 * 2.0 = 0.0
    }
    
    func testExponentialBackoffWithNegativeScaleRate() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: -1.0)
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, 1.0)
    }
    
    // MARK: - Missing Test Cases - Default Values
    
    func testDefaultValues() {
        // Test default values for all cases
        let fixedDefault = RetryCount.IntervalProxy.fixed()
        XCTAssertEqual(fixedDefault.timeInterval, 0.0)
        
        let exponentialDefault = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)
        XCTAssertEqual(exponentialDefault.timeInterval, 1.0)
        
        let beforeFixedDefault = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(initialTimeInterval: 1.0, maxExponentialBackoffCount: 0, scaleRate: 2.0)
        XCTAssertEqual(beforeFixedDefault.timeInterval, 1.0)
        
        let afterFixedDefault = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(initialTimeInterval: 1.0, maxFixedCount: 0, scaleRate: 2.0)
        XCTAssertEqual(afterFixedDefault.timeInterval, 1.0)
    }
    
    // MARK: - Missing Test Cases - Infinity with Different Intervals
    
    func testInfinityWithExponentialBackoff() {
        let retryCount = RetryCount.infinity(intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0))
        XCTAssertEqual(retryCount.timeInterval, 1.0)
        
        let next1 = retryCount.next()
        XCTAssertEqual(next1.timeInterval, 2.0)
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 4.0)
        
        // Should continue infinitely with exponential backoff
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 8.0)
    }
    
    func testInfinityWithExponentialBackoffBeforeFixed() {
        let retryCount = RetryCount.infinity(intervalProxy: .exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            maxExponentialBackoffCount: 2,
            scaleRate: 2.0
        ))
        XCTAssertEqual(retryCount.timeInterval, 1.0)
        
        let next1 = retryCount.next()
        XCTAssertEqual(next1.timeInterval, 2.0)
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 4.0)
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 1.0) // Fixed
        
        let next4 = next3.next()
        XCTAssertEqual(next4.timeInterval, 1.0) // Fixed
        
        // Should continue infinitely with fixed interval
        let next5 = next4.next()
        XCTAssertEqual(next5.timeInterval, 1.0)
    }
    
    // MARK: - Missing Test Cases - Large Numbers and Overflow
    
    func testLargeCountValues() {
        let retryCount = RetryCount.count(count: 1000000)
        XCTAssertEqual(retryCount.timeInterval, 0.0)
        
        // Test that it doesn't crash with large numbers
        var current = retryCount
        for _ in 0..<100 {
            current = current.next()
            XCTAssertNotNil(current.timeInterval)
            XCTAssertGreaterThanOrEqual(current.timeInterval!, 0.0)
        }
    }
    
    func testLargeScaleRate() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 1000.0)
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, 1000.0)
        
        let next2 = next.next()
        XCTAssertEqual(next2.timeInterval, 1000000.0)
    }
    
    // MARK: - Missing Test Cases - Negative Time Intervals
    
    func testNegativeTimeInterval() {
        let interval = RetryCount.IntervalProxy.fixed(timeInterval: -1.0)
        XCTAssertEqual(interval.timeInterval, -1.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, -1.0)
    }
    
    func testExponentialBackoffWithNegativeInitialInterval() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: -1.0, scaleRate: 2.0)
        XCTAssertEqual(interval.timeInterval, -1.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, -2.0)
    }
    
    // MARK: - Missing Test Cases - Zero Scale Rate
    
    func testExponentialBackoffWithZeroScaleRate() {
        let interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.0)
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next = interval.next()
        XCTAssertEqual(next.timeInterval, 1.0)
    }
    
    // MARK: - Missing Test Cases - Complex State Transitions
    
    func testComplexStateTransitions() {
        // Test exponential backoff before fixed with multiple transitions
        let interval = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            maxExponentialBackoffCount: 3,
            scaleRate: 2.0
        )
        
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next1 = interval.next()
        XCTAssertEqual(next1.timeInterval, 2.0)
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 4.0)
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 8.0)
        
        let next4 = next3.next()
        XCTAssertEqual(next4.timeInterval, 1.0) // Fixed
        
        let next5 = next4.next()
        XCTAssertEqual(next5.timeInterval, 1.0) // Fixed
    }
    
    func testExponentialBackoffAfterFixedComplex() {
        // Test exponential backoff after fixed with multiple fixed intervals
        let interval = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            maxFixedCount: 3,
            scaleRate: 2.0
        )
        
        XCTAssertEqual(interval.timeInterval, 1.0)
        
        let next1 = interval.next()
        XCTAssertEqual(next1.timeInterval, 1.0) // Fixed
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, 1.0) // Fixed
        
        let next3 = next2.next()
        XCTAssertEqual(next3.timeInterval, 1.0) // Fixed
        
        let next4 = next3.next()
        XCTAssertEqual(next4.timeInterval, 2.0) // Exponential backoff
        
        let next5 = next4.next()
        XCTAssertEqual(next5.timeInterval, 4.0) // Exponential backoff
    }
    
    // MARK: - Missing Test Cases - Convenience Initializers
    
    func testConvenienceInitializers() {
        // Test that convenience initializers work correctly
        let exp1 = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 2.0, scaleRate: 3.0)
        XCTAssertEqual(exp1.timeInterval, 2.0)
        
        let exp2 = exp1.next()
        XCTAssertEqual(exp2.timeInterval, 6.0)
        
        let beforeFixed = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 2.0,
            maxExponentialBackoffCount: 1,
            scaleRate: 3.0
        )
        XCTAssertEqual(beforeFixed.timeInterval, 2.0)
        
        let afterFixed = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 2.0,
            maxFixedCount: 1,
            scaleRate: 3.0
        )
        XCTAssertEqual(afterFixed.timeInterval, 2.0)
    }
    
    // MARK: - Missing Test Cases - Type Safety
    
    func testTypeSafety() {
        // Test that different types work correctly
        let retryCount: RetryCount = 42
        XCTAssertEqual(retryCount.timeInterval, 0.0)
        
        // Test with different integer literals
        let retryCount2: RetryCount = 0
        XCTAssertEqual(retryCount2.timeInterval, nil)
        
        let retryCount3: RetryCount = 1
        XCTAssertEqual(retryCount3.timeInterval, 0.0)
    }
    
    // MARK: - Missing Test Cases - Edge Cases for Count
    
    func testCountEdgeCases() {
        // Test count with different interval proxies
        let retryCount1 = RetryCount.count(count: 2, intervalProxy: .fixed(timeInterval: 5.0))
        XCTAssertEqual(retryCount1.timeInterval, 5.0)
        
        let next1 = retryCount1.next()
        XCTAssertEqual(next1.timeInterval, 5.0)
        
        let next2 = next1.next()
        XCTAssertEqual(next2.timeInterval, nil) // .never
        
        // Test count with exponential backoff
        let retryCount2 = RetryCount.count(count: 2, intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0))
        XCTAssertEqual(retryCount2.timeInterval, 1.0)
        
        let next3 = retryCount2.next()
        XCTAssertEqual(next3.timeInterval, 2.0)
        
        let next4 = next3.next()
        XCTAssertEqual(next4.timeInterval, nil) // .never
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceExponentialBackoff() {
        measure {
            var interval = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)
            for _ in 0..<100 {
                interval = interval.next()
                _ = interval.timeInterval
            }
        }
    }
    
    func testPerformanceRetryCountNext() {
        measure {
            var retryCount = RetryCount.count(count: 1000)
            for _ in 0..<1000 {
                retryCount = retryCount.next()
                _ = retryCount.timeInterval
            }
        }
    }
    
    // MARK: - Missing Test Cases - Performance with Complex Strategies
    
    func testPerformanceComplexStrategies() {
        measure {
            var retryCount = RetryCount.count(
                count: 100,
                intervalProxy: .exponentialBackoffBeforeFixed(
                    initialTimeInterval: 1.0,
                    maxExponentialBackoffCount: 10,
                    scaleRate: 1.5
                )
            )
            for _ in 0..<100 {
                retryCount = retryCount.next()
                _ = retryCount.timeInterval
            }
        }
    }
}
