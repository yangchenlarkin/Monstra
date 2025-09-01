import Foundation
import Combine

/// **MonoTask: Single-Instance Task Executor with TTL Caching and Retry Logic**
///
/// MonoTask is a thread-safe, high-performance task executor that ensures only one instance
/// of a task runs at a time while providing intelligent result caching and retry capabilities.
///
/// ## Key Features:
/// - **Execution Merging**: Multiple concurrent requests are merged into a single execution
/// - **TTL-based Caching**: Results are cached for a configurable duration to avoid redundant work
/// - **Retry Logic**: Automatic retry with exponential backoff for failed executions
/// - **Thread Safety**: Full thread safety with fine-grained locking using semaphores
/// - **Queue Management**: Separate queues for task execution and callback invocation
/// - **Manual Cache Control**: Manual cache invalidation with execution strategy options
///
/// ## Architecture:
/// ```
/// ┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
/// │   Execution     │    │   Caching    │    │   Callbacks     │
/// │   Merging       │───▶│   Layer      │───▶│   Distribution  │
/// │                 │    │              │    │                 │
/// │ • Single run    │    │ • TTL cache  │    │ • All waiters   │
/// │ • Merge calls   │    │ • Expiration │    │ • Same result   │
/// └─────────────────┘    └──────────────┘    └─────────────────┘
/// ```
///
/// ## Usage Examples:
/// ```swift
/// // Basic usage with caching
/// let task = MonoTask<String>(resultExpireDuration: 60.0) { callback in
///     // Expensive network call
///     URLSession.shared.dataTask(with: url) { data, _, error in
///         if let error = error {
///             callback(.failure(error))
///         } else {
///             callback(.success(String(data: data!, encoding: .utf8)!))
///         }
///     }.resume()
/// }
///
/// // Multiple concurrent calls - only one network request
/// let result1 = await task.asyncExecute() // Network call happens
/// let result2 = await task.asyncExecute() // Returns cached result
/// let result3 = await task.asyncExecute() // Returns cached result
///
/// // With retry logic
/// let retryTask = MonoTask<Data>(
///     retry: .count(count: 3, intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0, scaleRate: 2.0)),
///     resultExpireDuration: 300.0
/// ) { callback in
///     performNetworkRequest(callback)
/// }
///
/// // Manual cache control
/// task.clearResult(ongoingExecutionStrategy: .cancel) // Cancel and clear
/// ```
///
/// ## Thread Safety:
/// MonoTask uses two semaphores for fine-grained thread safety:
/// - `resultSemaphore`: Protects cached result and expiration state
/// - `callbackSemaphore`: Protects callback array and execution state
///
/// ## Performance:
/// - **Execution Merging**: Prevents duplicate work when multiple callers request same task
/// - **TTL Caching**: Avoids repeated expensive operations within cache period
/// - **Queue Separation**: Task execution and callback invocation can run on different queues
/// - **Memory Efficient**: Minimal overhead per task instance
///
/// - Note: This class is designed for expensive, idempotent operations like network requests,
///         database queries, or complex computations that benefit from caching and deduplication.
public class MonoTask<TaskResult> {
    // MARK: - Configuration Properties

    /// Retry configuration for failed executions (exponential backoff, fixed intervals, etc.)
    private let retry: RetryCount

    /// Time-to-live for cached results in seconds
    private let resultExpireDuration: TimeInterval

    /// The user-provided execution block that performs the actual work
    private let executeBlock: (@escaping ResultCallback) -> Void

    /// Queue where the actual task execution happens (can be background for expensive operations)
    private let taskQueue: DispatchQueue

    /// Queue where callbacks are invoked (can be main queue for UI updates)
    private let callbackQueue: DispatchQueue

    // MARK: - Result Caching State

    /// Timestamp when the cached result expires (using high-precision CPU timestamps)
    private var resultExpiresAt: CPUTimeStamp = .zero

    /// Semaphore protecting result and expiration state (semaphore)
    private var semaphore = DispatchSemaphore(value: 1)

    // MARK: - Execution Tracking

    /// Factory for generating unique execution IDs for tracking and cancellation
    private var executionIDFactory = TracingIDFactory()

    /// Current execution ID - used to ignore stale retry attempts after clearResult
    private var executionID: Int64?

    // MARK: - Callback Management

    /// Array of callbacks waiting for current execution (nil = not executing)
    /// When nil: Task is idle
    /// When non-nil: Task is executing, callbacks waiting for result
    private var waitingCallbacks: [ResultCallback]? {
        didSet {
            if let waitingCallbacks, waitingCallbacks.count > 0 {
                self.isExecuting = true
            } else {
                self.isExecuting = false
            }
        }
    }

