import XCTest
@testable import MonstraBase

final class RetryCountTests: XCTestCase {
    
    // MARK: - Basic RetryCount Tests
    
    func testRetryCountInitialization() {
        let retryCount = RetryCount.count(count: 3)
        XCTAssertEqual(retryCount.shouldRetry, 0.0, "Default time interval should be 0.0")
    }
    
    func testRetryCountNext() {
        var retryCount = RetryCount.count(count: 3)
        
        // First call
        retryCount = retryCount.next()
        XCTAssertEqual(retryCount.shouldRetry, 0.0, "Should still retry")
        
        // Second call
        retryCount = retryCount.next()
        XCTAssertEqual(retryCount.shouldRetry, 0.0, "Should still retry")
        
        // Third call
        retryCount = retryCount.next()
        XCTAssertNil(retryCount.shouldRetry, "Should not retry anymore")
    }
    
    func testRetryCountInfinity() {
        let retryCount = RetryCount.infinity()
        XCTAssertEqual(retryCount.shouldRetry, 0.0, "Infinity should always retry")
        
        let nextRetryCount = retryCount.next()
        XCTAssertEqual(nextRetryCount.shouldRetry, 0.0, "Infinity should always retry")
    }
    
    func testRetryCountNever() {
        let retryCount = RetryCount.never
        XCTAssertNil(retryCount.shouldRetry, "Never should not retry")
        
        let nextRetryCount = retryCount.next()
        XCTAssertNil(nextRetryCount.shouldRetry, "Never should not retry")
    }
    
    func testRetryCountWithCustomInterval() {
        let retryCount = RetryCount.count(count: 2, intervalProxy: .fixed(timeInterval: 1.5))
        XCTAssertEqual(retryCount.shouldRetry, 1.5, "Should use custom time interval")
    }
    
    func testRetryCountIntegerLiteral() {
        let retryCount: RetryCount = 0
        XCTAssertNil(retryCount.shouldRetry, "Zero should be never")
        
        let retryCount2: RetryCount = 3
        XCTAssertEqual(retryCount2.shouldRetry, 0.0, "Positive number should be count")
    }
    
    // MARK: - IntervalProxy.nextTimeInterval Tests
    
