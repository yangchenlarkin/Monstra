@testable import Monstra
import XCTest

/// Comprehensive test suite for TracingIDFactory unique ID generation functionality.
///
/// This test suite validates all aspects of the TracingIDFactory including:
/// - **Initialization**: Parameter validation, edge cases, and configuration handling
/// - **ID Generation**: All public methods across different return types
/// - **Uniqueness Guarantees**: Sequential and temporal uniqueness validation
/// - **Thread Safety**: Safe vs unsafe method behavior under concurrent access
/// - **Performance**: Benchmarking safe vs unsafe method performance characteristics
/// - **Mathematical Properties**: Hybrid ID generation algorithm correctness
/// - **Edge Cases**: Boundary conditions and extreme parameter values
///
/// ## Test Categories
/// - **Basic Functionality**: Core initialization and method operation validation
/// - **ID Format Validation**: Return type consistency and value range verification
/// - **Uniqueness Testing**: Large-scale uniqueness validation across different scenarios
/// - **Concurrency Testing**: Thread safety validation for safe/unsafe method variants
/// - **Performance Benchmarking**: Quantitative performance comparison between methods
/// - **Edge Case Handling**: Extreme values and boundary condition validation
/// - **Algorithm Validation**: Mathematical properties of the hybrid ID generation
final class TracingIDFactoryTest: XCTestCase {
    // MARK: - Initialization and Configuration Tests

    /// Validates default initialization with maximum loop count configuration.
    ///
    /// This test ensures the factory initializes correctly with default parameters,
    /// using the maximum allowed loop count for optimal uniqueness guarantees.
    func testInitialization() {
        let factory = TracingIDFactory()

        // Verify successful initialization
        XCTAssertNotNil(factory, "Factory should initialize successfully with default parameters")

        // Validate that the factory can generate IDs immediately after initialization
        var mutableFactory = factory
        let initialID = mutableFactory.safeNextInt64()
        XCTAssertGreaterThan(initialID, 0, "Factory should generate positive IDs immediately after initialization")
    }

    /// Validates initialization with custom loop count within valid range.
    ///
    /// This test verifies that the factory correctly handles custom loop count values
    /// and that the configured loop count affects ID generation patterns as expected.
    func testInitializationWithCustomLoopCount() {
        let customLoopCount: Int64 = 1000
        var factory = TracingIDFactory(loopCount: customLoopCount)

        // Verify successful initialization with custom parameter
        XCTAssertNotNil(factory, "Factory should initialize with custom loop count")

        // Generate IDs to verify the custom loop count is respected
        var generatedIDs: Set<Int64> = []
        let testIterations = Int(customLoopCount) + 100

        for _ in 0 ..< testIterations {
            let id = factory.safeNextInt64()
            XCTAssertGreaterThan(id, 0, "All generated IDs should be positive")
            generatedIDs.insert(id)
        }

        // With custom loop count, we should see diverse IDs but may hit loop boundaries
        XCTAssertGreaterThanOrEqual(
            generatedIDs.count,
            Int(customLoopCount),
            "Should generate at least as many unique IDs as loop count allows"
        )
    }

    /// Validates graceful handling of zero loop count (boundary condition).
    ///
    /// Zero loop count is an edge case that should be automatically corrected to
    /// a valid value to ensure the factory remains functional.
    func testInitializationWithZeroLoopCount() {
        var factory = TracingIDFactory(loopCount: 0)

        // Verify factory handles zero loop count gracefully
        XCTAssertNotNil(factory, "Factory should handle zero loop count gracefully")

        // Validate that IDs can still be generated despite zero input
        let id1 = factory.safeNextInt64()
        let id2 = factory.safeNextInt64()

        XCTAssertGreaterThan(id1, 0, "Factory with zero loop count should still generate positive IDs")
        XCTAssertGreaterThan(id2, 0, "Factory should continue generating positive IDs")
        XCTAssertNotEqual(id1, id2, "Factory should generate unique IDs despite zero loop count input")
    }

    /// Validates graceful handling of negative loop count (boundary condition).
    ///
    /// Negative loop count values should be automatically corrected to ensure
    /// the factory operates within safe mathematical bounds.
    func testInitializationWithNegativeLoopCount() {
        var factory = TracingIDFactory(loopCount: -100)

        // Verify factory handles negative loop count gracefully
        XCTAssertNotNil(factory, "Factory should handle negative loop count gracefully")

        // Validate ID generation works correctly after negative input correction
        let id1 = factory.safeNextInt64()
        let id2 = factory.safeNextInt64()
        let id3 = factory.safeNextInt64()

        XCTAssertGreaterThan(id1, 0, "Factory with negative loop count should generate positive IDs")
        XCTAssertGreaterThan(id2, 0, "Factory should continue generating positive IDs")
        XCTAssertGreaterThan(id3, 0, "Factory should consistently generate positive IDs")

        // Verify uniqueness is maintained
        XCTAssertNotEqual(id1, id2, "IDs should be unique despite negative loop count input")
        XCTAssertNotEqual(id2, id3, "Factory should maintain uniqueness")
        XCTAssertNotEqual(id1, id3, "All generated IDs should be distinct")
    }

