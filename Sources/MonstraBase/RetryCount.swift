//
//  RetryCount.swift
//  Monstask
//
//  Created by Larkin on 2025/7/20.
//

import Foundation

public enum RetryCount {
    public enum IntervalProxy {
        public static let DefaultInitialTimeInterval: TimeInterval = 1
        public static let DefaultExponentialBackoffScaleRate: Double = 2.0
        
        case fixed(timeInterval: TimeInterval = 0)
        case exponentialBackoff(initialTimeInterval: TimeInterval = DefaultInitialTimeInterval, scaleRate: Double = DefaultExponentialBackoffScaleRate)
        case exponentialBackoffBeforeFixed(
            initialTimeInterval: TimeInterval = DefaultInitialTimeInterval, 
            originalInitialInterval: TimeInterval = DefaultInitialTimeInterval,
            maxExponentialBackoffCount: UInt = 0, 
            scaleRate: Double = DefaultExponentialBackoffScaleRate
        )
        case exponentialBackoffAfterFixed(
            initialTimeInterval: TimeInterval = DefaultInitialTimeInterval,
            originalInitialInterval: TimeInterval = DefaultInitialTimeInterval,
            maxFixedCount: UInt = 0, 
            scaleRate: Double = DefaultExponentialBackoffScaleRate
        )
        
        public func next() -> Self {
            switch self {
            case .fixed(_):
                return self
            case .exponentialBackoff(initialTimeInterval: let initialTimeInterval, scaleRate: let rate):
                return .exponentialBackoff(initialTimeInterval: nextTimeInterval(of: initialTimeInterval, scale: rate), scaleRate: rate)
            case .exponentialBackoffBeforeFixed(initialTimeInterval: let initialTimeInterval, originalInitialInterval: let originalInterval, maxExponentialBackoffCount: let maxExponentialBackoffCount, scaleRate: let rate):
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
            case .exponentialBackoffAfterFixed(initialTimeInterval: let initialTimeInterval, originalInitialInterval: let originalInterval, maxFixedCount: let maxFixedCount, scaleRate: let rate):
                if maxFixedCount == 0 {
                    return .exponentialBackoff(initialTimeInterval: nextTimeInterval(of: initialTimeInterval, scale: rate), scaleRate: rate)
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
        
        public var timeInterval: TimeInterval {
            switch self {
            case .fixed(timeInterval: let timeInterval):
                return timeInterval
            case .exponentialBackoff(initialTimeInterval: let initialTimeInterval, _):
                return initialTimeInterval
            case .exponentialBackoffBeforeFixed(initialTimeInterval: let initialTimeInterval, _, _, _):
                return initialTimeInterval
            case .exponentialBackoffAfterFixed(initialTimeInterval: let initialTimeInterval, _, _, _):
                return initialTimeInterval
            }
        }
        
        private func nextTimeInterval(of initialTimeInterval: TimeInterval, scale rate: Double) -> TimeInterval {
            let rate = max(rate, 1.0)
            if initialTimeInterval < .greatestFiniteMagnitude / rate {
                return initialTimeInterval * rate
            }
            return .greatestFiniteMagnitude
        }
    }
    
    case infinity(intervalProxy: IntervalProxy = .fixed())
    case count(count: UInt, intervalProxy: IntervalProxy = .fixed())
    case never
    
    public func next() -> Self {
        switch self {
        case .infinity(intervalProxy: let intervalProxy):
            return .infinity(intervalProxy: intervalProxy.next())
        case .count(count: let count, intervalProxy: let intervalProxy):
            guard count > 1 else {
                return .never
            }
            return .count(count: count - 1, intervalProxy: intervalProxy.next())
        case .never:
            return .never
        }
    }
    
    public var shouldRetry: Bool {
        switch self {
        case .never: false
        default: true
        }
    }
    
    public var timeInterval: TimeInterval {
        switch self {
        case .infinity(intervalProxy: let intervalProxy):
            fallthrough
        case .count(_, intervalProxy: let intervalProxy):
            return intervalProxy.timeInterval
        case .never:
            return 0
        }
    }
}

extension RetryCount: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt) {
        if value == 0 {
            self = .never
        } else {
            self = .count(count: value)
        }
    }
}
