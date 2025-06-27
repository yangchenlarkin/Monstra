//
// CPUTimeStamp.swift
// A high-precision CPU timestamp implementation for performance measurement
//
// Created by Larkin on 2025/5/10.
//

import Foundation

/// Represents a high-precision CPU timestamp that can be used for accurate time measurements
struct CPUTimeStamp {
    /// Current timestamp value in seconds
    private let timestampSeconds: TimeInterval
    
    /// Mach timebase info for converting between different time units
    /// This is computed once and cached for performance
    private static let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
    
    /// Initialize with raw CPU ticks
    private init(rawTicks: UInt64) {
        self.timestampSeconds = Self.convertTicksToSeconds(rawTicks)
    }
    
    /// Initialize with time interval
    private init(timeInterval: TimeInterval) {
        self.timestampSeconds = timeInterval
    }
    
    static let infinity: Self = .init(timeInterval: .infinity)
    
    /// Creates a timestamp representing the current moment
    static func now() -> Self { Self() }
    
    /// A timestamp representing zero time (epoch)
    static var zero: Self = Self(timeInterval: 0.0)
    
    /// Initialize with current CPU time
    init() {
        self.init(rawTicks: mach_absolute_time())
    }
    
    /// Returns the time interval since CPU start in seconds
    func timeIntervalSinceCPUStart() -> TimeInterval { timestampSeconds }
}

// MARK: - Protocol Conformance
extension CPUTimeStamp: Hashable {}
extension CPUTimeStamp: Equatable {}

extension CPUTimeStamp: Comparable {
    /// Implements comparison between timestamps
    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestampSeconds < rhs.timestampSeconds
    }
}

// MARK: - Arithmetic Operations
extension CPUTimeStamp {
    /// Adds a time interval to a timestamp
    /// - Returns: A new timestamp offset by the specified interval
    static func + (lhs: Self, rhs: TimeInterval) -> Self {
        Self(timeInterval: lhs.timestampSeconds + rhs)
    }
    
    /// Subtracts a time interval from a timestamp
    /// - Returns: A new timestamp offset backwards by the specified interval
    static func - (lhs: Self, rhs: TimeInterval) -> Self {
        Self(timeInterval: lhs.timestampSeconds - rhs)
    }
    
    /// Calculates the time interval between two timestamps
    /// - Parameter other: The reference timestamp to measure against
    /// - Returns: Time interval in seconds between the timestamps
    func timeIntervalSince(_ other: Self) -> TimeInterval {
        self.timestampSeconds - other.timestampSeconds
    }
    
    /// Subtracts two timestamps to get the interval between them
    /// - Returns: Time interval in seconds
    static func - (lhs: Self, rhs: Self) -> TimeInterval {
        lhs.timestampSeconds - rhs.timestampSeconds
    }
}

// MARK: - Time Unit Conversion
private extension CPUTimeStamp {
    /// Converts CPU ticks to seconds using timebase info
    /// This handles potential overflow by performing division before multiplication
    static func convertTicksToSeconds(_ ticks: UInt64) -> TimeInterval {
        let nanos = (ticks / UInt64(Self.timebaseInfo.denom)) * UInt64(Self.timebaseInfo.numer)
        return TimeInterval(nanos) / TimeInterval(NSEC_PER_SEC)
    }
    
    /// Converts seconds to CPU ticks using timebase info
    /// This handles potential overflow by performing calculations in steps
    static func convertSecondsToTicks(_ seconds: TimeInterval) -> UInt64 {
        let nanos = seconds * TimeInterval(NSEC_PER_SEC)
        return (UInt64(nanos) / UInt64(Self.timebaseInfo.numer)) * UInt64(Self.timebaseInfo.denom)
    }
}