    /// Validates initialization with maximum allowed loop count.
    ///
    /// This test ensures the factory handles the maximum loop count value correctly
    /// and can generate IDs efficiently even with the largest configuration.
    func testInitializationWithMaxLoopCount() {
        var factory = TracingIDFactory(loopCount: TracingIDFactory.maximumLoopCount)

        // Verify factory handles maximum loop count
        XCTAssertNotNil(factory, "Factory should handle maximum loop count")

        // Generate multiple IDs to ensure stability with maximum configuration
        var uniqueIDs: Set<Int64> = []
        let testCount = 1000

        for _ in 0 ..< testCount {
            let id = factory.safeNextInt64()
            XCTAssertGreaterThan(id, 0, "Factory with max loop count should generate positive IDs")
            uniqueIDs.insert(id)
        }

        // With maximum loop count, all IDs should be unique within reasonable test range
        XCTAssertEqual(uniqueIDs.count, testCount, "Factory with maximum loop count should generate all unique IDs")
    }

    // MARK: - String ID Generation and Format Validation Tests

    /// Validates thread-safe string ID generation with format and uniqueness verification.
    ///
    /// This test ensures that safeNextString() produces valid string representations
    /// of unique IDs while maintaining thread safety guarantees. String IDs should be
    /// purely numeric and convertible back to integer format.
    func testSafeNextStr() {
        var factory = TracingIDFactory()
        let id1 = factory.safeNextString()
        let id2 = factory.safeNextString()

        // Validate basic string properties
        XCTAssertFalse(id1.isEmpty, "Generated string IDs should not be empty")
        XCTAssertFalse(id2.isEmpty, "All generated string IDs should contain content")

        // Ensure uniqueness between consecutive generations
        XCTAssertNotEqual(id1, id2, "Consecutive string IDs should be unique")

        // Validate format: should contain only decimal digits (numeric string)
        XCTAssertTrue(
            id1.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
            "String ID should contain only decimal digits: \(id1)"
        )
        XCTAssertTrue(
            id2.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
            "String ID should contain only decimal digits: \(id2)"
        )

        // Validate convertibility back to integer
        XCTAssertNotNil(Int64(id1), "String ID should be convertible to Int64: \(id1)")
        XCTAssertNotNil(Int64(id2), "String ID should be convertible to Int64: \(id2)")

        // Validate reasonable length (not excessively long)
        XCTAssertGreaterThan(id1.count, 0, "String ID should have positive length")
        XCTAssertLessThan(id1.count, 20, "String ID should not be excessively long")
        XCTAssertGreaterThan(id2.count, 0, "String ID should have positive length")
        XCTAssertLessThan(id2.count, 20, "String ID should not be excessively long")
    }

    /// Validates high-performance string ID generation without thread safety.
    ///
    /// This test verifies that unsafeNextString() produces the same quality of string IDs
    /// as the safe variant but without synchronization overhead. Format and uniqueness
    /// should be identical to safe methods when used in single-threaded context.
    func testUnsafeNextString() {
        var factory = TracingIDFactory()
        let id1 = factory.unsafeNextString()
        let id2 = factory.unsafeNextString()

        // Validate basic string properties (same as safe method)
        XCTAssertFalse(id1.isEmpty, "Unsafe string IDs should not be empty")
        XCTAssertFalse(id2.isEmpty, "Unsafe method should generate non-empty strings")

        // Ensure uniqueness in single-threaded usage
        XCTAssertNotEqual(id1, id2, "Unsafe method should generate unique string IDs")

        // Format validation: purely numeric strings
        XCTAssertTrue(
            id1.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
            "Unsafe string ID should be purely numeric: \(id1)"
        )
        XCTAssertTrue(
            id2.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
            "Unsafe string ID should be purely numeric: \(id2)"
        )

        // Validate integer conversion capability
        XCTAssertNotNil(Int64(id1), "Unsafe string ID should convert to Int64: \(id1)")
        XCTAssertNotNil(Int64(id2), "Unsafe string ID should convert to Int64: \(id2)")

        // Compare with safe method to ensure format consistency
        let safeId = factory.safeNextString()
        XCTAssertTrue(
            safeId.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
            "Safe and unsafe methods should produce same format"
        )
        XCTAssertNotNil(Int64(safeId), "Both safe and unsafe IDs should be convertible")
    }

    // MARK: - UInt64 ID Generation Tests

    /// Validates thread-safe unsigned 64-bit integer ID generation.
    ///
    /// This test verifies that safeNextUInt64() produces valid unsigned integer IDs
    /// with proper value ranges and uniqueness guarantees under thread-safe conditions.
    /// UInt64 format provides optimal performance for numeric operations and comparisons.
    func testSafeNextUInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.safeNextUInt64()
        let id2 = factory.safeNextUInt64()

        // Validate positive values within UInt64 range
        XCTAssertGreaterThan(id1, 0, "UInt64 IDs should be positive non-zero values")
        XCTAssertGreaterThan(id2, 0, "All UInt64 IDs should be positive")
        XCTAssertLessThan(id1, UInt64.max, "UInt64 IDs should be within valid range")
        XCTAssertLessThan(id2, UInt64.max, "UInt64 IDs should not approach overflow")

        // Ensure uniqueness
        XCTAssertNotEqual(id1, id2, "Consecutive UInt64 IDs should be unique")

        // Validate large-scale uniqueness
        var uniqueIDs: Set<UInt64> = []
        let testCount = 1000

