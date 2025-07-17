//
//  Capacity.swift
//  Monstore
//
//  Created by Larkin on 2025/7/14.
//

import Foundation

/// Represents the capacity constraints for a cache, including memory usage and item count.
/// Used to configure cache limits for memory-sensitive or size-sensitive scenarios.
struct Capacity {
    /// The maximum memory usage allowed (in MB).
    let maxMemoryUsage: Int
    /// The maximum number of items allowed in the cache.
    let maxCount: Int

    /// A capacity with zero memory and zero items (effectively disables the cache).
    static let zero: Self = .init(maxMemoryUsage: 0, maxCount: 0)
    /// A capacity with no practical limits (uses Int.max for both fields).
    static let max: Self = .init(maxMemoryUsage: .max, maxCount: .max)
    /// Returns a capacity with a specific memory usage limit (in MB) and unlimited item count.
    static func memoryUsage(_ value: Int) -> Self {
        .init(maxMemoryUsage: value, maxCount: .max)
    }
    /// Returns a capacity with a specific item count limit and unlimited memory usage.
    static func count(_ value: Int) -> Self {
        .init(maxMemoryUsage: .max, maxCount: value)
    }
}

