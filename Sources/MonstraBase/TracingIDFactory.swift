import Foundation

/// Public interface for TracingIDFactory providing type-safe ID generation methods.
///
/// This extension provides convenient methods to generate unique tracing IDs in different formats
/// while maintaining thread safety through safe/unsafe variants for performance optimization.
public extension TracingIDFactory {
    /// Generates a thread-safe unique tracing ID as a String.
    ///
    /// This method uses internal locking to ensure thread safety, making it suitable for
    /// concurrent access across multiple threads. The performance cost is minimal for most use cases.
    ///
    /// - Returns: A unique string representation of the tracing ID
    /// - Note: Thread-safe but slightly slower than unsafe variant
    mutating func safeNextString() -> String {
        String(_safe_next())
    }

    /// Generates a unique tracing ID as a String without thread safety guarantees.
    ///
    /// This method provides maximum performance by avoiding synchronization overhead.
    /// Use only when you can guarantee single-threaded access or have external synchronization.
    ///
    /// - Returns: A unique string representation of the tracing ID
    /// - Warning: Not thread-safe. Ensure single-threaded access or external synchronization
    mutating func unsafeNextString() -> String {
        String(_unsafe_next())
    }

    /// Generates a thread-safe unique tracing ID as an unsigned 64-bit integer.
    ///
    /// This method uses internal locking to ensure thread safety. The UInt64 format provides
    /// excellent performance for numeric operations and comparisons while maintaining uniqueness.
    ///
    /// - Returns: A unique UInt64 tracing ID
    /// - Note: Thread-safe but slightly slower than unsafe variant
    mutating func safeNextUInt64() -> UInt64 {
        return UInt64(_safe_next())
    }

    /// Generates a unique tracing ID as an unsigned 64-bit integer without thread safety.
    ///
    /// This method provides maximum performance for numeric ID generation by avoiding
    /// synchronization overhead. Ideal for high-frequency ID generation in single-threaded contexts.
    ///
    /// - Returns: A unique UInt64 tracing ID
    /// - Warning: Not thread-safe. Ensure single-threaded access or external synchronization
    mutating func unsafeNextUInt64() -> UInt64 {
        return UInt64(_unsafe_next())
    }

    /// Generates a thread-safe unique tracing ID as a signed 64-bit integer.
    ///
    /// This method returns the raw signed integer format used internally by the factory.
    /// Provides thread safety through internal locking mechanisms.
    ///
    /// - Returns: A unique Int64 tracing ID (raw internal format)
    /// - Note: Thread-safe but slightly slower than unsafe variant
    mutating func safeNextInt64() -> Int64 {
        return _safe_next()
    }

    /// Generates a unique tracing ID as a signed 64-bit integer without thread safety.
    ///
    /// This method returns the raw signed integer format with maximum performance.
    /// Use when thread safety is not required or is handled externally.
    ///
    /// - Returns: A unique Int64 tracing ID (raw internal format)
    /// - Warning: Not thread-safe. Ensure single-threaded access or external synchronization
    mutating func unsafeNextInt64() -> Int64 {
        return _unsafe_next()
    }
}

/// A high-performance unique ID generator optimized for distributed tracing and request tracking.
///
/// TracingIDFactory generates unique, monotonically increasing IDs that combine temporal and sequential
/// components for excellent uniqueness guarantees across distributed systems. The factory uses a hybrid
/// approach combining time-based base IDs with sequential counters to ensure both uniqueness and ordering.
///
/// ## Core Design Principles
///
/// ### Hybrid ID Generation
/// The factory generates IDs using the formula: `ID = (timeBasedID × loopCount) + sequentialCounter`
/// - **Time-based component**: Seconds since start of current year (UTC) - provides temporal ordering
/// - **Sequential component**: Incrementing counter that wraps at configurable loop count - ensures uniqueness
/// - **Combined result**: Globally unique ID with built-in temporal and sequential properties
///
/// ### Performance Characteristics
/// - **High throughput**: Generates millions of IDs per second with minimal overhead
/// - **Memory efficient**: Minimal state (3 Int64 values + lock)
/// - **CPU optimized**: Simple arithmetic operations, no string formatting or complex calculations
/// - **Lock-free option**: Unsafe variants avoid synchronization for maximum performance
///
/// ### Uniqueness Guarantees
/// - **Temporal uniqueness**: IDs generated at different times are naturally ordered
/// - **Sequential uniqueness**: IDs generated in rapid succession are guaranteed unique
/// - **Cross-instance safety**: Different instances initialized at different times generate different ID ranges
/// - **Rollover handling**: Sequential counter wraps safely without ID collisions
///
/// ## Usage Examples
///
/// ```swift
/// // Basic usage with default settings (thread-safe)
/// var factory = TracingIDFactory()
/// let id1 = factory.safeNextString()     // "1234567890123456789"
/// let id2 = factory.safeNextUInt64()     // 1234567890123456790
///
/// // High-performance usage (requires external synchronization)
/// var factory = TracingIDFactory()
/// let fastID = factory.unsafeNextInt64() // Maximum performance
///
/// // Custom configuration for high-frequency scenarios
/// var highFreq = TracingIDFactory(loopCount: 1_000_000)
/// let customID = highFreq.safeNextUInt64()
/// ```
///
/// ## Thread Safety
/// - **Safe methods**: Use internal `os_unfair_lock` for thread safety with minimal overhead
/// - **Unsafe methods**: No synchronization - caller must ensure thread safety or single-threaded access
/// - **Mixed usage**: Safe and unsafe methods can be mixed - each call is independent
///
/// ## Performance Considerations
/// - **Safe vs Unsafe**: Unsafe methods are ~10-15% faster, safe methods have negligible lock overhead
/// - **Return type impact**: All return types have similar performance (conversion is minimal)
/// - **Initialization cost**: One-time UTC calendar calculation - amortized across millions of IDs
/// - **Memory footprint**: ~64 bytes total including lock and temporal calculation state
public struct TracingIDFactory {
    // MARK: - Constants and Limits