    // MARK: - Initialization

    /// Private initializer to enforce use of public convenience initializers
    /// - Parameters:
    ///   - retry: Retry configuration for failed executions
    ///   - resultExpireDuration: Cache TTL in seconds
    ///   - taskQueue: Queue for executing the actual task
    ///   - callbackQueue: Queue for invoking callbacks
    ///   - executeBlock: User-provided task implementation
    private init(
        retry: RetryCount,
        resultExpireDuration: TimeInterval,
        taskQueue: DispatchQueue,
        callbackQueue: DispatchQueue,
        executeBlock: @escaping (@escaping ResultCallback) -> Void
    ) {
        self.retry = retry
        self.resultExpireDuration = resultExpireDuration
        self.taskQueue = taskQueue
        self.callbackQueue = callbackQueue
        self.executeBlock = executeBlock
    }

    // MARK: - Core Execution Logic

    /// Thread-safe execution coordinator that handles callback registration and execution merging
    ///
    /// This method is the main entry point for all execution requests. It:
    /// 1. Safely registers the callback in the waiting list
    /// 2. Determines if a new execution should be started (execution merging)
    /// 3. Starts execution only if no other execution is currently running
    ///
    /// **Thread Safety**: Protected by `callbackSemaphore`
    ///
    /// **Execution Merging**: Multiple concurrent calls to this method will:
    /// - All register their callbacks in the `_callbacks` array
    /// - Only the first call will trigger actual execution
    /// - All callbacks receive the same result when execution completes
    ///
    /// - Parameter completionCallback: Optional callback to invoke when execution completes
    private func _safe_execute(forceUpdate: Bool, then completionCallback: ResultCallback?) {
        semaphore.wait()
        defer { semaphore.signal() }

        if forceUpdate {
            // Force a fresh execution regardless of current state, while retaining cached result
            // 1) Ensure callbacks array exists to keep one-call-one-callback semantics
            if waitingCallbacks == nil {
                waitingCallbacks = [ResultCallback]()
            }

            // 2) Register callback for result notification
            if let completionCallback {
                waitingCallbacks!.append(completionCallback)
            }
            
            // 3) Schedule a brand-new execution and mark force scheduled
            _unsafe_execute(retry: retry)
            return
        }
        
        // === Phase 1: Check Cache Validity ===
        if let cachedResult = result, resultExpiresAt > .now() {
            // Cache hit! Always invoke callback on the designated callbackQueue
            if let completionCallback {
                callbackQueue.async {
                    completionCallback(.success(cachedResult))
                }
            }
            return
        }

        // === Phase 2: Prepare for Fresh Execution ===
        result = nil
        resultExpiresAt = .zero

        // Check if execution is already running
        let isAlreadyExecuting = waitingCallbacks != nil

        // Initialize callback array if needed (marks task as "executing")
        if waitingCallbacks == nil {
            waitingCallbacks = [ResultCallback]()
        }

        // Register callback for result notification
        if let completionCallback {
            waitingCallbacks!.append(completionCallback)
        }

        // Start execution only if not already running (execution merging)
        guard !isAlreadyExecuting else { return }

        _unsafe_execute(retry: retry)
    }

