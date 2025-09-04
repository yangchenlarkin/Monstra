import Foundation

/// Discrete outcomes recorded by the cache for statistics.
public enum CacheRecord {
    case invalidKey
    case hitNullElement
    case hitNonNullElement
    case miss
}

/// Statistics tracker for cache performance monitoring.
///
/// Tracks counts of cache results and computes derived metrics such as total accesses
/// and hit rates. A lightweight `report` callback can be attached to observe each record.
///
/// - Thread-safety: This type is not synchronized; coordinate access externally if needed.
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

    /// Optional callback invoked after every record to emit the latest statistics and result.
    public var report: ((Self, CacheRecord) -> Void)? = nil

    /// Total number of cache accesses (invalid + null-hit + non-null-hit + miss).
    public var totalAccesses: Int {
        return invalidKeyCount + nullElementHitCount + nonNullElementHitCount + missCount
    }

    /// Hit rate (excluding invalid keys). Range: 0.0 ... 1.0
    public var hitRate: Double {
        let validAccesses = nullElementHitCount + nonNullElementHitCount + missCount
        guard validAccesses > 0 else { return 0.0 }
        return Double(nullElementHitCount + nonNullElementHitCount) / Double(validAccesses)
    }

    /// Overall success rate including invalid keys. Range: 0.0 ... 1.0
    public var successRate: Double {
        guard totalAccesses > 0 else { return 0.0 }
        return Double(nullElementHitCount + nonNullElementHitCount) / Double(totalAccesses)
    }

    /// Records a cache result and triggers the optional report callback.
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

    /// Resets all statistics and assigns a new tracing ID.
    public mutating func reset() {
        tracingID = Self.tracingIDFactory.unsafeNextUInt64()
        invalidKeyCount = 0
        nullElementHitCount = 0
        nonNullElementHitCount = 0
        missCount = 0
    }
}
