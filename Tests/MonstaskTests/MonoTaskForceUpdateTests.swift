@testable import Monstra
import XCTest
import Foundation

final class MonoTaskForceUpdateTests: XCTestCase {
    private actor Counter {
        private var value: Int = 0
        func next() -> Int { value += 1; return value }
        func get() -> Int { value }
    }

    /// Force update should start a new execution even if cache is valid, while callers without force
    /// still get cached result until the fresh execution completes.
    func testForceUpdateServesCachedThenRefreshes() async {
        let counter = Counter()

        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 5.0
        ) { callback in
            Task {
                let attempt = await counter.next()
                callback(.success("value_\(attempt)"))
            }
        }

        // Seed cache
        let r1 = await task.asyncExecute()
        if case let .success(v1) = r1 { XCTAssertEqual(v1, "value_1") } else { XCTFail() }
        XCTAssertEqual(task.currentResult, "value_1")

        // Start a force refresh
        let refreshed = Task { await task.asyncExecute(forceUpdate: true) }

        // While refreshing, non-force callers should still get cached value
        let r2 = await task.asyncExecute()
        if case let .success(v2) = r2 { XCTAssertEqual(v2, "value_1") } else { XCTFail() }

        // Force refresh completes with new value
        let r3 = await refreshed.value
        if case let .success(v3) = r3 { XCTAssertEqual(v3, "value_2") } else { XCTFail() }

        // Subsequent non-force calls get the refreshed value
        let r4 = await task.asyncExecute()
        if case let .success(v4) = r4 { XCTAssertEqual(v4, "value_2") } else { XCTFail() }

        let attempts = await counter.get()
        XCTAssertEqual(attempts, 2, "Should execute exactly twice (seed + refresh)")
    }

    /// Force update during an ongoing execution should replace it and notify all waiters once with fresh result.
    func testForceUpdateReplacesOngoingExecution() async {
        let counter = Counter()

        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 2.0
        ) { callback in
            Task {
                let attempt = await counter.next()
                try await Task.sleep(nanoseconds: 5_000_000_000)
                callback(.success("\(attempt)"))
            }
        }

        let resultCollector = ResultCollector<String>()

        // Start first execution
        task.execute { result in
            if case let .success(v) = result { Task { await resultCollector.add(v) } }
        }

        // Wait until first started
        
        XCTAssertTrue(task.isExecuting)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Issue force update while first is running; add two callers
        task.execute(forceUpdate: true) { result in
            if case let .success(v) = result { Task { await resultCollector.add(v) } }
        }
        task.execute(forceUpdate: true) { result in
            if case let .success(v) = result { Task { await resultCollector.add(v) } }
        }

        // Wait a bit for second to complete
        try? await Task.sleep(nanoseconds: 10_000_000_000)

        let results = await resultCollector.getResults()
        // All 3 callers should get exactly one callback with the second execution result
        XCTAssertEqual(results.count, 3)
        for r in results { XCTAssertTrue(r.contains("3"), "Got: \(r)") }

        let attempts = await counter.get()
        XCTAssertEqual(attempts, 3, "Should run 3 times (3rd delivered)")
    }

    /// Force update failure should not clear existing cached result; non-force calls still see cache.
    func testForceUpdateFailureKeepsCachedResult() async {
        let counter = Counter()

        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 5.0
        ) { callback in
            Task {
                let attempt = await counter.next()
                if attempt == 1 {
                    callback(.success("ok_1"))
                } else {
                    callback(.failure(NSError(domain: "Force", code: 1)))
                }
            }
        }

        // Seed success
        let r1 = try? await task.executeThrows()
        XCTAssertEqual(r1, "ok_1")
        XCTAssertEqual(task.currentResult, "ok_1")

        // Force an update that fails
        let result = await task.asyncExecute(forceUpdate: true)
        if case .failure = result {} else { XCTFail("Expected failure from force update") }

        // Cache remains intact
        XCTAssertEqual(task.currentResult, "ok_1")
        let r2 = try? await task.executeThrows()
        XCTAssertEqual(r2, "ok_1")
    }

    /// Multiple rapid force updates should result in only the last execution's result being delivered.
    func testMultipleRapidForceUpdatesDeliverLastResult() async {
        let counter = Counter()
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 50.0
        ) { callback in
            Task {
                let attempt = await counter.next()
                try? await Task.sleep(nanoseconds: 50_000_000)
                callback(.success("attempt_\(attempt)"))
            }
        }

        // Seed cache
        _ = await task.asyncExecute()

        let results = ResultCollector<String>()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 3 {
                group.addTask {
                    let r = await task.asyncExecute(forceUpdate: true)
                    if case let .success(v) = r { await results.add(v) }
                }
            }
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let outs = await results.getResults()
        XCTAssertEqual(outs.count, 3)
        // Due to restart semantics, only the last execution's result should be delivered to all
        for v in outs { XCTAssertEqual(v, "attempt_4") }
        // attempts: 1 (seed) + 3 force updates = 4
        let attempts = await counter.get()
        XCTAssertEqual(attempts, 4)
    }

    /// Force update path for throws API
    func testExecuteThrowsWithForceUpdate() async {
        let counter = Counter()
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 1.0
        ) { callback in
            Task {
                let attempt = await counter.next()
                callback(.success("T_\(attempt)"))
            }
        }

        let v1 = try? await task.executeThrows()
        XCTAssertEqual(v1, "T_1")

        let v2 = try? await task.executeThrows(forceUpdate: true)
        XCTAssertEqual(v2, "T_2")
    }

    /// Mixed force and non-force concurrent calls should each receive exactly one callback; last execution result wins
    func testMixedForceAndNonForceCallbacksCount() async {
        let counter = Counter()
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 0
        ) { callback in
            Task {
                let attempt = await counter.next()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                callback(.success("M_\(attempt)"))
            }
        }

        // Seed cache
        _ = await task.asyncExecute()

        let results = ResultCollector<String>()
        await withTaskGroup(of: Void.self) { group in
            // 3 non-force
            for i in 0..<3 {
                group.addTask {
                    let r = await task.asyncExecute()
                    if case let .success(v) = r { await results.add("n\(i)_\(v)") }
                }
            }
            
            // 3 force
            for i in 0..<3 {
                group.addTask {
                    let r = await task.asyncExecute(forceUpdate: true)
                    if case let .success(v) = r { await results.add("f\(i)_\(v)") }
                }
            }
        }

        let outs = await results.getResults()
        XCTAssertEqual(outs.count, 6)
        // All should carry the last execution's suffix
        let suffixes = Set(outs.compactMap { $0.split(separator: "_").last }.map(String.init))
        XCTAssertEqual(suffixes.count, 1)
    }

    /// isExecuting should toggle correctly during force update execution
    func testIsExecutingDuringForceUpdate() async {
        let task = MonoTask<String>(
            retry: .never,
            resultExpireDuration: 5.0
        ) { callback in
            Thread.sleep(forTimeInterval: 5)
            callback(.success("X"))
        }

        // Seed cache
        _ = await task.asyncExecute()
        XCTAssertFalse(task.isExecuting)

        // Start force update
        let t = Task { await task.asyncExecute(forceUpdate: true) }

        // Wait until started
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        XCTAssertTrue(task.isExecuting)

        // Finish
        _ = await t.value
        XCTAssertFalse(task.isExecuting)
    }
}

// Reuse test utility from MonoTaskTests
private actor ResultCollector<T> {
    private var values: [T] = []
    func add(_ v: T) { values.append(v) }
    func getResults() -> [T] { values }
}