    /// Core execution method that handles caching, retry logic, and result distribution
    ///
    /// This method implements the main execution flow with intelligent caching:
    ///
    /// **Execution Flow**:
    /// 1. Check cache validity (TTL-based) - if valid, return cached result immediately
    /// 2. If cache expired/invalid, clear cache and generate new execution ID
    /// 3. Execute user's task block with result callback
    /// 4. On success: cache result and notify all waiting callbacks
    /// 5. On failure: retry if configured, otherwise notify callbacks with error
    ///
    /// **Execution ID Tracking**: Each execution gets a unique ID to handle race conditions:
    /// - If `clearResult()` is called during execution, execution ID changes
    /// - Stale retry attempts check their ID and abort if execution was cancelled
    ///
    /// **Thread Safety**: This method runs on `taskQueue` and uses `resultSemaphore`
    /// for cache state protection
    ///
    /// - Parameter retryConfiguration: Current retry configuration (decrements on each retry)
    private func _unsafe_execute(retry retryConfiguration: RetryCount) {
        executionID = executionIDFactory.safeNextInt64()
        
        taskQueue.async { [weak self] in
            guard let self else { return }

            semaphore.wait()
            // Generate new execution ID for tracking (important for clearResult cancellation)
            let currentExecutionID = executionIDFactory.safeNextInt64()
            self.executionID = currentExecutionID
            semaphore.signal()

            // === Phase 3: Execute User Task ===
            self.executeBlock { [weak self] executionResult in
                guard let self else { return }
                semaphore.wait()
                defer { semaphore.signal() }

                // Check if this execution was cancelled (execution ID changed)
                guard currentExecutionID == self.executionID else { return }
                self.executionID = executionIDFactory.safeNextInt64()

                // === Phase 4: Handle Success ===
                if case let .success(successData) = executionResult {
                    // Cache the result with TTL expiration
                    self.result = successData
                    self.resultExpiresAt = .now() + self.resultExpireDuration
                    _unsafe_callback(result: executionResult)
                    return
                }

                // === Phase 5: Handle Failure & Retry Logic ===

                // Retry if retry attempts are available
                if retryConfiguration.shouldRetry {
                    taskQueue.asyncAfter(deadline: .now() + retryConfiguration.timeInterval) {
                        self._unsafe_execute(retry: retryConfiguration.next())
                    }
                    return
                }

                // No more retries available, notify callbacks with final error
                _unsafe_callback(result: executionResult)
            }
        }
    }

    /// Thread-safe callback distribution system
    ///
    /// This method safely notifies all waiting callbacks with the execution result:
    ///
    /// **Callback Distribution Process**:
    /// 1. Move execution to callback queue (potentially main queue for UI updates)
    /// 2. Atomically extract all waiting callbacks and clear execution state
    /// 3. Invoke all callbacks with the same result
    /// 4. Transition task from "executing" to "idle" state
    ///
    /// **Thread Safety**: Uses `callbackQueue` and `callbackSemaphore` for safe
    /// callback array manipulation
    ///
    /// **State Transition**: After this method completes, the task transitions from
    /// "executing" to "idle" state (`waitingCallbacks` becomes nil)
    ///
    /// - Parameter executionResult: The result to distribute to all waiting callbacks
    private func _unsafe_callback(result executionResult: Result<TaskResult, Error>) {
        let callbacksToNotify = waitingCallbacks
        waitingCallbacks = nil // Task transitions to "idle" state

        callbackQueue.async {
            // Notify all callbacks with the same result
            guard let callbacksToNotify else { return }
            for callback in callbacksToNotify {
                callback(executionResult)
            }
        }
    }
    
    @Published public private(set) var result: TaskResult? = nil
    @Published public private(set) var isExecuting: Bool = false
}

// MARK: - Public API

public extension MonoTask {
    // MARK: - Type Aliases

    /// Callback signature for receiving task execution results
    /// - Parameter result: Success with TaskResult data or failure with Error
    typealias ResultCallback = (Result<TaskResult, Error>) -> Void

    /// Callback-based execution block signature for traditional async patterns
    /// - Parameter callback: Callback to invoke with result when task completes
    typealias CallbackExecution = (@escaping ResultCallback) -> Void

    /// Swift async/await execution block signature for modern async patterns
    /// - Returns: Result with success data or failure error
    typealias AsyncExecution = () async -> Result<TaskResult, Error>

    // MARK: - Convenience Initializers

    /// Create MonoTask with callback-based execution (traditional async pattern)
    ///
    /// Perfect for wrapping existing callback-based APIs like URLSession, Core Data, etc.
    ///
    /// **Example**:
    /// ```swift
    /// let networkTask = MonoTask<Data>(
    ///     retry: .count(count: 3, intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0)),
    ///     resultExpireDuration: 300.0 // 5 minutes
    /// ) { callback in
    ///     URLSession.shared.dataTask(with: url) { data, response, error in
    ///         if let error = error {
    ///             callback(.failure(error))
    ///         } else if let data = data {
    ///             callback(.success(data))
    ///         }
    ///     }.resume()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - retry: Retry configuration (default: no retries)
    ///   - resultExpireDuration: How long to cache results in seconds
    ///   - taskQueue: Queue where task execution happens (default: global background)
    ///   - callbackQueue: Queue where callbacks are invoked (default: global background)
    ///   - task: The callback-based task to execute
    convenience init(
        retry: RetryCount = .never,
        resultExpireDuration: TimeInterval,
        taskQueue: DispatchQueue = DispatchQueue.global(),
        callbackQueue: DispatchQueue = DispatchQueue.global(),
        task: @escaping CallbackExecution
    ) {
        self.init(
            retry: retry,
            resultExpireDuration: resultExpireDuration,
            taskQueue: taskQueue,
            callbackQueue: callbackQueue,
            executeBlock: task
        )
    }