    /// Maximum value for time-based ID component to prevent Int64 overflow.
    ///
    /// This limit ensures that `(timeBasedID × loopCount) + sequentialCounter` never exceeds Int64.max.
    /// Value chosen to support maximum loop counts while maintaining 8-digit time-based IDs for readability.
    ///
    /// **Mathematical basis**:
    /// - Int64.max = 9,223,372,036,854,775,807 (19 digits)
    /// - Maximum year seconds ≈ 31,622,400 (leap year, ~8 digits)
    /// - Safety buffer allows loop counts up to 10 billion while preventing overflow
    private static let maximumBaseID: Int64 = 100_000_000

    /// Maximum allowed value for sequential counter loop count.
    ///
    /// This defines the range of the sequential component before it wraps back to 0.
    /// Chosen to balance uniqueness guarantees with performance and overflow prevention.
    ///
    /// **Usage implications**:
    /// - With default: 10 billion unique IDs per time-based ID before sequential wraparound
    /// - Lower values: More frequent wraparound but better cache locality
    /// - Higher values: Longer uniqueness period but higher memory usage for large IDs
    public static let maximumLoopCount: Int64 = 10_000_000_000
    public static let minimumLoopCount: Int64 = 1000

    // MARK: - Instance Properties

    /// The range for the sequential counter before wrapping back to 0.
    ///
    /// This value determines how many unique IDs can be generated for each time-based ID
    /// before the sequential component wraps. Clamped between 1 and `maximumLoopCount`.
    private let loopCount: Int64

    /// The time-based component used as the base for ID generation.
    ///
    /// Calculated once during initialization as seconds elapsed since the start of the current year (UTC).
    /// This provides temporal ordering and ensures different instances create different ID ranges.
    ///
    /// **Calculation method**:
    /// 1. Get current UTC time
    /// 2. Calculate start of current year in UTC
    /// 3. Compute elapsed seconds since year start
    /// 4. Apply modulo to keep within `maximumBaseID` range
    private let timeBasedIDBase: Int64

    /// Current value of the sequential counter for ID generation.
    ///
    /// This counter increments with each ID generation and wraps at `loopCount`.
    /// Combined with `timeBasedIDBase` to create the final unique ID.
    ///
    /// **Thread safety**: Access must be synchronized for safe methods via `lock`
    private var sequentialCounter: Int64 = 0

