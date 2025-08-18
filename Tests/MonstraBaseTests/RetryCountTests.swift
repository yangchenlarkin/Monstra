import XCTest
@testable import MonstraBase

/// Test suite for RetryCount enum and its IntervalProxy
/// 
/// This test suite comprehensively validates the retry logic and timing behavior
/// of the RetryCount enum, including all retry strategies and interval calculations.
final class RetryCountTests: XCTestCase {
    
    // MARK: - Basic RetryCount Tests
    
    /// Test basic initialization and properties of count-based retry
    func testRetryCountInitialization() {
        let retryCount = RetryCount.count(count: 3)
        XCTAssertTrue(retryCount.shouldRetry, "Count-based retry should be enabled")
        XCTAssertEqual(retryCount.timeInterval, 0.0, "Default time interval should be 0.0")
    }
    
    /// Test the progression through count-based retry states
    func testRetryCountNext() {
        var retryCount = RetryCount.count(count: 3)
        
        // Initial state
        XCTAssertTrue(retryCount.shouldRetry, "Should initially allow retry")
        
        // First call - should have 2 retries left
        retryCount = retryCount.next()
        XCTAssertTrue(retryCount.shouldRetry, "Should still retry (2 left)")
        
        // Second call - should have 1 retry left  
        retryCount = retryCount.next()
        XCTAssertTrue(retryCount.shouldRetry, "Should still retry (1 left)")
        
        // Third call - should transition to never
        retryCount = retryCount.next()
        XCTAssertFalse(retryCount.shouldRetry, "Should not retry anymore")
        
        // Verify it's in never state
        if case .never = retryCount {
            // Expected
        } else {
            XCTFail("Should transition to .never state")
        }
    }
    
    /// Test infinite retry behavior
    func testRetryCountInfinity() {
        let retryCount = RetryCount.infinity()
        XCTAssertTrue(retryCount.shouldRetry, "Infinity should always retry")
        XCTAssertEqual(retryCount.timeInterval, 0.0, "Default time interval should be 0.0")
        
        let nextRetryCount = retryCount.next()
        XCTAssertTrue(nextRetryCount.shouldRetry, "Infinity should always retry after next()")
        XCTAssertEqual(nextRetryCount.timeInterval, 0.0, "Time interval should remain 0.0")
    }
    
    /// Test never retry behavior
    func testRetryCountNever() {
        let retryCount = RetryCount.never
        XCTAssertFalse(retryCount.shouldRetry, "Never should not retry")
        XCTAssertEqual(retryCount.timeInterval, 0.0, "Never should have 0 time interval")
        
        let nextRetryCount = retryCount.next()
        XCTAssertFalse(nextRetryCount.shouldRetry, "Never should not retry after next()")
        XCTAssertEqual(nextRetryCount.timeInterval, 0.0, "Never should maintain 0 time interval")
    }
    
    /// Test retry count with custom time interval
    func testRetryCountWithCustomInterval() {
        let retryCount = RetryCount.count(count: 2, intervalProxy: .fixed(timeInterval: 1.5))
        XCTAssertTrue(retryCount.shouldRetry, "Should allow retry")
        XCTAssertEqual(retryCount.timeInterval, 1.5, "Should use custom time interval")
        
        let nextRetryCount = retryCount.next()
        XCTAssertTrue(nextRetryCount.shouldRetry, "Should still allow retry")
        XCTAssertEqual(nextRetryCount.timeInterval, 1.5, "Should maintain custom time interval")
    }
    
    /// Test integer literal conformance
    func testRetryCountIntegerLiteral() {
        let retryCount: RetryCount = 0
        XCTAssertFalse(retryCount.shouldRetry, "Zero should be never")
        XCTAssertEqual(retryCount.timeInterval, 0.0, "Zero should have 0 time interval")
        
        let retryCount2: RetryCount = 3
        XCTAssertTrue(retryCount2.shouldRetry, "Positive number should be count")
        XCTAssertEqual(retryCount2.timeInterval, 0.0, "Default interval should be 0.0")
        
        // Test the actual count
        if case .count(let count, _) = retryCount2 {
            XCTAssertEqual(count, 3, "Count should be 3")
        } else {
            XCTFail("Should be count case")
        }
    }
    