    /// Create MonoTask with async/await execution (modern async pattern)
    ///
    /// Perfect for wrapping modern async APIs and Swift concurrency patterns.
    ///
    /// **Example**:
    /// ```swift
    /// let apiTask = MonoTask<APIResponse>(
    ///     retry: .count(count: 2, intervalProxy: .fixed(timeInterval: 2.0)),
    ///     resultExpireDuration: 60.0 // 1 minute
    /// ) {
    ///     do {
    ///         let response = try await APIClient.shared.fetchData()
    ///         return .success(response)
    ///     } catch {
    ///         return .failure(error)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - retry: Retry configuration (default: no retries)
    ///   - resultExpireDuration: How long to cache results in seconds
    ///   - taskQueue: Queue where task execution happens (default: global background)
    ///   - callbackQueue: Queue where callbacks are invoked (default: global background)
    ///   - task: The async task to execute
    convenience init(
        retry: RetryCount = .never,
        resultExpireDuration: TimeInterval,
        taskQueue: DispatchQueue = DispatchQueue.global(),
        callbackQueue: DispatchQueue = DispatchQueue.global(),
        task: @escaping AsyncExecution
    ) {
        self.init(
            retry: retry,
            resultExpireDuration: resultExpireDuration,
            taskQueue: taskQueue,
            callbackQueue: callbackQueue
        ) { callback in
            Task {
                await callback(task())
            }
        }
    }

    // MARK: - Execution Methods

    /// Execute task without waiting for result (fire-and-forget)
    ///
    /// Useful when you want to trigger execution but don't need the result immediately.
    /// The task will still benefit from caching and execution merging.
    ///
    /// **Example**:
    /// ```swift
    /// // Pre-warm cache
    /// task.justExecute()
    ///
    /// // Later, this will likely return cached result
    /// let result = await task.asyncExecute()
    /// ```
    func justExecute(forceUpdate: Bool = false) {
        _safe_execute(forceUpdate: forceUpdate, then: nil)
    }

    /// Execute task with callback-based result handling
    ///
    /// Perfect for integrating with callback-based code or when you need to handle
    /// results in a specific queue context.
    ///
    /// **Example**:
    /// ```swift
    /// task.execute { result in
    ///     switch result {
    ///     case .success(let data):
    ///         print("Got data: \(data)")
    ///     case .failure(let error):
    ///         print("Error: \(error)")
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter completionHandler: Optional callback to receive the result
    func execute(forceUpdate: Bool = false, then completionHandler: ResultCallback?) {
        _safe_execute(forceUpdate: forceUpdate, then: completionHandler)
    }

    /// Execute task with async/await and return Result type
    ///
    /// This is the recommended method for modern Swift code. Returns a Result type
    /// which allows explicit error handling without exceptions.
    ///
    /// **Example**:
    /// ```swift
    /// let result = await task.asyncExecute()
    /// switch result {
    /// case .success(let data):
    ///     // Handle success
    ///     updateUI(with: data)
    /// case .failure(let error):
    ///     // Handle error
    ///     showErrorMessage(error)
    /// }
    /// ```
    ///
    /// - Returns: Result containing either success data or failure error
    @discardableResult
    func asyncExecute(forceUpdate: Bool = false) async -> Result<TaskResult, Error> {
        return await withCheckedContinuation { continuation in
            self._safe_execute(forceUpdate: forceUpdate) { executionResult in
                continuation.resume(returning: executionResult)
            }
        }
    }

    /// Execute task with async/await and throw on failure
    ///
    /// Convenient when you want to use Swift's error throwing mechanism.
    /// Will throw the underlying error if execution fails.
    ///
    /// **Example**:
    /// ```swift
    /// do {
    ///     let data = try await task.executeThrows()
    ///     // Handle success case directly
    ///     updateUI(with: data)
    /// } catch {
    ///     // Handle any errors
    ///     showErrorMessage(error)
    /// }
    /// ```
    ///
    /// - Returns: The successful result data
    /// - Throws: The underlying error if execution fails
    @discardableResult
    func executeThrows(forceUpdate: Bool = false) async throws -> TaskResult {
        switch await withCheckedContinuation({ continuation in
            self._safe_execute(forceUpdate: forceUpdate) { executionResult in
                continuation.resume(returning: executionResult)
            }
        }) {
        case let .success(successValue): return successValue
        case let .failure(executionError): throw executionError
        }
    }

