import Foundation

public enum CacheRecord {
    case invalidKey
    case hitNullElement
    case hitNonNullElement
    case miss
}

/// Statistics tracker for cache performance monitoring
public struct CacheStatistics {
    private(set) static var tracingIDFactory = TracingIDFactory()

    private(set) var tracingID = tracingIDFactory.unsafeNextUInt64()

    /// Number of invalid key attempts
    private(set) var invalidKeyCount: Int = 0

    /// Number of null element hits
    private(set) var nullElementHitCount: Int = 0

    /// Number of non-null element hits
    private(set) var nonNullElementHitCount: Int = 0

    /// Number of cache misses
    private(set) var missCount: Int = 0

    public var report: ((Self, CacheRecord) -> Void)? = nil

    /// Total number of cache accesses
    public var totalAccesses: Int {
        return invalidKeyCount + nullElementHitCount + nonNullElementHitCount + missCount
    }

    /// Hit rate as a percentage (excluding invalid keys)
    public var hitRate: Double {
        let validAccesses = nullElementHitCount + nonNullElementHitCount + missCount
        guard validAccesses > 0 else { return 0.0 }
        return Double(nullElementHitCount + nonNullElementHitCount) / Double(validAccesses)
    }

    /// Overall success rate including invalid keys
    public var successRate: Double {
        guard totalAccesses > 0 else { return 0.0 }
        return Double(nullElementHitCount + nonNullElementHitCount) / Double(totalAccesses)
    }

    /// Record a cache result
    public mutating func record(_ result: CacheRecord) {
        switch result {
        case .invalidKey:
            invalidKeyCount += 1
        case .hitNullElement:
            nullElementHitCount += 1
        case .hitNonNullElement:
            nonNullElementHitCount += 1
        case .miss:
            missCount += 1
        }
        report?(self, result)
    }

    /// Reset all statistics
    public mutating func reset() {
        tracingID = Self.tracingIDFactory.unsafeNextUInt64()
        invalidKeyCount = 0
        nullElementHitCount = 0
        nonNullElementHitCount = 0
        missCount = 0
    }
}
