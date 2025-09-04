import Foundation

/// RetryCount: Configurable retry policy with backoff strategies.
///
/// Encapsulates common retry patterns for asynchronous operations, including:
/// - No retries (`never`)
/// - Fixed number of retries with optional delay strategy (`count`)
/// - Infinite retries with optional delay strategy (`infinity`)
///
/// Delay strategies are modeled via `IntervalProxy`, covering fixed delays, pure exponential backoff,
/// and hybrid schemes that switch between exponential and fixed delays.
public enum RetryCount {
    /// Delay strategy used between retries.
    public enum IntervalProxy {
        /// Default initial delay (seconds) for exponential strategies.
        public static let DefaultInitialTimeInterval: TimeInterval = 1
        /// Default multiplier for exponential strategies.
        public static let DefaultExponentialBackoffScaleRate: Double = 2.0

        /// Always use a fixed delay.
        case fixed(timeInterval: TimeInterval = 0)
        /// Exponential backoff that multiplies delay on each `next()`.
        case exponentialBackoff(
            initialTimeInterval: TimeInterval = DefaultInitialTimeInterval,
            scaleRate: Double = DefaultExponentialBackoffScaleRate
        )
        /// Exponential backoff for up to `maxExponentialBackoffCount` iterations, then switch to fixed.
        case exponentialBackoffBeforeFixed(
            initialTimeInterval: TimeInterval = DefaultInitialTimeInterval,
            originalInitialInterval: TimeInterval = DefaultInitialTimeInterval,
            maxExponentialBackoffCount: UInt = 0,
            scaleRate: Double = DefaultExponentialBackoffScaleRate
        )
        /// Fixed delay for up to `maxFixedCount` iterations, then switch to exponential backoff.
        case exponentialBackoffAfterFixed(
            initialTimeInterval: TimeInterval = DefaultInitialTimeInterval,
            originalInitialInterval: TimeInterval = DefaultInitialTimeInterval,
            maxFixedCount: UInt = 0,
            scaleRate: Double = DefaultExponentialBackoffScaleRate
        )

        /// Returns the next stage in the delay sequence.
        public func next() -> Self {
            switch self {
            case .fixed:
                return self
            case let .exponentialBackoff(initialTimeInterval: initialTimeInterval, scaleRate: rate):
                return .exponentialBackoff(
                    initialTimeInterval: nextTimeInterval(of: initialTimeInterval, scale: rate),
                    scaleRate: rate
                )
            case let .exponentialBackoffBeforeFixed(
                initialTimeInterval: initialTimeInterval,
                originalInitialInterval: originalInterval,
                maxExponentialBackoffCount: maxExponentialBackoffCount,
                scaleRate: rate
            ):
                if maxExponentialBackoffCount == 0 {
                    return .fixed(timeInterval: originalInterval)
                } else {
                    return .exponentialBackoffBeforeFixed(
                        initialTimeInterval: nextTimeInterval(of: initialTimeInterval, scale: rate),
                        originalInitialInterval: originalInterval,
                        maxExponentialBackoffCount: maxExponentialBackoffCount - 1,
                        scaleRate: rate
                    )
                }
            case let .exponentialBackoffAfterFixed(
                initialTimeInterval: initialTimeInterval,
                originalInitialInterval: originalInterval,
                maxFixedCount: maxFixedCount,
                scaleRate: rate
            ):
                if maxFixedCount == 0 {
                    return .exponentialBackoff(
                        initialTimeInterval: nextTimeInterval(of: initialTimeInterval, scale: rate),
                        scaleRate: rate
                    )
                } else {
                    return .exponentialBackoffAfterFixed(
                        initialTimeInterval: originalInterval,
                        originalInitialInterval: originalInterval,
                        maxFixedCount: maxFixedCount - 1,
                        scaleRate: rate
                    )
                }
            }
        }

        /// The current delay (seconds) represented by this proxy.
        public var timeInterval: TimeInterval {
            switch self {
            case let .fixed(timeInterval: timeInterval):
                return timeInterval
            case let .exponentialBackoff(initialTimeInterval: initialTimeInterval, _):
                return initialTimeInterval
            case let .exponentialBackoffBeforeFixed(initialTimeInterval: initialTimeInterval, _, _, _):
                return initialTimeInterval
            case let .exponentialBackoffAfterFixed(initialTimeInterval: initialTimeInterval, _, _, _):
                return initialTimeInterval
            }
        }

        /// Computes the next exponential delay with overflow protection and minimum scale of 1.0.
        private func nextTimeInterval(of initialTimeInterval: TimeInterval, scale rate: Double) -> TimeInterval {
            let rate = max(rate, 1.0)
            if initialTimeInterval < .greatestFiniteMagnitude / rate {
                return initialTimeInterval * rate
            }
            return .greatestFiniteMagnitude
        }
    }

    /// Infinite retries using the provided delay strategy.
    case infinity(intervalProxy: IntervalProxy = .fixed())
    /// Retry up to `count` times with the provided delay strategy.
    case count(count: UInt, intervalProxy: IntervalProxy = .fixed())
    /// No retries.
    case never

    /// Returns the next retry state after consuming one attempt.
    public func next() -> Self {
        switch self {
        case let .infinity(intervalProxy: intervalProxy):
            return .infinity(intervalProxy: intervalProxy.next())
        case let .count(count: count, intervalProxy: intervalProxy):
            guard count > 1 else {
                return .never
            }
            return .count(count: count - 1, intervalProxy: intervalProxy.next())
        case .never:
            return .never
        }
    }

    /// Indicates whether another retry should be attempted.
    public var shouldRetry: Bool {
        switch self {
        case .never: false
        default: true
        }
    }

    /// The current delay (seconds) to wait before the next retry attempt.
    public var timeInterval: TimeInterval {
        switch self {
        case let .infinity(intervalProxy: intervalProxy):
            return intervalProxy.timeInterval
        case let .count(_, intervalProxy: intervalProxy):
            return intervalProxy.timeInterval
        case .never:
            return 0
        }
    }
}

/// Initialize a `RetryCount` using an integer literal.
///
/// - `0` becomes `.never`
/// - Any positive value `n` becomes `.count(count: n)` with default fixed delay 0
extension RetryCount: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt) {
        if value == 0 {
            self = .never
        } else {
            self = .count(count: value)
        }
    }
}