    // MARK: - State Properties

    /// Get currently cached result without triggering execution
    ///
    /// Returns the cached result if available and not expired, otherwise nil.
    /// This property respects TTL and will return nil for expired results.
    ///
    /// **Thread Safety**: This property is thread-safe and can be called from any queue
    ///
    /// **Use Cases**:
    /// - Check if data is available without triggering a potentially expensive operation
    /// - Display cached data immediately while triggering background refresh
    /// - Implement cache-first UI patterns
    ///
    /// **Example**:
    /// ```swift
    /// // Show cached data immediately if available
    /// if let cached = task.currentResult {
    ///     updateUI(with: cached)
    /// } else {
    ///     showLoadingSpinner()
    /// }
    ///
    /// // Trigger fresh execution
    /// task.execute { result in
    ///     hideLoadingSpinner()
    ///     // Handle result...
    /// }
    /// ```
    var currentResult: TaskResult? {
        semaphore.wait()
        defer { semaphore.signal() }

        // Check if cached result has expired based on TTL
        if resultExpiresAt <= .now() {
            // Cache expired, clear stale data
            result = nil
            resultExpiresAt = .zero
        }

        return result
    }

    // MARK: - Cache Management

    /// Strategy for handling ongoing execution when clearing cached results
    ///
    /// Defines how to handle a running task when `clearResult()` is called.
    enum OngoingExecutionStrategy {
        /// Cancel the current execution immediately and notify callbacks with cancellation error
        case cancel

        /// Allow current execution to complete, then automatically restart with fresh execution
        case restart

        /// Allow current execution to complete normally, just clear the cached result
        case allowCompletion
    }

    /// MonoTask-specific errors
    enum Errors: Error {
        /// Error sent to callbacks when execution is cancelled via clearResult(.cancel)
        case executionCancelledDueToClearResult
    }

    /// Manually invalidate cached result with fine-grained control over ongoing execution
    ///
    /// This method provides powerful cache management capabilities:
    ///
    /// **Execution State Handling**:
    /// - **If task is idle**: Simply clears cache, optionally starts fresh execution
    /// - **If task is executing**: Applies the chosen strategy for ongoing execution
    ///
    /// **Strategy Details**:
    /// - `.cancel`: Immediately cancels execution and notifies all callbacks with error
    /// - `.restart`: Lets execution complete, then starts fresh execution
    /// - `.allowCompletion`: Lets execution complete normally, just clears cache
    ///
    /// **Thread Safety**: Fully thread-safe, can be called from any queue
    ///
    /// **Use Cases**:
    /// ```swift
    /// // Force fresh data (cancel ongoing request)
    /// task.clearResult(ongoingExecutionStrategy: .cancel)
    ///
    /// // Clear cache but let current request complete
    /// task.clearResult(ongoingExecutionStrategy: .allowCompletion)
    ///
    /// // Clear cache and ensure fresh execution
    /// task.clearResult(ongoingExecutionStrategy: .restart, shouldRestartWhenIDLE: true)
    /// ```
    ///
    /// - Parameters:
    ///   - ongoingExecutionStrategy: How to handle currently running execution
    ///   - shouldRestartWhenIDLE: Whether to start new execution if task is idle
    func clearResult(
        ongoingExecutionStrategy: OngoingExecutionStrategy = .allowCompletion,
        shouldRestartWhenIDLE: Bool = false
    ) {
        semaphore.wait()
        defer { semaphore.signal() }

        // Always clear cached result and reset expiration timestamp
        result = nil
        resultExpiresAt = .zero

        if let callbacksToNotify = waitingCallbacks {
            // Task is currently executing - apply strategy
            switch ongoingExecutionStrategy {
            case .cancel:
                // Cancel and notify all waiting callbacks on the designated callbackQueue
                waitingCallbacks = nil
                executionID = executionIDFactory.safeNextInt64()
                callbackQueue.async {
                    for callback in callbacksToNotify {
                        callback(.failure(Errors.executionCancelledDueToClearResult))
                    }
                }
            case .restart:
                // Let current execution complete, then restart
                _unsafe_execute(retry: retry)
            case .allowCompletion:
                // Do nothing, let execution complete normally
                break
            }
        } else {
            // Task is idle - optionally start fresh execution
            if shouldRestartWhenIDLE {
                _unsafe_execute(retry: retry)
            }
        }
    }
}