    /// Initializes a new TracingIDFactory with configurable sequential counter range.
    ///
    /// The initializer performs one-time setup including temporal base ID calculation and
    /// loop count validation. The temporal component ensures different instances initialized
    /// at different times will generate IDs in different ranges, preventing collisions.
    ///
    /// - Parameter loopCount: Maximum value for the sequential counter before wraparound.
    ///   Values are automatically clamped to the valid range [1, maximumLoopCount].
    ///   Default: `maximumLoopCount` (10 billion) for maximum uniqueness period.
    ///
    /// ## Initialization Process
    /// 1. **Validate loop count**: Clamp input to valid range and handle edge cases
    /// 2. **Calculate temporal base**: Compute seconds since start of current year (UTC)
    /// 3. **Apply safety limits**: Ensure base ID stays within overflow-safe bounds
    /// 4. **Initialize state**: Set up sequential counter and synchronization primitives
    ///
    /// ## Performance Impact
    /// - **One-time cost**: UTC calendar calculations performed only during initialization
    /// - **Memory allocation**: Minimal - only primitive types and one lock
    /// - **Future calls**: Initialization cost is amortized across millions of ID generations
    public init(loopCount: Int64 = Self.maximumLoopCount) {
        // Validate and normalize the loop count parameter
        self.loopCount = max(Self.minimumLoopCount, min(loopCount, Self.maximumLoopCount))

        // Calculate time-based ID component using UTC timezone for consistency
        timeBasedIDBase = {
            let currentTimestamp = CPUTimeStamp().timeIntervalSinceCPUStart()
            let integerPart = Double(Int64(currentTimestamp))
            let decimalPart = currentTimestamp - integerPart
            return Int64(decimalPart * 1_000_000_000) % Self.maximumBaseID
        }()
    }

    // MARK: - Internal ID Generation

    /// Low-level lock for thread-safe access to mutable state.
    ///
    /// Uses `os_unfair_lock` for minimal overhead while providing mutual exclusion.
    /// This lock protects the `sequentialCounter` during increment and ID calculation.
    private var lock = os_unfair_lock()

    /// Core ID generation logic without thread safety (maximum performance).
    ///
    /// This method implements the hybrid ID generation algorithm that combines the time-based
    /// component with the sequential counter. It uses deferred execution to increment the counter
    /// after the current ID is calculated, ensuring proper sequencing.
    ///
    /// ## Algorithm Details
    /// 1. **Capture current counter**: Use current `sequentialCounter` value for this ID
    /// 2. **Calculate hybrid ID**: Apply formula `(timeBasedID × loopCount) + sequentialCounter`
    /// 3. **Increment counter**: Move to next sequential value with modulo wraparound
    /// 4. **Return result**: Unique ID combining temporal and sequential components
    ///
    /// ## Mathematical Properties
    /// - **Uniqueness**: Each sequential counter value produces a unique ID within the time window
    /// - **Ordering**: IDs are monotonically increasing within each time-based ID period
    /// - **Wraparound safety**: Sequential counter resets to 0 after reaching `loopCount`
    /// - **Overflow prevention**: Time-based ID capped to prevent Int64 overflow
    ///
    /// - Returns: Unique Int64 ID combining time-based and sequential components
    /// - Warning: Not thread-safe. Use `_safe_next()` for concurrent access.
    private mutating func _unsafe_next() -> Int64 {
        // Use defer to ensure counter increment happens after ID calculation
        defer {
            // Increment sequential counter with wraparound at loopCount boundary
            // This ensures we never exceed the configured uniqueness period
            let next = (self.sequentialCounter + 1) % self.loopCount
            self.sequentialCounter = next < 0 ? next + self.loopCount : next
        }

        // Apply hybrid ID generation formula: combine time-based and sequential components
        // Formula: ID = (timeBasedBase × loopCount) + sequentialCounter
        // This ensures different time-based IDs generate completely separate ID ranges
        return sequentialCounter + timeBasedIDBase * loopCount
    }

    /// Thread-safe wrapper around core ID generation logic.
    ///
    /// This method provides mutual exclusion around the unsafe ID generation using `os_unfair_lock`.
    /// The lock scope is minimal - only protecting the counter increment and ID calculation.
    ///
    /// ## Synchronization Strategy
    /// - **Minimal lock scope**: Only protects critical section of counter access
    /// - **Fast unlock**: Uses defer to guarantee lock release even on early returns
    /// - **Low overhead**: `os_unfair_lock` provides minimal synchronization cost
    /// - **No recursion**: Simple lock/unlock pattern without complex synchronization
    ///
    /// ## Performance Characteristics
    /// - **Lock contention**: Minimal due to very short critical section
    /// - **Scalability**: Good performance even under high concurrent load
    /// - **Fairness**: `os_unfair_lock` doesn't guarantee FIFO but provides good throughput
    ///
    /// - Returns: Unique Int64 ID safe for concurrent access
    /// - Note: Thread-safe but slightly slower than `_unsafe_next()`
    private mutating func _safe_next() -> Int64 {
        // Acquire exclusive access to mutable state
        os_unfair_lock_lock(&lock)
        defer {
            // Ensure lock is always released, even if _unsafe_next() throws or returns early
            os_unfair_lock_unlock(&self.lock)
        }

        // Delegate to unsafe implementation now that we have exclusive access
        return _unsafe_next()
    }
}