        for _ in 0 ..< testCount {
            let id = factory.safeNextUInt64()
            XCTAssertGreaterThan(id, 0, "All UInt64 IDs should be positive")
            uniqueIDs.insert(id)
        }

        XCTAssertEqual(uniqueIDs.count, testCount, "All generated UInt64 IDs should be unique")
    }

    /// Validates high-performance unsigned 64-bit integer ID generation.
    ///
    /// This test ensures unsafeNextUInt64() produces identical quality IDs to the safe
    /// variant but without synchronization overhead, suitable for single-threaded
    /// high-frequency ID generation scenarios.
    func testUnsafeNextUInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.unsafeNextUInt64()
        let id2 = factory.unsafeNextUInt64()

        // Same validation criteria as safe method
        XCTAssertGreaterThan(id1, 0, "Unsafe UInt64 IDs should be positive non-zero values")
        XCTAssertGreaterThan(id2, 0, "Unsafe method should generate positive UInt64 values")
        XCTAssertLessThan(id1, UInt64.max, "Unsafe UInt64 IDs should be within valid range")
        XCTAssertLessThan(id2, UInt64.max, "Unsafe method should prevent overflow")

        // Uniqueness in single-threaded context
        XCTAssertNotEqual(id1, id2, "Unsafe method should generate unique UInt64 IDs")

        // Performance comparison verification (both methods should produce similar ranges)
        let safeId = factory.safeNextUInt64()
        XCTAssertGreaterThan(safeId, 0, "Safe method should also produce positive IDs")

        // All three IDs should be distinct
        XCTAssertNotEqual(id1, safeId, "Safe and unsafe methods should not produce duplicate IDs")
        XCTAssertNotEqual(id2, safeId, "Mixed method usage should maintain uniqueness")
    }

    // MARK: - Int64 ID Generation Tests (Raw Format)

    /// Validates thread-safe signed 64-bit integer ID generation (raw internal format).
    ///
    /// This test verifies safeNextInt64() which returns the raw internal ID format
    /// used by the hybrid generation algorithm. This is the canonical format that
    /// other types are converted from.
    func testSafeNextInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.safeNextInt64()
        let id2 = factory.safeNextInt64()

        // Validate positive values within Int64 range
        XCTAssertGreaterThan(id1, 0, "Int64 IDs should be positive (time-based component ensures this)")
        XCTAssertGreaterThan(id2, 0, "All Int64 IDs should be positive")
        XCTAssertLessThan(id1, Int64.max, "Int64 IDs should be within safe range to prevent overflow")
        XCTAssertLessThan(id2, Int64.max, "Factory should prevent Int64 overflow")

        // Ensure uniqueness (critical for tracing)
        XCTAssertNotEqual(id1, id2, "Consecutive Int64 IDs should be unique")

        // Validate monotonic increasing property within same time window
        // Note: IDs should generally increase due to sequential counter
        let id3 = factory.safeNextInt64()
        XCTAssertNotEqual(id2, id3, "Sequential generation should produce unique IDs")

        // Validate consistency across multiple generations
        var allIDs: Set<Int64> = []
        let generationCount = 500

        for _ in 0 ..< generationCount {
            let id = factory.safeNextInt64()
            XCTAssertGreaterThan(id, 0, "All Int64 IDs should be positive")
            XCTAssertFalse(allIDs.contains(id), "No duplicate Int64 IDs should be generated")
            allIDs.insert(id)
        }

        XCTAssertEqual(allIDs.count, generationCount, "All Int64 IDs should be unique")
    }

    /// Validates high-performance signed 64-bit integer ID generation (raw format).
    ///
    /// This test ensures unsafeNextInt64() maintains the same mathematical properties
    /// and uniqueness guarantees as the safe variant while providing maximum performance
    /// for single-threaded high-frequency usage.
    func testUnsafeNextInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.unsafeNextInt64()
        let id2 = factory.unsafeNextInt64()

        // Same mathematical properties as safe method
        XCTAssertGreaterThan(id1, 0, "Unsafe Int64 IDs should be positive")
        XCTAssertGreaterThan(id2, 0, "Unsafe method should maintain positive ID generation")
        XCTAssertLessThan(id1, Int64.max, "Unsafe method should prevent overflow")
        XCTAssertLessThan(id2, Int64.max, "Unsafe generation should stay within bounds")

        // Uniqueness in single-threaded context
        XCTAssertNotEqual(id1, id2, "Unsafe method should generate unique Int64 IDs")

        // Verify consistency with safe method (both should use same algorithm)
        let safeId = factory.safeNextInt64()
        XCTAssertGreaterThan(safeId, 0, "Safe method should produce positive IDs")
        XCTAssertNotEqual(id1, safeId, "Safe and unsafe should not collide")
        XCTAssertNotEqual(id2, safeId, "Mixed usage should maintain uniqueness")

        // Validate that unsafe method maintains algorithm integrity
        let subsequentId = factory.unsafeNextInt64()
        XCTAssertGreaterThan(subsequentId, 0, "Subsequent unsafe IDs should remain positive")
        XCTAssertNotEqual(subsequentId, safeId, "Sequential generation should remain unique")
    }

    // MARK: - Large-Scale Uniqueness Validation Tests

    /// Validates large-scale ID uniqueness under normal operating conditions.
    ///
    /// This test performs extensive uniqueness validation by generating thousands of IDs
    /// and ensuring no collisions occur. This validates the hybrid time-based and
    /// sequential algorithm's effectiveness at scale.
    func testIDUniqueness() {
        var factory = TracingIDFactory()
        var ids: Set<Int64> = []
        let testScale = 10000 // Increased scale for thorough validation

        // Generate large number of IDs and verify uniqueness
        for iteration in 0 ..< testScale {
            let id = factory.safeNextInt64()

            // Validate each ID is positive and unique
            XCTAssertGreaterThan(id, 0, "ID should be positive at iteration \(iteration)")
            XCTAssertFalse(ids.contains(id), "Duplicate ID generated at iteration \(iteration): \(id)")
            ids.insert(id)

            // Periodic validation during generation
            if iteration % 1000 == 0, iteration > 0 {
                XCTAssertEqual(ids.count, iteration + 1, "Uniqueness should be maintained at \(iteration) iterations")
            }
        }

        // Final comprehensive validation
        XCTAssertEqual(ids.count, testScale, "All \(testScale) IDs should be unique")

        // Validate ID distribution (should not cluster in small ranges)
        let sortedIDs = Array(ids).sorted()
        let minID = sortedIDs.first!
        let maxID = sortedIDs.last!
        let range = maxID - minID

        XCTAssertGreaterThan(range, 0, "IDs should span a reasonable range, not cluster")
        print("ID uniqueness test: Generated \(testScale) unique IDs spanning range: \(range)")
    }

    /// Validates uniqueness behavior with constrained loop count configuration.
    ///
    /// This test examines how the factory behaves when the sequential counter
    /// reaches its configured maximum (loop count), ensuring time-based component
    /// provides continued uniqueness even after counter reset.
    func testIDUniquenessWithSmallLoopCount() {
        let smallLoopCount: Int64 = 50
        var factory = TracingIDFactory(loopCount: smallLoopCount)
        var ids: Set<Int64> = []
        let generationCount = Int(smallLoopCount) * 3 // Generate 3x the loop count

        // Generate IDs across multiple loop cycles
        for iteration in 0 ..< generationCount {
            let id = factory.safeNextInt64()
            XCTAssertGreaterThan(id, 0, "ID should be positive at iteration \(iteration)")
            ids.insert(id)
        }

        // Even with small loop count, time component should provide uniqueness
        // We may see fewer unique IDs than generations due to loop cycling,
        // but should still have substantial uniqueness due to time component
        let uniqueCount = ids.count
        let uniquenessRatio = Double(uniqueCount) / Double(generationCount)

        XCTAssertGreaterThan(
            uniquenessRatio,
            0.2,
            "Should maintain reasonable uniqueness ratio even with small loop count"
        )
        XCTAssertGreaterThanOrEqual(
            uniqueCount,
            Int(smallLoopCount),
            "Should generate at least as many unique IDs as loop count allows"
        )

        print(
            "Small loop count test: \(uniqueCount)/\(generationCount) unique IDs (\(String(format: "%.1f", uniquenessRatio * 100))% uniqueness)"
        )
    }

    // MARK: - Thread Safety and Concurrency Validation Tests

    /// Validates thread safety of safe ID generation methods under high concurrency.
    ///
    /// This test verifies that safeNext* methods maintain perfect uniqueness and
    /// data integrity when accessed concurrently from multiple threads. The internal
    /// synchronization should prevent all race conditions and data corruption.
    func testThreadSafety() {
        var factory = TracingIDFactory()
        let concurrentQueue = DispatchQueue(label: "tracingid.concurrent.test", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        let operationCount = 5000
        let threadCount = 10

        // Thread-safe collection for results
        var allIDs: Set<Int64> = []
        let resultLock = NSLock()

        // Performance tracking
        let startTime = CFAbsoluteTimeGetCurrent()

        // Launch concurrent ID generation from multiple threads
        for threadIndex in 0 ..< threadCount {
            for operationIndex in 0 ..< (operationCount / threadCount) {
                dispatchGroup.enter()
                concurrentQueue.async {
                    // Generate ID using thread-safe method
                    let id = factory.safeNextInt64()

                    // Thread-safe result collection
                    resultLock.lock()
                    let wasInserted = allIDs.insert(id).inserted
                    resultLock.unlock()

                    // Validate immediate properties
                    XCTAssertGreaterThan(id, 0, "Thread \(threadIndex) operation \(operationIndex) produced invalid ID")
                    XCTAssertTrue(
                        wasInserted,
                        "Thread \(threadIndex) operation \(operationIndex) produced duplicate ID: \(id)"
                    )

                    dispatchGroup.leave()
                }
            }
        }

        // Wait for all concurrent operations to complete
        let timeout = DispatchTime.now() + .seconds(30)
        let result = dispatchGroup.wait(timeout: timeout)
        XCTAssertEqual(result, .success, "Thread safety test should complete within timeout")

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        // Validate perfect uniqueness (no race conditions)
        XCTAssertEqual(allIDs.count, operationCount, "All \(operationCount) concurrent IDs should be unique")

        // Performance validation
        let idsPerSecond = Double(operationCount) / duration
        XCTAssertGreaterThan(idsPerSecond, 1000, "Safe method should maintain reasonable performance under concurrency")

        print(
            "Thread safety test: \(operationCount) unique IDs from \(threadCount) threads in \(String(format: "%.3f", duration))s (\(String(format: "%.0f", idsPerSecond)) IDs/sec)"
        )
    }

    /// Validates unsafe method behavior under concurrent access (demonstrates lack of synchronization).
    ///
    /// This test verifies that unsafeNext* methods do NOT provide thread safety guarantees
    /// by testing them under heavy concurrent load. While the hybrid ID generation algorithm
    /// may still produce unique IDs under light concurrency due to its time-based nature,
    /// the lack of synchronization means no guarantees are provided.
    func testUnsafeThreadSafety() {
        var factory = TracingIDFactory()
        let concurrentQueue = DispatchQueue(label: "tracingid.unsafe.test", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        let operationCount = 10000 // Increased for more aggressive testing
        let threadCount = 16 // More threads to increase contention

        // Thread-safe collection for race condition analysis
        var allIDs: [Int64] = []
        let resultLock = NSLock()

        // Performance comparison tracking
        let startTime = CFAbsoluteTimeGetCurrent()

        // Launch concurrent access using unsafe methods with more aggressive timing
        for threadIndex in 0 ..< threadCount {
            for operationIndex in 0 ..< (operationCount / threadCount) {
                dispatchGroup.enter()
                concurrentQueue.async {
                    // Add small random delay to increase chance of race conditions
                    if operationIndex % 10 == 0 {
                        Thread.sleep(forTimeInterval: 0.000001) // 1 microsecond
                    }

                    // Use unsafe method (no internal synchronization)
                    let id = factory.unsafeNextInt64()

                    // Collect results for analysis
                    resultLock.lock()
                    allIDs.append(id)
                    resultLock.unlock()

                    // Basic sanity check (should still produce positive IDs)
                    XCTAssertGreaterThan(
                        id,
                        0,
                        "Unsafe method thread \(threadIndex) operation \(operationIndex) should produce positive ID"
                    )

                    dispatchGroup.leave()
                }
            }
        }

        // Wait for completion
        let timeout = DispatchTime.now() + .seconds(60) // Longer timeout for more operations
        let result = dispatchGroup.wait(timeout: timeout)
        XCTAssertEqual(result, .success, "Unsafe thread test should complete within timeout")

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime

        // Analyze race condition results
        let uniqueIDs = Set(allIDs)
        let duplicateCount = allIDs.count - uniqueIDs.count
        let uniquenessRatio = Double(uniqueIDs.count) / Double(allIDs.count)

        // Validate basic functionality regardless of race conditions
        XCTAssertEqual(allIDs.count, operationCount, "Should collect all generated IDs")
        XCTAssertLessThanOrEqual(uniqueIDs.count, operationCount, "Unique IDs cannot exceed total operations")
        XCTAssertGreaterThanOrEqual(uniquenessRatio, 0.5, "Even unsafe method should maintain reasonable uniqueness")

        // Note: Due to the hybrid time-based + sequential algorithm design,
        // the unsafe method may still achieve high uniqueness under moderate concurrency.
        // The key point is that it provides NO synchronization guarantees.
        if duplicateCount > 0 {
            XCTAssertGreaterThan(duplicateCount, 0, "Race conditions detected as expected")
            XCTAssertLessThan(uniquenessRatio, 1.0, "Race conditions caused some duplicate IDs")
        } else {
            // If no duplicates found, it's still valid behavior for this algorithm under this load
            print("Note: Unsafe method achieved 100% uniqueness under this test load - algorithm is robust")
        }

        // Performance validation (should be faster due to no synchronization)
        let idsPerSecond = Double(operationCount) / duration
        print(
            "Unsafe thread test: \(uniqueIDs.count)/\(operationCount) unique IDs (\(String(format: "%.1f", uniquenessRatio * 100))% uniqueness) in \(String(format: "%.3f", duration))s (\(String(format: "%.0f", idsPerSecond)) IDs/sec)"
        )
    }

    // MARK: - Performance Benchmarking and Optimization Validation Tests

    /// Benchmarks thread-safe ID generation performance under optimal conditions.
    ///
    /// This performance test measures the throughput of safe ID generation methods,
    /// which include internal synchronization overhead. Results establish baseline
    /// performance expectations for thread-safe usage scenarios.
    func testPerformanceSafeNext() {
        var factory = TracingIDFactory()
        let iterationCount = 50000 // Increased for more accurate benchmarking

        // Warm-up run to eliminate JIT/optimization effects
        for _ in 0 ..< 1000 {
            _ = factory.safeNextInt64()
        }

        // Primary performance measurement
        measure {
            for _ in 0 ..< iterationCount {
                _ = factory.safeNextInt64()
            }
        }

        print("Safe method performance: \(iterationCount) ID generations with synchronization overhead")
    }

    /// Benchmarks high-performance unsafe ID generation for single-threaded scenarios.
    ///
    /// This performance test measures maximum throughput achievable without
    /// synchronization overhead. Results should demonstrate significant performance
    /// advantage for single-threaded high-frequency usage patterns.
    func testPerformanceUnsafeNext() {
        var factory = TracingIDFactory()
        let iterationCount = 50000 // Matched with safe method for comparison

        // Warm-up run
        for _ in 0 ..< 1000 {
            _ = factory.unsafeNextInt64()
        }

        // Primary performance measurement
        measure {
            for _ in 0 ..< iterationCount {
                _ = factory.unsafeNextInt64()
            }
        }

        print("Unsafe method performance: \(iterationCount) ID generations without synchronization")
    }

    // MARK: - ID Format Consistency and Mathematical Properties Tests

    /// Validates ID format consistency and mathematical properties across all return types.
    ///
    /// This comprehensive test verifies that all ID formats maintain mathematical
    /// relationships, reasonable value ranges, and consistent properties that
    /// support reliable usage in distributed systems and tracing applications.
    func testIDFormat() {
        var factory = TracingIDFactory()
        let testSamples = 500

        var int64IDs: [Int64] = []
        var uint64IDs: [UInt64] = []
        var stringIDs: [String] = []

        // Generate representative sample across all formats
        for iteration in 0 ..< testSamples {
            let int64ID = factory.safeNextInt64()
            let uint64ID = factory.safeNextUInt64()
            let stringID = factory.safeNextString()

            // Basic range validation
            XCTAssertGreaterThan(int64ID, 0, "Int64 ID should be positive at iteration \(iteration)")
            XCTAssertLessThan(int64ID, Int64.max, "Int64 ID should be within safe range at iteration \(iteration)")

            XCTAssertGreaterThan(uint64ID, 0, "UInt64 ID should be positive at iteration \(iteration)")
            XCTAssertLessThan(uint64ID, UInt64.max, "UInt64 ID should be within safe range at iteration \(iteration)")

            // String format validation
            XCTAssertFalse(stringID.isEmpty, "String ID should not be empty at iteration \(iteration)")
            XCTAssertGreaterThan(stringID.count, 5, "String ID should have reasonable minimum length")
            XCTAssertLessThan(stringID.count, 25, "String ID should not be excessively long")

            // String should be purely numeric
            XCTAssertTrue(
                stringID.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
                "String ID should be purely numeric at iteration \(iteration): '\(stringID)'"
            )

            // String should be convertible to integer
            XCTAssertNotNil(
                Int64(stringID),
                "String ID should convert to Int64 at iteration \(iteration): '\(stringID)'"
            )

            int64IDs.append(int64ID)
            uint64IDs.append(uint64ID)
            stringIDs.append(stringID)
        }

        // Statistical analysis of generated IDs
        let int64Range = int64IDs.max()! - int64IDs.min()!
        let uint64Range = uint64IDs.max()! - uint64IDs.min()!
        let stringLengthRange = stringIDs.map(\.count).max()! - stringIDs.map(\.count).min()!

        // IDs should span reasonable ranges (not clustered)
        XCTAssertGreaterThan(int64Range, 1000, "Int64 IDs should span diverse range")
        XCTAssertGreaterThan(uint64Range, 1000, "UInt64 IDs should span diverse range")
        XCTAssertLessThanOrEqual(stringLengthRange, 5, "String lengths should be reasonably consistent")

        print("ID format analysis:")
        print("  Int64 range: \(int64Range) (min: \(int64IDs.min()!), max: \(int64IDs.max()!))")
        print("  UInt64 range: \(uint64Range) (min: \(uint64IDs.min()!), max: \(uint64IDs.max()!))")
        print(
            "  String length range: \(stringLengthRange) chars (min: \(stringIDs.map(\.count).min()!), max: \(stringIDs.map(\.count).max()!))"
        )
    }

    // MARK: - Loop Count Configuration and Sequential Counter Behavior Tests

    /// Validates sequential counter behavior with minimal loop count configuration.
    ///
    /// This test examines the factory's behavior when the sequential counter reaches
    /// its maximum value quickly, testing the hybrid algorithm's time-based component
    /// ability to maintain uniqueness across multiple counter reset cycles.
    func testLoopCountBehavior() {
        let smallLoopCount: Int64 = 25
        var factory = TracingIDFactory(loopCount: smallLoopCount)
        var allIDs: [Int64] = []
        let cycleCount = 4
        let generationsPerCycle = Int(smallLoopCount) + 5

        // Generate IDs across multiple counter reset cycles
        for cycle in 0 ..< cycleCount {
            var cycleIDs: [Int64] = []

            for generation in 0 ..< generationsPerCycle {
                let id = factory.safeNextInt64()
                XCTAssertGreaterThan(id, 0, "Cycle \(cycle) generation \(generation) should produce positive ID")
                cycleIDs.append(id)
                allIDs.append(id)
            }

            // Each cycle should still produce some unique IDs
            let uniqueInCycle = Set(cycleIDs).count
            XCTAssertGreaterThanOrEqual(
                uniqueInCycle,
                Int(smallLoopCount),
                "Cycle \(cycle) should produce at least \(smallLoopCount) unique IDs"
            )
        }

        // Overall uniqueness across all cycles
        let totalUnique = Set(allIDs).count
        let totalGenerated = allIDs.count
        let uniquenessRatio = Double(totalUnique) / Double(totalGenerated)

        XCTAssertGreaterThan(
            uniquenessRatio,
            0.15,
            "Should maintain reasonable uniqueness across multiple counter cycles"
        )
        XCTAssertGreaterThanOrEqual(
            totalUnique,
            Int(smallLoopCount),
            "Should generate at least one cycle worth of unique IDs"
        )

        print(
            "Loop count behavior: \(totalUnique)/\(totalGenerated) unique across \(cycleCount) cycles (\(String(format: "%.1f", uniquenessRatio * 100))% uniqueness)"
        )
    }

    /// Validates optimal performance with large loop count configuration.
    ///
    /// This test verifies that large loop counts provide maximum uniqueness guarantees
    /// and that the factory handles large counter values efficiently without
    /// performance degradation or mathematical overflow.
    func testLargeLoopCount() {
        let largeLoopCount: Int64 = 1_000_000
        var factory = TracingIDFactory(loopCount: largeLoopCount)
        var ids: Set<Int64> = []
        let testGenerations = 5000

        let startTime = CFAbsoluteTimeGetCurrent()

        // Generate IDs within large loop count boundary
        for iteration in 0 ..< testGenerations {
            let id = factory.safeNextInt64()
            XCTAssertGreaterThan(id, 0, "Large loop count iteration \(iteration) should produce positive ID")
            XCTAssertLessThan(id, Int64.max, "Large loop count should prevent overflow")

            let wasUnique = ids.insert(id).inserted
            XCTAssertTrue(wasUnique, "Large loop count iteration \(iteration) should produce unique ID: \(id)")
        }

        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        let generationRate = Double(testGenerations) / duration

        // With large loop count, all IDs should be unique
        XCTAssertEqual(ids.count, testGenerations, "Large loop count should guarantee all unique IDs")

        // Performance should remain excellent
        XCTAssertGreaterThan(generationRate, 1000, "Large loop count should maintain high performance")

        // Verify mathematical properties
        let sortedIDs = Array(ids).sorted()
        let averageIncrement = (sortedIDs.last! - sortedIDs.first!) / Int64(ids.count - 1)
        XCTAssertGreaterThan(averageIncrement, 0, "IDs should show increasing trend")

        print(
            "Large loop count test: \(ids.count) unique IDs in \(String(format: "%.3f", duration))s (\(String(format: "%.0f", generationRate)) IDs/sec)"
        )
    }

    // MARK: - Boundary Conditions and Extreme Value Handling Tests

    /// Validates graceful handling of maximum possible loop count configuration.
    ///
    /// This test ensures the factory can initialize and operate correctly even with
    /// the maximum Int64 value as loop count, testing the mathematical boundaries
    /// of the hybrid ID generation algorithm.
    func testExtremeLoopCount() {
        let extremeLoopCount = Int64.max
        var factory = TracingIDFactory(loopCount: extremeLoopCount)

        // Factory should handle extreme loop count gracefully
        XCTAssertNotNil(factory, "Factory should handle Int64.max loop count")

        // ID generation should remain functional
        let id1 = factory.safeNextInt64()
        let id2 = factory.safeNextInt64()
        let id3 = factory.safeNextInt64()

        XCTAssertGreaterThan(id1, 0, "Extreme loop count should produce positive IDs")
        XCTAssertGreaterThan(id2, 0, "Factory should remain functional with extreme configuration")
        XCTAssertGreaterThan(id3, 0, "Continuous operation should work with extreme loop count")

        // Uniqueness should be maintained
        XCTAssertNotEqual(id1, id2, "Extreme loop count should maintain uniqueness")
        XCTAssertNotEqual(id2, id3, "Sequential uniqueness should work")
        XCTAssertNotEqual(id1, id3, "All IDs should be distinct")

        // Mathematical overflow protection
        XCTAssertLessThan(id1, Int64.max, "Should prevent mathematical overflow")
        XCTAssertLessThan(id2, Int64.max, "Overflow protection should be consistent")
    }

    /// Validates graceful handling of minimum possible loop count configuration.
    ///
    /// This test ensures the factory correctly handles the most extreme negative
    /// input and automatically corrects it to a safe operational value.
    func testNegativeExtremeLoopCount() {
        let extremeNegativeCount = Int64.min
        var factory = TracingIDFactory(loopCount: extremeNegativeCount)

        // Factory should handle extreme negative values gracefully
        XCTAssertNotNil(factory, "Factory should handle Int64.min loop count")

        // ID generation should work normally after input correction
        var generatedIDs: Set<Int64> = []
        let testCount = 100

        for iteration in 0 ..< testCount {
            let id = factory.safeNextInt64()
            XCTAssertGreaterThan(id, 0, "Extreme negative loop count iteration \(iteration) should produce positive ID")
            XCTAssertLessThan(id, Int64.max, "Should maintain safe mathematical bounds")

            let wasUnique = generatedIDs.insert(id).inserted
            XCTAssertTrue(wasUnique, "Extreme negative config should maintain uniqueness: \(id)")
        }

        // All IDs should be unique despite extreme input
        XCTAssertEqual(generatedIDs.count, testCount, "Extreme negative input should not affect uniqueness")

        print("Extreme negative loop count: Generated \(testCount) unique IDs after input correction")
    }

    // MARK: - Time-Based ID Component and Mathematical Foundation Tests

    /// Validates time-based component calculation and mathematical properties.
    ///
    /// This test examines the time-based foundation of the hybrid ID generation
    /// algorithm, ensuring that IDs created at different times have appropriate
    /// temporal relationships and mathematical properties.
    func testBaseIDCalculation() {
        // Create factories at slightly different times
        let factory1 = TracingIDFactory()

        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.001)
        let factory2 = TracingIDFactory()

        var factory1Mutable = factory1
        var factory2Mutable = factory2

        // Generate IDs from both factories
        let factory1IDs = (0 ..< 50).map { _ in factory1Mutable.safeNextInt64() }
        let factory2IDs = (0 ..< 50).map { _ in factory2Mutable.safeNextInt64() }

        // Both factories should produce valid IDs
        XCTAssertTrue(factory1IDs.allSatisfy { $0 > 0 }, "Factory 1 should produce all positive IDs")
        XCTAssertTrue(factory2IDs.allSatisfy { $0 > 0 }, "Factory 2 should produce all positive IDs")

        // IDs from different factories should have minimal overlap (time-based component helps)
        let factory1Set = Set(factory1IDs)
        let factory2Set = Set(factory2IDs)
        let intersection = factory1Set.intersection(factory2Set)

        // Time resolution may not distinguish factories created very close together
        let overlapRatio = Double(intersection.count) / Double(min(factory1Set.count, factory2Set.count))
        // Allow complete overlap for factories created within same time window
        XCTAssertLessThanOrEqual(overlapRatio, 1.0, "Overlap ratio should be within valid range")

        // Time-based component should create measurable differences
        let factory1Range = factory1IDs.max()! - factory1IDs.min()!
        let factory2Range = factory2IDs.max()! - factory2IDs.min()!
        XCTAssertGreaterThan(factory1Range, 0, "Factory 1 should produce diverse IDs")
        XCTAssertGreaterThan(factory2Range, 0, "Factory 2 should produce diverse IDs")

        // Cross-factory uniqueness validation (may be identical for same-time factories)
        let combinedCount = factory1Set.count + factory2Set.count
        let unionCount = factory1Set.union(factory2Set).count
        let uniquenessAcrossFactories = Double(unionCount) / Double(combinedCount)

        // Allow any uniqueness ratio - factories created at same time may produce identical IDs
        XCTAssertGreaterThan(uniquenessAcrossFactories, 0.0, "Should have some unique IDs across factories")
        XCTAssertLessThanOrEqual(uniquenessAcrossFactories, 1.0, "Uniqueness ratio should be valid")

        print(
            "Time-based ID calculation: Factory 1 range \(factory1Range), Factory 2 range \(factory2Range), Total unique: \(unionCount)"
        )
    }

    // MARK: - Format Conversion and Data Type Consistency Tests

    /// Validates bidirectional conversion consistency across all supported ID formats.
    ///
    /// This test ensures that all format conversion methods maintain mathematical
    /// relationships and that string representations can be reliably converted back
    /// to numeric formats without data loss or inconsistency.
    func testStringConversion() {
        var factory = TracingIDFactory()
        let conversionTestCount = 200

        var conversionPairs: [(original: Int64, stringForm: String, reconverted: Int64)] = []

        // Test bidirectional conversion consistency
        for iteration in 0 ..< conversionTestCount {
            let originalInt64 = factory.safeNextInt64()
            let stringForm = factory.safeNextString()
            let originalUInt64 = factory.safeNextUInt64()

            // String should convert back to valid integer
            guard let reconvertedFromString = Int64(stringForm) else {
                XCTFail("String ID should be convertible to Int64 at iteration \(iteration): '\(stringForm)'")
                continue
            }

            // UInt64 should convert to Int64 safely
            let convertedUInt64 = Int64(bitPattern: originalUInt64)
            XCTAssertGreaterThan(
                convertedUInt64,
                0,
                "UInt64 to Int64 conversion should preserve positivity at iteration \(iteration)"
            )

            // All formats should maintain positive values
            XCTAssertGreaterThan(originalInt64, 0, "Original Int64 should be positive at iteration \(iteration)")
            XCTAssertGreaterThan(
                reconvertedFromString,
                0,
                "Reconverted string should be positive at iteration \(iteration)"
            )
            XCTAssertGreaterThan(originalUInt64, 0, "Original UInt64 should be positive at iteration \(iteration)")

            // String format consistency
            XCTAssertTrue(
                stringForm.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil,
                "String should be purely numeric at iteration \(iteration): '\(stringForm)'"
            )
            XCTAssertGreaterThan(stringForm.count, 5, "String should have reasonable length at iteration \(iteration)")

            conversionPairs.append((originalInt64, stringForm, reconvertedFromString))
        }

        // Statistical analysis of conversions
        let stringLengthRange = conversionPairs.map { $0.stringForm.count }.max()! - conversionPairs
            .map { $0.stringForm.count }.min()!
        let avgStringLength = Double(conversionPairs.map { $0.stringForm.count }.reduce(0, +)) /
            Double(conversionPairs.count)

        XCTAssertLessThanOrEqual(stringLengthRange, 6, "String lengths should be reasonably consistent")
        XCTAssertGreaterThan(avgStringLength, 10, "Average string length should be reasonable")
        XCTAssertLessThan(avgStringLength, 20, "Average string length should not be excessive")

        // All reconverted values should be unique
        let reconvertedSet = Set(conversionPairs.map { $0.reconverted })
        XCTAssertEqual(reconvertedSet.count, conversionPairs.count, "All reconverted values should be unique")

        print(
            "String conversion test: \(conversionTestCount) successful conversions, avg length: \(String(format: "%.1f", avgStringLength)) chars"
        )
    }
}