    /// Test infinity with custom interval proxy
    func testRetryCountInfinityWithCustomInterval() {
        let retryCount = RetryCount.infinity(intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0))
        XCTAssertTrue(retryCount.shouldRetry, "Infinity should allow retry")
        XCTAssertEqual(retryCount.timeInterval, 1.0, "Should use initial time interval")
        
        let nextRetryCount = retryCount.next()
        XCTAssertTrue(nextRetryCount.shouldRetry, "Infinity should continue to allow retry")
        XCTAssertEqual(nextRetryCount.timeInterval, 2.0, "Should scale time interval")
    }
    
    /// Test count with exponential backoff
    func testRetryCountWithExponentialBackoff() {
        var retryCount = RetryCount.count(count: 3, intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0))
        
        // Initial state
        XCTAssertTrue(retryCount.shouldRetry, "Should allow retry")
        XCTAssertEqual(retryCount.timeInterval, 1.0, "Initial interval should be 1.0")
        
        // First next()
        retryCount = retryCount.next()
        XCTAssertTrue(retryCount.shouldRetry, "Should still allow retry")
        XCTAssertEqual(retryCount.timeInterval, 2.0, "Should scale to 2.0")
        
        // Second next()
        retryCount = retryCount.next()
        XCTAssertTrue(retryCount.shouldRetry, "Should still allow retry")
        XCTAssertEqual(retryCount.timeInterval, 4.0, "Should scale to 4.0")
        
        // Third next() - should transition to never
        retryCount = retryCount.next()
        XCTAssertFalse(retryCount.shouldRetry, "Should not allow retry")
        XCTAssertEqual(retryCount.timeInterval, 0.0, "Never should have 0 interval")
    }
    
    // MARK: - IntervalProxy Basic Functionality Tests
    
    /// Test exponential backoff with normal scaling factor
    func testNextTimeIntervalWithNormalScale() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)
        let nextProxy = proxy.next()
        
        // Test that the time interval is correctly scaled
        XCTAssertEqual(nextProxy.timeInterval, 2.0, "Time interval should be scaled by 2.0")
        
        // Verify it's still exponential backoff
        if case .exponentialBackoff(let interval, let rate) = nextProxy {
            XCTAssertEqual(interval, 2.0, "Should have scaled interval")
            XCTAssertEqual(rate, 2.0, "Should preserve scale rate")
        } else {
            XCTFail("Should remain exponentialBackoff case")
        }
    }
    
    /// Test exponential backoff with large scaling factor
    func testNextTimeIntervalWithLargeScale() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 10.0)
        let nextProxy = proxy.next()
        
        XCTAssertEqual(nextProxy.timeInterval, 10.0, "Time interval should be scaled by 10.0")
        
        if case .exponentialBackoff(let interval, let rate) = nextProxy {
            XCTAssertEqual(interval, 10.0, "Should have scaled interval")
            XCTAssertEqual(rate, 10.0, "Should preserve scale rate")
        } else {
            XCTFail("Should remain exponentialBackoff case")
        }
    }
    
    /// Test scale rate clamping behavior
    func testNextTimeIntervalWithScaleBelowOne() {
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.5)
        let nextProxy = proxy.next()
        
        // Scale rate should be clamped to minimum 1.0
        XCTAssertEqual(nextProxy.timeInterval, 1.0, "Scale rate should be clamped to minimum 1.0")
        
        if case .exponentialBackoff(let interval, let rate) = nextProxy {
            XCTAssertEqual(interval, 1.0, "Should have clamped interval")
            XCTAssertEqual(rate, 0.5, "Should preserve original scale rate")
        } else {
            XCTFail("Should remain exponentialBackoff case")
        }
    }
    
    /// Test overflow prevention with very large initial intervals
    func testNextTimeIntervalWithVeryLargeInitialInterval() {
        let largeInterval = TimeInterval.greatestFiniteMagnitude / 2.0
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: largeInterval, scaleRate: 2.0)
        let nextProxy = proxy.next()
        
        // Should clamp to greatestFiniteMagnitude to prevent overflow
        XCTAssertEqual(nextProxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should clamp to greatestFiniteMagnitude")
    }
    
    /// Test overflow prevention with near-maximum intervals
    func testNextTimeIntervalWithOverflowPrevention() {
        let nearMaxInterval = TimeInterval.greatestFiniteMagnitude / 1.1
        let proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: nearMaxInterval, scaleRate: 2.0)
        let nextProxy = proxy.next()
        
        XCTAssertEqual(nextProxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should prevent overflow")
    }
    
    /// Test that fixed intervals remain unchanged
    func testFixedIntervalDoesNotChange() {
        let proxy = RetryCount.IntervalProxy.fixed(timeInterval: 1.5)
        let nextProxy = proxy.next()
        
        XCTAssertEqual(nextProxy.timeInterval, 1.5, "Fixed interval should not change")
        
        if case .fixed(let timeInterval) = nextProxy {
            XCTAssertEqual(timeInterval, 1.5, "Should remain fixed")
        } else {
            XCTFail("Should be fixed case")
        }
        
        // Test multiple iterations
        let thirdProxy = nextProxy.next()
        XCTAssertEqual(thirdProxy.timeInterval, 1.5, "Fixed interval should remain unchanged")
    }
    
    // MARK: - Complex IntervalProxy Strategies Tests
    
    /// Test exponential backoff before fixed with immediate transition (zero max count)
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
    
    /// Test exponential backoff before fixed with continued exponential phase
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
        
        if case .exponentialBackoffBeforeFixed(let initialTimeInterval, let originalInterval, let maxCount, let scaleRate) = nextProxy {
            XCTAssertEqual(initialTimeInterval, 2.0, "Should scale initial interval")
            XCTAssertEqual(originalInterval, 0.5, "Should preserve original interval")
            XCTAssertEqual(maxCount, 1, "Should decrement max count")
            XCTAssertEqual(scaleRate, 2.0, "Should preserve scale rate")
        } else {
            XCTFail("Should be exponentialBackoffBeforeFixed case")
        }
    }
    
    /// Test exponential backoff after fixed with immediate transition (zero max count)
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
        
        if case .exponentialBackoff(let initialTimeInterval, let scaleRate) = nextProxy {
            XCTAssertEqual(initialTimeInterval, 2.0, "Should scale initial interval")
            XCTAssertEqual(scaleRate, 2.0, "Should preserve scale rate")
        } else {
            XCTFail("Should be exponentialBackoff case")
        }
    }
    
    /// Test exponential backoff after fixed with continued fixed phase
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
        
        if case .exponentialBackoffAfterFixed(let initialTimeInterval, let originalInterval, let maxCount, let scaleRate) = nextProxy {
            XCTAssertEqual(initialTimeInterval, 0.5, "Should use original interval")
            XCTAssertEqual(originalInterval, 0.5, "Should preserve original interval")
            XCTAssertEqual(maxCount, 1, "Should decrement max count")
            XCTAssertEqual(scaleRate, 2.0, "Should preserve scale rate")
        } else {
            XCTFail("Should be exponentialBackoffAfterFixed case")
        }
    }
    
    /// Test complete transition from exponential backoff to fixed interval
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
        
        // Verify still in exponential backoff phase
        if case .exponentialBackoffBeforeFixed(_, _, let maxCount, _) = proxy {
            XCTAssertEqual(maxCount, 0, "Max count should be decremented to 0")
        } else {
            XCTFail("Should still be exponentialBackoffBeforeFixed case")
        }
        
        // Second call should transition to fixed
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Should transition to fixed interval")
        
        if case .fixed(let timeInterval) = proxy {
            XCTAssertEqual(timeInterval, 0.5, "Should use original interval")
        } else {
            XCTFail("Should be fixed case")
        }
        
        // Subsequent calls should remain fixed
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Should remain at fixed interval")
    }
    
    /// Test complete transition from fixed interval to exponential backoff
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
        
        // Verify still in fixed phase
        if case .exponentialBackoffAfterFixed(_, _, let maxCount, _) = proxy {
            XCTAssertEqual(maxCount, 0, "Max count should be decremented to 0")
        } else {
            XCTFail("Should still be exponentialBackoffAfterFixed case")
        }
        
        // Second call should transition to exponential backoff
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Should transition to exponential backoff")
        
        if case .exponentialBackoff(let initialTimeInterval, let scaleRate) = proxy {
            XCTAssertEqual(initialTimeInterval, 1.0, "Should use original interval")
            XCTAssertEqual(scaleRate, 2.0, "Should preserve scale rate")
        } else {
            XCTFail("Should be exponentialBackoff case")
        }
        
        // Subsequent calls should follow exponential backoff
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.0, "Should continue exponential backoff")
    }
    
    // MARK: - Exponential Backoff Pattern Tests
    
    /// Test multiple iterations of pure exponential backoff
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
        
        // Verify it maintains exponential backoff state
        if case .exponentialBackoff(let interval, let rate) = proxy {
            XCTAssertEqual(interval, 8.0, "Should maintain scaled interval")
            XCTAssertEqual(rate, 2.0, "Should preserve scale rate")
        } else {
            XCTFail("Should remain exponentialBackoff case")
        }
    }
    
    /// Test exponential backoff with custom scale rate
    func testExponentialBackoffWithCustomScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 1.5)
        
        // First iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.5, "First iteration should be 1.5")
        
        // Second iteration
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.25, "Second iteration should be 2.25")
    }
    
    // MARK: - Scale Rate Edge Case Tests
    
    /// Test scale rate clamping for values below 1.0
    func testExponentialBackoffWithVerySmallScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.1)
        
        // Scale rate should be clamped to 1.0
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Scale rate should be clamped to 1.0")
    }
    
    /// Test negative scale rate handling
    func testExponentialBackoffWithNegativeScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: -1.0)
        
        // Scale rate should be clamped to 1.0
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Negative scale rate should be clamped to 1.0")
    }
    
    /// Test zero scale rate handling
    func testExponentialBackoffWithZeroScaleRate() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 0.0)
        
        // Scale rate should be clamped to 1.0
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Zero scale rate should be clamped to 1.0")
    }
    
    /// Test extreme scale rate handling
    func testExponentialBackoffWithExtremeScaleRate() {
        let extremeScale = Double.greatestFiniteMagnitude
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: 1.0, scaleRate: extremeScale)
        
        // Should handle extreme scale rate gracefully
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should clamp to greatestFiniteMagnitude")
    }
    
    // MARK: - Overflow Prevention Tests
    
    /// Test handling of near-maximum time intervals
    func testExponentialBackoffWithNearMaxInterval() {
        let nearMaxInterval = TimeInterval.greatestFiniteMagnitude / 3.0
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: nearMaxInterval, scaleRate: 2.0)
        
        // Should handle near-maximum interval
        proxy = proxy.next()
        XCTAssertTrue(proxy.timeInterval >= nearMaxInterval, "Should scale the interval")
    }
    
    /// Test handling of maximum time interval
    func testExponentialBackoffWithMaxInterval() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoff(initialTimeInterval: TimeInterval.greatestFiniteMagnitude, scaleRate: 2.0)
        
        // Should handle maximum interval
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, TimeInterval.greatestFiniteMagnitude, "Should remain at greatestFiniteMagnitude")
    }
    
    // MARK: - Complex Strategy Integration Tests
    
    /// Test complete exponential-to-fixed transition scenario
    func testComplexExponentialBackoffBeforeFixedScenario() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxExponentialBackoffCount: 3,
            scaleRate: 2.0
        )
        
        // First iteration (exponential phase)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.0, "First iteration should be 2.0")
        
        // Second iteration (exponential phase)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 4.0, "Second iteration should be 4.0")
        
        // Third iteration (exponential phase)
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
        
        // Subsequent iterations should remain fixed
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Should remain at fixed interval")
    }
    
    /// Test complete fixed-to-exponential transition scenario
    func testComplexExponentialBackoffAfterFixedScenario() {
        var proxy = RetryCount.IntervalProxy.exponentialBackoffAfterFixed(
            initialTimeInterval: 1.0,
            originalInitialInterval: 0.5,
            maxFixedCount: 3,
            scaleRate: 2.0
        )
        
        // First iteration (fixed phase)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "First iteration should be 0.5")
        
        // Second iteration (fixed phase)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Second iteration should be 0.5")
        
        // Third iteration (fixed phase)
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 0.5, "Third iteration should be 0.5")
        
        // Fourth iteration should transition to exponential backoff
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 1.0, "Should transition to exponential backoff")
        
        if case .exponentialBackoff(let initialTimeInterval, let scaleRate) = proxy {
            XCTAssertEqual(initialTimeInterval, 1.0, "Should use original interval")
            XCTAssertEqual(scaleRate, 2.0, "Should preserve scale rate")
        } else {
            XCTFail("Should be exponentialBackoff case")
        }
        
        // Fifth iteration should continue exponential scaling
        proxy = proxy.next()
        XCTAssertEqual(proxy.timeInterval, 2.0, "Should continue exponential scaling")
    }
    
    // MARK: - Edge Case and Default Value Tests
    
    /// Test default parameter values for IntervalProxy cases
    func testIntervalProxyDefaultValues() {
        // Test fixed with default (0)
        let fixedProxy = RetryCount.IntervalProxy.fixed()
        XCTAssertEqual(fixedProxy.timeInterval, 0.0, "Default fixed interval should be 0.0")
        
        // Test exponentialBackoff with defaults
        let expProxy = RetryCount.IntervalProxy.exponentialBackoff()
        XCTAssertEqual(expProxy.timeInterval, RetryCount.IntervalProxy.DefaultInitialTimeInterval, "Should use default initial interval")
        if case .exponentialBackoff(_, let rate) = expProxy {
            XCTAssertEqual(rate, RetryCount.IntervalProxy.DefaultExponentialBackoffScaleRate, "Should use default scale rate")
        } else {
            XCTFail("Should be exponentialBackoff case")
        }
        
        // Test exponentialBackoffBeforeFixed with defaults
        let expBeforeProxy = RetryCount.IntervalProxy.exponentialBackoffBeforeFixed()
        XCTAssertEqual(expBeforeProxy.timeInterval, RetryCount.IntervalProxy.DefaultInitialTimeInterval, "Should use default initial interval")
        
        // Test exponentialBackoffAfterFixed with defaults  
        let expAfterProxy = RetryCount.IntervalProxy.exponentialBackoffAfterFixed()
        XCTAssertEqual(expAfterProxy.timeInterval, RetryCount.IntervalProxy.DefaultInitialTimeInterval, "Should use default initial interval")
    }
    
    /// Test RetryCount with extreme count values
    func testRetryCountWithExtremeValues() {
        // Test with maximum UInt value
        let maxRetryCount = RetryCount.count(count: UInt.max)
        XCTAssertTrue(maxRetryCount.shouldRetry, "Max count should allow retry")
        
        let nextMaxRetry = maxRetryCount.next()
        XCTAssertTrue(nextMaxRetry.shouldRetry, "Should still allow retry with very large count")
        
        // Test with count 1 (edge case for immediate transition to never)
        var singleRetry = RetryCount.count(count: 1)
        XCTAssertTrue(singleRetry.shouldRetry, "Count 1 should initially allow retry")
        
        singleRetry = singleRetry.next()
        XCTAssertFalse(singleRetry.shouldRetry, "Should transition to never after single retry")
    }
} 