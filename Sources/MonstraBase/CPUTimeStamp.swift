import Foundation

/// Represents a high-precision CPU timestamp for accurate time measurements and cache expiration logic.
///
/// - Provides nanosecond-level precision using mach timebase.
/// - Supports arithmetic and comparison for time intervals and expiration checks.
public struct CPUTimeStamp {
    /// The timestamp value in seconds since CPU start.
    private let timestampSeconds: TimeInterval

    /// Mach timebase info for converting between different time units. Cached for performance.
    private static let timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Initialize with raw CPU ticks.
    private init(rawTicks: UInt64) {
        timestampSeconds = Self.convertTicksToSeconds(rawTicks)
    }

    /// Initialize with a time interval (seconds).
    private init(timeInterval: TimeInterval) {
        timestampSeconds = timeInterval
    }

    /// A timestamp representing positive infinity (never expires).
    public static let infinity: Self = .init(timeInterval: .infinity)

    /// Creates a timestamp representing the current moment.
    public static func now() -> Self { Self() }

    /// A timestamp representing zero time (epoch).
    public static var zero: Self = .init(timeInterval: 0.0)

    /// Initialize with current CPU time.
    public init() {
        self.init(rawTicks: mach_absolute_time())
    }

    /// Returns the time interval since CPU start in seconds.
    public func timeIntervalSinceCPUStart() -> TimeInterval { timestampSeconds }
}

// MARK: - Protocol Conformance

extension CPUTimeStamp: Hashable {}
extension CPUTimeStamp: Equatable {}

extension CPUTimeStamp: Comparable {
    /// Implements comparison between timestamps.
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.timestampSeconds < rhs.timestampSeconds
    }
}

// MARK: - Arithmetic Operations

public extension CPUTimeStamp {
    /// Adds a time interval to a timestamp.
    /// - Returns: A new timestamp offset by the specified interval.
    static func + (lhs: Self, rhs: TimeInterval) -> Self {
        Self(timeInterval: lhs.timestampSeconds + rhs)
    }

    /// Subtracts a time interval from a timestamp.
    /// - Returns: A new timestamp offset backwards by the specified interval.
    static func - (lhs: Self, rhs: TimeInterval) -> Self {
        Self(timeInterval: lhs.timestampSeconds - rhs)
    }

    /// Calculates the time interval between two timestamps.
    /// - Parameter other: The reference timestamp to measure against.
    /// - Returns: Time interval in seconds between the timestamps.
    func timeIntervalSince(_ other: Self) -> TimeInterval {
        timestampSeconds - other.timestampSeconds
    }

    /// Subtracts two timestamps to get the interval between them.
    /// - Returns: Time interval in seconds.
    static func - (lhs: Self, rhs: Self) -> TimeInterval {
        lhs.timestampSeconds - rhs.timestampSeconds
    }
}

// MARK: - Time Unit Conversion

private extension CPUTimeStamp {
    /// Converts CPU ticks to seconds using timebase info.
    /// Handles potential overflow by performing division before multiplication.
    static func convertTicksToSeconds(_ ticks: UInt64) -> TimeInterval {
        let nanos = (ticks / UInt64(Self.timebaseInfo.denom)) * UInt64(Self.timebaseInfo.numer)
        return TimeInterval(nanos) / TimeInterval(NSEC_PER_SEC)
    }
}
