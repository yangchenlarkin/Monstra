//
//  CacheStatistics.swift
//  Monstore
//
//  Created by Larkin on 2025/7/18.
//

import Foundation

enum CacheResult {
    case invalidKey
    case hitNullValue
    case hitNonNullValue
    case miss
}


/// Statistics tracker for cache performance monitoring
struct CacheStatistics {
    private(set) static var tracingIDFactory = TracingIDFactory()
    
    private(set) var tracingID = tracingIDFactory.unsafeNextUInt64()
    
    /// Number of invalid key attempts
    private(set) var invalidKeyCount: Int = 0
    
    /// Number of null value hits
    private(set) var nullValueHitCount: Int = 0
    
    /// Number of non-null value hits
    private(set) var nonNullValueHitCount: Int = 0
    
    /// Number of cache misses
    private(set) var missCount: Int = 0
    
    var report: ((Self, CacheResult) -> Void)? = nil
    
    /// Total number of cache accesses
    var totalAccesses: Int {
        return invalidKeyCount + nullValueHitCount + nonNullValueHitCount + missCount
    }
    
    /// Hit rate as a percentage (excluding invalid keys)
    var hitRate: Double {
        let validAccesses = nullValueHitCount + nonNullValueHitCount + missCount
        guard validAccesses > 0 else { return 0.0 }
        return Double(nullValueHitCount + nonNullValueHitCount) / Double(validAccesses)
    }
    
    /// Overall success rate including invalid keys
    var successRate: Double {
        guard totalAccesses > 0 else { return 0.0 }
        return Double(nullValueHitCount + nonNullValueHitCount) / Double(totalAccesses)
    }
    
    /// Record a cache result
    mutating func record(_ result: CacheResult) {
        switch result {
        case .invalidKey:
            invalidKeyCount += 1
        case .hitNullValue:
            nullValueHitCount += 1
        case .hitNonNullValue:
            nonNullValueHitCount += 1
        case .miss:
            missCount += 1
        }
        report?(self, result)
    }
    
    /// Reset all statistics
    mutating func reset() {
        tracingID = Self.tracingIDFactory.unsafeNextUInt64()
        invalidKeyCount = 0
        nullValueHitCount = 0
        nonNullValueHitCount = 0
        missCount = 0
    }
} 