    func testNextTimeIntervalWithNormalScale() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)
        let nextProxy = proxy.next()
        
        // Test that the time interval is correctly scaled
        XCTAssertEqual(nextProxy.timeInterval, 2.0, "Time interval should be scaled by 2.0")
    }
    
    func testNextTimeIntervalWithLargeScale() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 10.0)
        let nextProxy = proxy.next()
        
        XCTAssertEqual(nextProxy.timeInterval, 10.0, "Time interval should be scaled by 10.0")
    }
    
    func testNextTimeIntervalWithScaleBelowOne() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.5)
        let nextProxy = proxy.next()
        
        // Scale rate should be clamped to minimum 1.0
        XCTAssertEqual(nextProxy.timeInterval, 1.0, "Scale rate should be clamped to minimum 1.0")
    }
    
    func testNextTimeIntervalWithVeryLargeInitialInterval() {
        let largeInterval = TimeInterval.greatestFiniteMagnitude / 2.0
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: largeInterval, scaleRate: 2.0)
        let nextProxy = proxy.next()
        
        // Should clamp to greatestFiniteMagnitude to prevent overflow
        XCTAssertEqual(nextProxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should clamp to greatestFiniteMagnitude")
    }
    
    func testNextTimeIntervalWithOverflowPrevention() {
        let nearMaxInterval = TimeInterval.greatestFiniteMagnitude / 1.1
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: nearMaxInterval, scaleRate: 2.0)
        let nextProxy = proxy.next()
        
        XCTAssertEqual(nextProxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should prevent overflow")
    }
    
    // MARK: - Complex IntervalProxy.next() Tests
    
    func testExponentialBackoffBeforeFixedWithZeroMaxCount() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 2.0,
            originalInitialInterval: 1.0,
            maxExponentialBackoffCount: 0,
            scaleRate: 2.0
        )
        let nextProxy = proxy.next()
        
        // Should transition to fixed interval when maxExponentialBackoffCount is 0
        XCTAssertEqual(nextProxy.timeInterval, 1.0, "Should transition to fixed interval")
        
        if case .fixed(let timeInterval) = nextProxy {
            XCTAssertEqual(timeInterval, 1.0, "Should use original interval")
        } else {
            XCTFail("Should be fixed case")
        }
    }
    
    func testExponentialBackoffBeforeFixedWithNonZeroMaxCount() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxExponentialBackoffCount: 2,
            scaleRate: 2.0
        )
        let nextProxy = proxy.next()
        
        // Should continue exponential backoff
        XCTAssertEqual(nextProxy.timeInterval, 2.0, "Should continue exponential backoff")
        
        if case .exponentialBackoffBeforeFixed(let initialTimeInterval, let originalInterval, let maxCount, _) = nextProxy {
            XCTAssertEqual(initialTimeInterval, 2.0, "Should scale initial interval")
            XCTAssertEqual(originalInterval, 0.5, "Should preserve original interval")
            XCTAssertEqual(maxCount, 1, "Should decrement max count")
        } else {
            XCTFail("Should be exponentialBackoffBeforeFixed case")
        }
    }
    
    func testExponentialBackoffAfterFixedWithZeroMaxCount() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxFixedCount: 0,
            scaleRate: 2.0
        )
        let nextProxy = proxy.next()
        
        // Should transition to exponential backoff when maxFixedCount is 0
        XCTAssertEqual(nextProxy.timeInterval, 2.0, "Should transition to exponential backoff")
        
        if case .exponentialBackoff(let initialTimeInterval, _) = nextProxy {
            XCTAssertEqual(initialTimeInterval, 2.0, "Should scale initial interval")
        } else {
            XCTFail("Should be exponentialBackoff case")
        }
    }
    
    func testExponentialBackoffAfterFixedWithNonZeroMaxCount() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxFixedCount: 2,
            scaleRate: 2.0
        )
        let nextProxy = proxy.next()
        
        // Should continue fixed interval
        XCTAssertEqual(nextProxy.timeInterval, 0.5, "Should use original interval")
        
        if case .exponentialBackoffAfterFixed(let initialTimeInterval, let originalInterval, let maxCount, _) = nextProxy {
            XCTAssertEqual(initialTimeInterval, 0.5, "Should use original interval")
            XCTAssertEqual(originalInterval, 0.5, "Should preserve original interval")
            XCTAssertEqual(maxCount, 1, "Should decrement max count")
        } else {
            XCTFail("Should be exponentialBackoffAfterFixed case")
        }
    }
    
    func testExponentialBackoffBeforeFixedTransitionToFixed() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxExponentialBackoffCount: 1,
            scaleRate: 2.0
        )
        
        // First call should continue exponential backoff
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.0, "Should continue exponential backoff")
        
        // Second call should transition to fixed
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Should transition to fixed interval")
        
        if case .fixed(let timeInterval) = proxy {
            XCTAssertEqual(timeInterval, 0.5, "Should use original interval")
        } else {
            XCTFail("Should be fixed case")
        }
    }
    
    func testExponentialBackoffAfterFixedTransitionToExponential() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxFixedCount: 1,
            scaleRate: 2.0
        )
        
        // First call should continue fixed
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Should continue fixed interval")
        
        // Second call should transition to exponential backoff
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Should transition to exponential backoff")
        
        if case .exponentialBackoff(let initialTimeInterval, _) = proxy {
            XCTAssertEqual(initialTimeInterval, 1.0, "Should use original interval")
        } else {
            XCTFail("Should be exponentialBackoff case")
        }
    }
    
    func testFixedIntervalDoesNotChange() {
        let proxy = RetryCount.IntervalProxy.fixed(timeInterval: 1.5)
        let nextProxy = proxy.next()
        
        XCTAssertEqual(nextProxy.timeInterval, 1.5, "Fixed interval should not change")
        
        if case .fixed(let timeInterval) = nextProxy {
            XCTAssertEqual(timeInterval, 1.5, "Should remain fixed")
        } else {
            XCTFail("Should be fixed case")
        }
    }
    
    func testExponentialBackoffMultipleIterations() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)
        
        // First iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.0, "First iteration should be 2.0")
        
        // Second iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 4.0, "Second iteration should be 4.0")
        
        // Third iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 8.0, "Third iteration should be 8.0")
    }
    
    func testExponentialBackoffWithCustomScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 1.5)
        
        // First iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.5, "First iteration should be 1.5")
        
        // Second iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.25, "Second iteration should be 2.25")
    }
    
    func testExponentialBackoffWithVerySmallScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.1)
        
        // Scale rate should be clamped to 1.0
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Scale rate should be clamped to 1.0")
    }
    
    func testExponentialBackoffWithNegativeScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: -1.0)
        
        // Scale rate should be clamped to 1.0
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Negative scale rate should be clamped to 1.0")
    }
    
    func testExponentialBackoffWithZeroScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.0)
        
        // Scale rate should be clamped to 1.0
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Zero scale rate should be clamped to 1.0")
    }
    
    func testExponentialBackoffWithExtremeScaleRate() {
        let extremeScale = Double.greatestFiniteMagnitude
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: extremeScale)
        
        // Should handle extreme scale rate gracefully
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should clamp to greatestFiniteMagnitude")
    }
    
    func testExponentialBackoffWithNearMaxInterval() {
        let nearMaxInterval = TimeInterval.greatestFiniteMagnitude / 3.0
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: nearMaxInterval, scaleRate: 2.0)
        
        // Should handle near-maximum interval
        proxy = proxy.next()
        XCTAssertTrue(proxy.timeInterval >= nearMaxInterval, "Should scale the interval")
    }
    
    func testExponentialBackoffWithMaxInterval() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: TimeInterval.greatestFiniteMagnitude, scaleRate: 2.0)
        
        // Should handle maximum interval
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should remain at greatestFiniteMagnitude")
    }
    

    
    func testComplexExponentialBackoffBeforeFixedScenario() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxExponentialBackoffCount: 3,
            scaleRate: 2.0
        )
        
        // First iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.0, "First iteration should be 2.0")
        
        // Second iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 4.0, "Second iteration should be 4.0")
        
        // Third iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 8.0, "Third iteration should be 8.0")
        
        // Fourth iteration should transition to fixed
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Should transition to fixed interval")
        
        if case .fixed(let timeInterval) = proxy {
            XCTAssertEqual(timeInterval, 0.5, "Should use original interval")
        } else {
            XCTFail("Should be fixed case")
        }
    }
    
    func testComplexExponentialBackoffAfterFixedScenario() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxFixedCount: 3,
            scaleRate: 2.0
        )
        
        // First iteration (fixed)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "First iteration should be 0.5")
        
        // Second iteration (fixed)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Second iteration should be 0.5")
        
        // Third iteration (fixed)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Third iteration should be 0.5")
        
        // Fourth iteration should transition to exponential backoff
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Should transition to exponential backoff")
        
        if case .exponentialBackoff(let initialTimeInterval, _) = proxy {
            XCTAssertEqual(initialTimeInterval, 1.0, "Should use original interval")
        } else {
            XCTFail("Should be exponentialBackoff case")
        }
    }
} 