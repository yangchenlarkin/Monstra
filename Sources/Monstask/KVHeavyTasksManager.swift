//
//  KVHeavyTasksManager.swift
//  Monstra
//
//  Created by Larkin on 2025/7/27.
//
//  ## Overview
//  KVHeavyTasksManager is a sophisticated task management system designed for resource-intensive operations
//  that require careful coordination, caching, and lifecycle management. It serves as a centralized coordinator
//  for heavy computational tasks while providing robust concurrency control and memory optimization.
//
//  ## Supported Task Types
//  - **Large file downloads**: Videos, 3D models, datasets with progress tracking
//  - **Complex image processing**: Photo editing, AI-generated content, batch processing
//  - **Video encoding/decoding**: Format conversions, compression, streaming preparations
//  - **Machine learning inference**: Model predictions, data preprocessing, feature extraction
//  - **Database operations**: Large queries, bulk operations, data migrations
//  - **Network operations**: Multi-part uploads, API batching, distributed computing
//
//  ## Core Capabilities
//  - **Priority-based task scheduling**: LIFO/FIFO strategies with interruption support
//  - **Concurrent task execution**: Configurable limits with automatic load balancing
//  - **Intelligent caching**: Multi-level caching with TTL, memory limits, and statistics
//  - **Progress tracking**: Real-time updates with custom event publishing
//  - **Task lifecycle management**: Start/stop/resume with provider state preservation
//  - **Error handling & recovery**: Graceful degradation with detailed error propagation
//  - **Memory management**: Automatic cleanup with configurable resource limits
//  - **Thread safety**: Complete concurrency protection with minimal performance impact
//
//  ## Architecture Layers
//  1. **Public API**: Simple fetch interface with callback-based results
//  2. **Task Coordination**: Priority queues, concurrency control, and task routing  
//  3. **Cache Layer**: Multi-state caching (hit/miss/null/invalid) with validation
//  4. **Provider Management**: DataProvider lifecycle with dealloc/reuse strategies
//  5. **Event System**: Progress tracking and custom event broadcasting
//

import Foundation

/// Base class for heavy task data providers that defines the foundation for task execution.
///
/// This abstract base class provides the essential components that every heavy task data provider needs:
/// a unique key identifier, event publishing capabilities, and result delivery mechanisms.
/// It serves as the foundation for implementing concrete data providers that perform specific heavy operations.
///
/// ## Key Responsibilities
/// - **Task Identification**: Maintains unique key for task tracking and cache coordination
/// - **Event Broadcasting**: Provides mechanism for real-time progress and status updates  
/// - **Result Delivery**: Handles final result publishing with success/failure states
/// - **Type Safety**: Enforces generic type constraints for keys, elements, and events
///
/// ## Generic Parameters
/// - `K`: Key type (must be Hashable) used for task identification and caching
/// - `Element`: Result type returned upon successful task completion  
/// - `CustomEvent`: Event type for progress updates and status notifications
///
/// ## Usage Pattern
/// Concrete implementations should inherit from this class and implement the 
/// `KVHeavyTaskDataProviderInterface` protocol to provide actual task execution logic.
open class KVHeavyTaskBaseDataProvider<K: Hashable, Element, CustomEvent> {
    /// Callback type for publishing custom events during task execution.
    ///
    /// This closure is invoked to broadcast real-time updates such as:
    /// - Progress percentages and completion estimates
    /// - Status changes (starting, processing, pausing)
    /// - Custom metrics (throughput, error counts, quality metrics)
    /// - User-defined events specific to the task domain
    ///
    /// Events are published asynchronously to avoid blocking task execution.
    public typealias CustomEventPublisher = @Sendable (CustomEvent) -> Void
    
    /// Callback type for publishing the final task result.
    ///
    /// This closure is called exactly once per task execution to deliver:
    /// - **Success case**: Contains the computed result or nil for valid null results
    /// - **Failure case**: Contains detailed error information for debugging and recovery
    ///
    /// The callback is thread-safe and handles proper cleanup after result delivery.
    public typealias ResultPublisher = @Sendable (Result<Element?, Error>)->Void
    
    /// The unique identifier for this task instance.
    ///
    /// This key serves multiple purposes:
    /// - **Task identification**: Uniquely identifies this task across the system
    /// - **Cache coordination**: Used as cache key for result storage and retrieval  
    /// - **Deduplication**: Prevents duplicate tasks from running simultaneously
    /// - **Progress tracking**: Associates events and callbacks with specific tasks
    public internal(set) var key: K
    
    /// Publisher for broadcasting custom events during task execution.
    ///
    /// Use this callback to send real-time updates to observers. Events are delivered
    /// asynchronously on a global queue to prevent blocking the main task execution.
    /// Multiple observers can be registered for the same task key.
    public internal(set) var customEventPublisher: CustomEventPublisher
    
    /// Publisher for delivering the final task result.
    ///
    /// **Critical**: This callback must be called exactly once per task execution.
    /// Calling it multiple times or not calling it will result in undefined behavior,
    /// memory leaks, or hanging operations. The manager relies on this callback
    /// for proper task lifecycle management and resource cleanup.
    public internal(set) var resultPublisher: ResultPublisher
    
    /// Initializes a new heavy task data provider instance.
    ///
    /// This initializer sets up the essential communication channels between the data provider
    /// and the task manager. The provided callbacks are used for the entire lifecycle of the task.
    ///
    /// - Parameters:
    ///   - key: Unique identifier for this task (used for caching and deduplication)
    ///   - customEventPublisher: Callback for sending progress updates and custom events
    ///   - resultPublisher: Callback for delivering the final result (success or failure)
    ///
    /// - Note: Both publishers are thread-safe and can be called from any queue.
    /// - Warning: The resultPublisher must be called exactly once per task execution.
    required public init(key: K, customEventPublisher: @escaping CustomEventPublisher, resultPublisher: @escaping ResultPublisher) {
        self.key = key
        self.customEventPublisher = customEventPublisher
        self.resultPublisher = resultPublisher
    }
}

/// Defines the action to take when a DataProvider is stopped during task interruption.
///
/// This enum controls the lifecycle management of DataProvider instances when they are
/// interrupted by higher-priority tasks in LIFO(.stop) strategy. The choice between
/// reuse and dealloc affects memory usage, performance, and task resumption behavior.
///
/// ## Performance Implications
/// - **Reuse**: Lower memory allocation overhead, faster task resumption, higher memory usage
/// - **Dealloc**: Higher allocation overhead, slower resumption, lower memory footprint
///
/// ## Use Case Guidelines
/// - Choose **reuse** for tasks that are likely to resume soon or have expensive setup
/// - Choose **dealloc** for tasks with large memory footprint or unlikely to resume
public enum KVHeavyTaskDataProviderStopAction {
    /// Keep the DataProvider instance in memory for potential future resumption.
    ///
    /// **When to use**:
    /// - Tasks with expensive initialization (network connections, file handles, parsed data)
    /// - Frequently interrupted tasks that need quick resumption
    /// - Tasks where preserving intermediate state provides significant performance benefits
    ///
    /// **Trade-offs**:
    /// - ✅ Faster resumption (no re-initialization required)
    /// - ✅ Preserves computed intermediate results and state
    /// - ❌ Higher memory usage (provider remains in memory)
    /// - ❌ Potential memory leaks if tasks never resume
    case reuse
    
    /// Deallocate the DataProvider instance to free memory immediately.
    ///
    /// **When to use**:
    /// - Tasks with large memory footprint (large buffers, cached data, heavy objects)
    /// - Rarely resumed tasks or one-time operations
    /// - Memory-constrained environments where immediate cleanup is preferred
    ///
    /// **Trade-offs**:
    /// - ✅ Immediate memory reclamation and cleanup
    /// - ✅ Prevents potential memory leaks from abandoned tasks
    /// - ❌ Slower resumption (requires full re-initialization)
    /// - ❌ Loss of intermediate results and computed state
    case dealloc
}

/// Protocol defining the interface for heavy task data providers.
///
/// This protocol establishes the contract for implementing concrete data providers that execute
/// resource-intensive operations. All data providers must implement both start and stop methods
/// to ensure proper task lifecycle management and integration with the task manager.
///
/// ## Core Responsibilities
/// - **Task Execution**: Implement the actual heavy computation or I/O operation
/// - **Progress Reporting**: Publish real-time updates through the event system
/// - **Interruption Handling**: Gracefully respond to stop requests from the manager
/// - **State Management**: Maintain task state and support resumption when applicable
/// - **Error Handling**: Properly handle and report failures through the result system
///
/// ## Implementation Guidelines
/// - **Thread Safety**: Methods may be called from different threads; ensure proper synchronization
/// - **Cancellation**: Check for interruption periodically during long-running operations
/// - **Resource Management**: Clean up resources properly in both success and failure cases
/// - **Event Publishing**: Use customEventPublisher for progress updates, not result delivery
/// - **Result Delivery**: Call resultPublisher exactly once with the final outcome
///
/// ## Integration with Task Manager
/// The task manager handles:
/// - Provider instantiation and lifecycle management
/// - Event routing to registered observers
/// - Result caching and callback coordination
/// - Concurrency control and queue management
/// - Stop action processing (reuse vs dealloc)
///
/// ## Example Implementation Pattern
/// ```swift
/// class MyHeavyTaskProvider: KVHeavyTaskBaseDataProvider<String, Data, Progress>, KVHeavyTaskDataProviderInterface {
///     private var isStopped = false
///     
///     func start() {
///         // Validate input and setup
///         guard isValidKey(key) else { 
///             resultPublisher(.failure(ValidationError.invalidKey))
///             return 
///         }
///         
///         // Execute task with progress updates
///         performHeavyOperation { progress in
///             guard !isStopped else { return }
///             customEventPublisher(progress)
///         } completion: { result in
///             resultPublisher(result)
///         }
///     }
///     
///     func stop() -> KVHeavyTaskDataProviderStopAction {
///         isStopped = true
///         return shouldPreserveState ? .reuse : .dealloc
///     }
/// }
/// ```
public protocol KVHeavyTaskDataProviderInterface {
    /// Initiates the execution of the heavy task.
    ///
    /// This method contains the core logic for performing the resource-intensive operation.
    /// It should handle the complete task lifecycle from initialization to completion,
    /// including progress reporting and error handling.
    ///
    /// ## Implementation Requirements
    /// - **Result Publishing**: Must call `resultPublisher` exactly once with success or failure
    /// - **Progress Updates**: Should use `customEventPublisher` for real-time status updates
    /// - **Interruption Handling**: Must check for stop conditions periodically
    /// - **Error Management**: Handle all exceptions and report through result publisher
    /// - **Resource Cleanup**: Ensure proper cleanup regardless of completion method
    ///
    /// ## Threading Considerations
    /// - This method may be called from any thread
    /// - Long-running operations should not block the calling thread
    /// - Use appropriate queues for I/O operations and CPU-intensive work
    /// - Publishers are thread-safe and can be called from any context
    ///
    /// ## Performance Guidelines
    /// - Minimize setup overhead for frequently created/destroyed providers
    /// - Use efficient data structures for intermediate state
    /// - Consider memory usage, especially for tasks that may be interrupted
    /// - Implement appropriate cancellation points for responsive interruption
    func start()
    
    /// Gracefully stops the currently executing task and determines cleanup strategy.
    ///
    /// This method is called by the task manager when a higher-priority task requires
    /// resources or when the task needs to be cancelled. The implementation should
    /// stop the current operation as quickly as possible while preserving data integrity.
    ///
    /// ## Return Value Significance
    /// The returned `KVHeavyTaskDataProviderStopAction` determines what happens to this
    /// provider instance:
    /// - **`.reuse`**: Provider stays in memory and can resume later from current state
    /// - **`.dealloc`**: Provider is deallocated immediately to free memory
    ///
    /// ## Implementation Guidelines
    /// - **Quick Response**: Should return promptly (typically < 100ms)
    /// - **State Preservation**: For `.reuse`, maintain enough state to resume effectively
    /// - **Clean Shutdown**: For `.dealloc`, ensure all resources are properly cleaned up
    /// - **Thread Safety**: Must be safe to call concurrently with `start()`
    /// - **Idempotency**: Safe to call multiple times without side effects
    ///
    /// ## Strategy Selection Criteria
    /// Consider returning `.reuse` when:
    /// - Task has expensive initialization or setup phase
    /// - Intermediate results are valuable and should be preserved
    /// - Task is likely to be resumed soon (high priority, frequent access)
    /// - Memory usage is reasonable and won't cause pressure
    ///
    /// Consider returning `.dealloc` when:
    /// - Task has large memory footprint that should be freed immediately
    /// - Task is unlikely to be resumed (low priority, infrequent access)
    /// - Setup cost is low and re-initialization is acceptable
    /// - System is under memory pressure
    ///
    /// - Returns: Strategy for handling this provider after stop (.reuse or .dealloc)
    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction
}

public extension KVHeavyTaskDataProviderInterface {
    func resume() async {}
}

/// Configuration types for KVHeavyTasksManager that define task execution behavior.
///
/// The Config system provides comprehensive control over task scheduling, concurrency,
/// caching, and resource management. Each setting affects performance, memory usage,
/// and task execution patterns in different ways.
public extension KVHeavyTasksManager {
    /// Configuration structure that controls all aspects of task manager behavior.
    ///
    /// This configuration is immutable after manager initialization, ensuring consistent
    /// behavior throughout the manager's lifecycle. Choose settings based on your specific
    /// use case requirements for performance, memory usage, and task prioritization needs.
    struct Config {
        /// Defines how new tasks handle currently running tasks in LIFO priority mode.
        ///
        /// This strategy only applies when using `PriorityStrategy.LIFO(strategy)` and determines
        /// the behavior when a new high-priority task needs resources that are currently in use.
        ///
        /// ## Performance Characteristics
        /// - **`.await`**: Lower interruption overhead, predictable completion times
        /// - **`.stop`**: Higher responsiveness, potential task restart overhead
        ///
        /// ## Memory Implications
        /// - **`.await`**: Gradual memory usage patterns, no sudden spikes
        /// - **`.stop`**: Potential memory spikes from simultaneous task states
        public enum LIFOStrategy {
            /// New tasks wait for currently running tasks to complete naturally.
            ///
            /// **Behavior**: When a new high-priority task is added, it joins the queue
            /// and waits for running tasks to finish before starting execution.
            ///
            /// **Best for**:
            /// - Scenarios where task interruption is expensive or problematic
            /// - Operations that don't handle interruption gracefully
            /// - Systems where predictable completion times are more important than responsiveness
            /// - Tasks with complex state that's difficult to preserve across interruptions
            ///
            /// **Trade-offs**:
            /// - ✅ No interruption overhead or complexity
            /// - ✅ Guaranteed task completion without restarts
            /// - ✅ Simpler debugging and monitoring
            /// - ❌ Lower responsiveness for high-priority tasks
            /// - ❌ Potential priority inversion in some scenarios
            case await
            
            /// New tasks stop currently running tasks to start immediately.
            ///
            /// **Behavior**: When a new high-priority task is added, it immediately stops
            /// one or more running tasks, moves them to the waiting queue, and starts execution.
            /// Stopped tasks are automatically restarted when resources become available.
            ///
            /// **Best for**:
            /// - Interactive applications where responsiveness is critical
            /// - Tasks that support efficient state preservation and resumption
            /// - Scenarios with clear priority hierarchies (user-initiated vs background tasks)
            /// - Operations where recent requests are more valuable than older ones
            ///
            /// **Trade-offs**:
            /// - ✅ Maximum responsiveness for high-priority tasks
            /// - ✅ Better resource utilization in dynamic priority scenarios
            /// - ✅ Natural handling of priority changes during execution
            /// - ❌ Additional complexity from task interruption and resumption
            /// - ❌ Potential efficiency loss from task restarts (if using .dealloc)
            /// - ❌ More complex debugging due to task state transitions
            case stop
        }
        
        /// Defines the overall task execution order and priority handling strategy.
        ///
        /// This is the primary control for task scheduling behavior and significantly
        /// affects both performance characteristics and resource usage patterns.
        ///
        /// ## Choosing the Right Strategy
        /// - **FIFO**: Use for batch processing, fair resource allocation, or when task order matters
        /// - **LIFO(.await)**: Use for responsive systems with predictable task completion
        /// - **LIFO(.stop)**: Use for highly interactive systems with dynamic priorities
        public enum PriorityStrategy {
            /// First In, First Out - tasks execute in submission order.
            ///
            /// **Characteristics**:
            /// - Fair resource allocation across all submitted tasks
            /// - Predictable execution order regardless of timing
            /// - No task interruption or complex state management
            /// - Consistent performance characteristics
            ///
            /// **Ideal use cases**:
            /// - Batch processing systems where order matters
            /// - Background processing where fairness is important
            /// - Systems with relatively uniform task priorities
            /// - Operations where interruption would be problematic
            case FIFO
            
            /// Last In, First Out - most recent tasks get priority.
            ///
            /// **Characteristics**:
            /// - Recent tasks are prioritized over older submissions
            /// - Supports both non-interrupting (.await) and interrupting (.stop) modes
            /// - Better responsiveness for user-initiated operations
            /// - More complex resource management and state handling
            ///
            /// **Ideal use cases**:
            /// - Interactive applications where recent requests matter most
            /// - Systems with dynamic priority requirements
            /// - User-facing operations that should feel responsive
            /// - Scenarios where newer data/requests invalidate older ones
            ///
            /// - Parameter strategy: How to handle resource conflicts with running tasks
            case LIFO(LIFOStrategy)
        }
        
        /// Maximum number of tasks that can wait in the queue simultaneously.
        ///
        /// This setting controls memory usage and prevents unbounded queue growth.
        /// When the queue is full, new tasks evict older waiting tasks based on the
        /// priority strategy (FIFO evicts oldest, LIFO evicts based on strategy).
        ///
        /// **Tuning Guidelines**:
        /// - **Low values (10-50)**: Better memory control, risk of task eviction
        /// - **High values (100+)**: Lower eviction risk, higher memory usage
        /// - **Consider**: Peak load, task submission rate, average task duration
        public let maxNumberOfQueueingTasks: Int
        
        /// Maximum number of tasks that can execute concurrently.
        ///
        /// This setting directly controls resource usage and system load. The optimal
        /// value depends on task characteristics, system resources, and performance requirements.
        ///
        /// **Tuning Guidelines**:
        /// - **CPU-bound tasks**: Typically equals number of CPU cores
        /// - **I/O-bound tasks**: Can be higher than CPU cores (2x-4x)
        /// - **Memory-intensive tasks**: Lower values to prevent memory pressure
        /// - **Mixed workloads**: Start conservative and monitor performance
        ///
        /// **Trade-offs**:
        /// - Higher values: Better throughput, higher resource usage
        /// - Lower values: Better resource control, potential throughput limitation
        public let maxNumberOfRunningTasks: Int
        
        /// Strategy for determining task execution order and priority handling.
        ///
        /// This setting affects the entire task scheduling behavior and should be chosen
        /// based on the specific requirements of your application's task characteristics.
        public let priorityStrategy: PriorityStrategy
        
        /// Configuration for caching completed task results.
        ///
        /// The cache prevents duplicate task execution and provides immediate results
        /// for previously computed tasks. Configure based on result value characteristics,
        /// memory constraints, and access patterns.
        ///
        /// **Key settings to consider**:
        /// - **Memory limits**: Prevent cache from consuming too much memory
        /// - **TTL (Time To Live)**: How long results remain valid
        /// - **Key validation**: Filter out invalid or malformed keys
        /// - **Eviction policy**: How to handle cache capacity limits
        public let cacheConfig: MemoryCache<K, Element>.Configuration
        
        /// Optional callback for monitoring cache performance and behavior.
        ///
        /// This callback provides detailed statistics about cache hits, misses, evictions,
        /// and memory usage. Use for performance monitoring, debugging, and optimization.
        ///
        /// **Provided statistics include**:
        /// - Hit/miss ratios and counts
        /// - Memory usage and capacity utilization
        /// - Eviction counts and reasons
        /// - Access patterns and timing information
        public let cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)?
        
        /// Initializes a new KVHeavyTasksManager configuration with specified parameters.
        ///
        /// This initializer provides sensible defaults for most use cases while allowing
        /// full customization of all behavioral aspects. The defaults are optimized for
        /// general-purpose heavy task management with balanced performance and resource usage.
        ///
        /// ## Default Value Rationale
        /// - **50 queuing tasks**: Balances memory usage with eviction avoidance
        /// - **4 concurrent tasks**: Suitable for most I/O-bound operations on multi-core systems
        /// - **LIFO(.await)**: Responsive to recent requests without interruption complexity
        /// - **Default cache config**: Reasonable memory limits with basic TTL support
        /// - **No statistics reporting**: Minimal overhead for production use
        ///
        /// - Parameters:
        ///   - maxNumberOfQueueingTasks: Maximum tasks in waiting queue (default: 50)
        ///   - maxNumberOfRunningTasks: Maximum concurrent task execution (default: 4)
        ///   - priorityStrategy: Task execution order and priority handling (default: .LIFO(.await))
        ///   - cacheConfig: Cache configuration for task results (default: .defaultConfig)
        ///   - cacheStatisticsReport: Optional statistics monitoring callback (default: nil)
        public init(maxNumberOfQueueingTasks: Int = 50,
                    maxNumberOfRunningTasks: Int = 4,
                    priorityStrategy: PriorityStrategy = .LIFO(.await),
                    cacheConfig: MemoryCache<K, Element>.Configuration = .defaultConfig,
                    cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil) {
            self.maxNumberOfQueueingTasks = maxNumberOfQueueingTasks
            self.maxNumberOfRunningTasks = maxNumberOfRunningTasks
            self.priorityStrategy = priorityStrategy
            self.cacheConfig = cacheConfig
            self.cacheStatisticsReport = cacheStatisticsReport
        }
    }
}

/// Comprehensive manager for resource-intensive computational tasks and operations.
///
/// KVHeavyTasksManager serves as the central coordination hub for executing, caching, and managing
/// heavy computational tasks. It provides sophisticated concurrency control, intelligent caching,
/// flexible priority strategies, and comprehensive lifecycle management for resource-intensive operations.
///
/// ## Architecture Overview
/// The manager operates through several interconnected systems:
/// - **Task Queue Management**: Dual-queue system (waiting/running) with configurable capacity and eviction
/// - **Priority Coordination**: FIFO/LIFO strategies with optional task interruption support
/// - **Cache Integration**: Multi-level caching with hit/miss/null/invalid state handling
/// - **Provider Lifecycle**: DataProvider creation, reuse, and cleanup with memory optimization
/// - **Event Broadcasting**: Real-time progress updates and custom event distribution
/// - **Thread Safety**: Complete concurrency protection using semaphore-based synchronization
///
/// ## Key Features
/// - **Zero-configuration operation**: Sensible defaults for immediate use
/// - **Highly configurable**: Every aspect of behavior can be customized
/// - **Memory efficient**: Automatic cleanup and configurable resource limits
/// - **Performance optimized**: Minimal overhead with intelligent caching and provider reuse
/// - **Robust error handling**: Comprehensive error propagation and graceful degradation
/// - **Production ready**: Thread-safe, tested, and optimized for high-load scenarios
///
/// ## Generic Type Parameters
/// - `K`: Key type for task identification (must be Hashable) - used for deduplication and caching
/// - `Element`: Result type returned by completed tasks - cached and delivered to callbacks
/// - `CustomEvent`: Event type for progress updates - broadcast to all registered observers
/// - `DataProvider`: Concrete provider class that executes the actual heavy operations
///
/// ## Usage Example
/// ```swift
/// // Define your custom data provider
/// class ImageProcessingProvider: KVHeavyTaskBaseDataProvider<String, UIImage, ProcessingProgress>,
///                               KVHeavyTaskDataProviderInterface {
///     func start() {
///         // Implement heavy image processing
///         performImageProcessing { progress in
///             customEventPublisher(progress)
///         } completion: { result in
///             resultPublisher(result)
///         }
///     }
///     
///     func stop() -> KVHeavyTaskDataProviderStopAction {
///         return .reuse // Preserve processing state for resumption
///     }
/// }
///
/// // Configure and create manager
/// let config = KVHeavyTasksManager<String, UIImage, ProcessingProgress, ImageProcessingProvider>.Config(
///     maxNumberOfRunningTasks: 2,
///     priorityStrategy: .LIFO(.stop),
///     cacheConfig: .init(memoryUsageLimitation: .init(capacity: 100, memory: 50_000_000))
/// )
/// let manager = KVHeavyTasksManager<String, UIImage, ProcessingProgress, ImageProcessingProvider>(config: config)
///
/// // Execute tasks with progress monitoring
/// manager.fetch(key: "process_photo_123", 
///               customEventObserver: { progress in
///                   print("Processing progress: \(progress.percentage)%")
///               },
///               result: { result in
///                   switch result {
///                   case .success(let image):
///                       // Handle processed image
///                   case .failure(let error):
///                       // Handle processing error
///                   }
///               })
/// ```
///
/// ## Thread Safety
/// All public methods are fully thread-safe and can be called from any queue or thread.
/// The manager uses internal synchronization to coordinate access to shared state while
/// minimizing performance impact through careful lock scope management.
///
/// ## Performance Considerations
/// - **Queue sizing**: Balance memory usage vs task eviction risk
/// - **Concurrency limits**: Optimize for your specific task characteristics and system resources  
/// - **Cache configuration**: Tune for your result size and access patterns
/// - **Priority strategy**: Choose based on responsiveness vs predictability requirements
/// - **Provider lifecycle**: Balance setup cost vs memory usage with reuse/dealloc decisions
public class KVHeavyTasksManager<K, Element, CustomEvent, DataProvider: KVHeavyTaskBaseDataProvider<K, Element, CustomEvent>> where DataProvider: KVHeavyTaskDataProviderInterface {
    /// Initializes a new KVHeavyTasksManager with the specified configuration.
    ///
    /// This initializer sets up all internal systems including queues, cache, and synchronization
    /// primitives. The configuration is immutable after initialization to ensure consistent behavior.
    ///
    /// - Parameter config: Complete configuration defining all manager behavior
    /// - Note: Initialization is lightweight and safe to call from any thread
    public init(config: Config) {
        self.config = config
        self.cache = MemoryCache<K, Element>(configuration: config.cacheConfig, statisticsReport: config.cacheStatisticsReport)
        self.waitingQueue = .init(capacity: config.maxNumberOfQueueingTasks)
        self.runningKeys = .init(capacity: config.maxNumberOfRunningTasks)
    }
    
    /// Immutable configuration that defines all manager behavior.
    ///
    /// This configuration is set at initialization and cannot be changed during the manager's
    /// lifetime, ensuring consistent and predictable behavior for all operations.
    public let config: Config
    
    /// High-performance memory cache for storing completed task results.
    ///
    /// The cache provides immediate results for previously computed tasks and supports:
    /// - Multi-state responses (hit/miss/null/invalid)
    /// - Memory and capacity limits with intelligent eviction
    /// - TTL-based expiration for time-sensitive results
    /// - Key validation to filter malformed requests
    /// - Detailed statistics reporting for performance monitoring
    private let cache: MemoryCache<K, Element>
    
    /// Queue for tasks waiting to be executed when resources become available.
    ///
    /// This queue manages overflow from the running queue and provides:
    /// - Configurable capacity with eviction when full
    /// - Priority-based insertion and removal (FIFO/LIFO)
    /// - Efficient key-based lookup and removal operations
    /// - Automatic integration with running queue management
    private let waitingQueue: HashQueue<K>
    
    /// Queue for tasks currently being executed by DataProviders.
    ///
    /// This queue tracks active tasks and enforces concurrency limits:
    /// - Fixed capacity based on maxNumberOfRunningTasks configuration
    /// - Automatic promotion of waiting tasks when slots become available
    /// - Support for task interruption and queue reordering in LIFO(.stop) mode
    /// - Integrated with DataProvider lifecycle management
    private let runningKeys: HashQueue<K>
    
    /// Registry of custom event observers for active tasks.
    ///
    /// Maps task keys to arrays of observer callbacks that receive real-time progress updates.
    /// Multiple observers can be registered for the same task, and all are notified of events.
    /// Automatically cleaned up when tasks complete or are evicted.
    private var customEventObservers: [K: [DataProvider.CustomEventPublisher]] = .init()
    
    /// Registry of result callbacks for active tasks.
    ///
    /// Maps task keys to arrays of result callbacks that receive final task outcomes.
    /// Multiple callbacks can be registered for the same task, enabling fan-out notification.
    /// Automatically cleaned up after result delivery to prevent memory leaks.
    private var resultCallbacks: [K: [DataProvider.ResultPublisher]] = .init()
    
    /// Active DataProvider instances indexed by task key.
    ///
    /// This dictionary manages the lifecycle of DataProvider instances:
    /// - Created on-demand when tasks start execution
    /// - Reused across multiple executions when stop() returns .reuse
    /// - Removed when tasks complete or when stop() returns .dealloc
    /// - Provides provider persistence for efficient task resumption
    private var dataProviders: [K: DataProvider] = .init()
    
    /// Semaphore providing thread-safe access to all manager state.
    ///
    /// This binary semaphore coordinates access to all shared mutable state including:
    /// - Task queues (waiting and running)
    /// - Observer and callback registries
    /// - DataProvider lifecycle management
    /// - Cache interactions and state transitions
    ///
    /// The semaphore is used with minimal scope to ensure high concurrency while maintaining
    /// data integrity and preventing race conditions.
    private var semaphore: DispatchSemaphore = .init(value: 1)
}

// Enable thread-safe concurrency through internal synchronization mechanisms.
// The manager employs DispatchSemaphore to ensure thread-safe access to shared mutable state.
extension KVHeavyTasksManager: @unchecked Sendable {}

public extension KVHeavyTasksManager {
    enum Errors: Error {
        case invalidConcurrencyConfiguration
        case taskEvictedDueToPriorityConstraints(K)
    }
    
    func fetch(key: K,
               customEventObserver: DataProvider.CustomEventPublisher? = nil,
               result resultCallback: DataProvider.ResultPublisher? = nil) {
        guard self.config.maxNumberOfRunningTasks > 0 else {
            resultCallback?(.failure(Errors.invalidConcurrencyConfiguration))
            return
        }
        self.start(key, customEventObserver: customEventObserver, resultCallback: resultCallback)
    }
    
    func asyncFetch(key: K,
                   customEventObserver: DataProvider.CustomEventPublisher? = nil) async -> Result<Element?, Error> {
        guard self.config.maxNumberOfRunningTasks > 0 else {
            return .failure(Errors.invalidConcurrencyConfiguration)
        }
        
        return await withCheckedContinuation { continuation in
            self.start(key, customEventObserver: customEventObserver) { result in
                continuation.resume(returning: result)
            }
        }
    }
}

/// Private implementation details for internal task coordination and execution.
///
/// These methods handle the core logic for task lifecycle management, cache coordination,
/// priority strategy execution, and DataProvider lifecycle. They are designed for internal
/// use only and assume proper synchronization context (semaphore protection).
private extension KVHeavyTasksManager {
    /// Internal entry point for task execution that handles cache checking and callback registration.
    ///
    /// This method serves as the coordination center for all task requests, handling:
    /// - **Cache consultation**: Check for existing results to avoid duplicate work
    /// - **Callback registration**: Register observers and result handlers for the task
    /// - **Priority routing**: Delegate to appropriate priority strategy implementation
    ///
    /// ## Cache State Handling
    /// The method handles all possible cache states:
    /// - **hitNonNullElement**: Returns cached result immediately without task execution
    /// - **hitNullElement**: Returns nil immediately (valid null result from previous execution)
    /// - **invalidKey**: Returns nil immediately (key rejected by cache validator)
    /// - **miss**: Proceeds with task execution through priority strategy
    ///
    /// ## Callback Management
    /// Multiple callbacks can be registered for the same task key, enabling:
    /// - **Fan-out notification**: Single task execution serves multiple requesters
    /// - **Progress broadcasting**: All observers receive the same progress updates
    /// - **Result distribution**: Final result is delivered to all registered callbacks
    ///
    /// ## Synchronization Context
    /// This method must be called within semaphore protection to ensure:
    /// - Thread-safe access to observer and callback registries
    /// - Consistent cache state during evaluation
    /// - Atomic callback registration and priority strategy execution
    ///
    /// - Parameters:
    ///   - key: Unique task identifier for execution, caching, and callback coordination
    ///   - customEventObserver: Optional observer for real-time progress and status updates
    ///   - resultCallback: Optional callback for final task result delivery
    ///
    /// - Note: All callbacks are executed asynchronously on global queues to prevent deadlock
    /// - Warning: Must be called within semaphore.wait()/signal() protection
    private func start(_ key: K, customEventObserver: DataProvider.CustomEventPublisher?, resultCallback: DataProvider.ResultPublisher?) {
        semaphore.wait()
        defer { semaphore.signal() }
        
        // First, consult the cache to avoid duplicate work
        switch cache.getElement(for: key) {
        case .hitNonNullElement(let element):
            // Cache hit with valid result - return immediately without task execution
            DispatchQueue.global().async {
                resultCallback?(.success(element))
            }
            return

        case .hitNullElement:
            // Cache hit with null result - return nil immediately (previously computed null result)
            fallthrough
        case .invalidKey:
            // Key rejected by cache validation - return nil immediately (invalid request)
            DispatchQueue.global().async {
                resultCallback?(.success(nil))
            }
            return
            
        case .miss:
            // Cache miss - proceed with task execution
            break
        }
        
        // Register custom event observer for progress updates
        if let customEventObserver {
            if !customEventObservers.keys.contains(key) {
                customEventObservers[key] = .init()
            }
            customEventObservers[key]?.append(customEventObserver)
        }
        
        // Register result callback for final outcome delivery
        if !resultCallbacks.keys.contains(key) {
            resultCallbacks[key] = .init()
        }
        if let resultCallback {
            resultCallbacks[key]?.append(resultCallback)
        }
        
        // Route to appropriate priority strategy implementation
        switch config.priorityStrategy {
        case .FIFO:
            executeFIFO(key)
        case .LIFO(.await):
            executeLIFOAwait(key)
        case .LIFO(.stop):
            executeLIFOStop(key)
        }
    }
    
    /// Implements First In, First Out priority strategy for task execution.
    ///
    /// FIFO strategy provides fair resource allocation by executing tasks in submission order.
    /// This strategy never interrupts running tasks and provides predictable execution patterns.
    ///
    /// ## Execution Logic
    /// 1. **Duplicate check**: Skip if task is already running
    /// 2. **Queue cleanup**: Remove from waiting queue if present (re-submission case)
    /// 3. **Direct execution**: Start immediately if running capacity available
    /// 4. **Queue for later**: Add to waiting queue if all slots occupied
    /// 5. **Eviction handling**: Notify evicted tasks when waiting queue is full
    ///
    /// ## Queue Management
    /// - **Running queue**: Uses LIFO eviction (though eviction never occurs in FIFO)
    /// - **Waiting queue**: Uses LIFO eviction to remove oldest waiting tasks when full
    /// - **Task promotion**: Waiting tasks are promoted to running when slots become available
    ///
    /// ## Characteristics
    /// - ✅ Fair resource allocation across all submitted tasks
    /// - ✅ Predictable execution order regardless of timing
    /// - ✅ No task interruption complexity
    /// - ❌ Lower responsiveness for recent high-priority requests
    ///
    /// - Parameter key: Task identifier to execute using FIFO strategy
    private func executeFIFO(_ key: K) {
        // Skip if this task is already running (avoid duplicates)
        if runningKeys.contains(key: key) {
            return
        }
        
        // Remove from waiting queue if present (handles re-submission)
        if waitingQueue.contains(key: key) {
            waitingQueue.remove(key: key)
        }
        
        // Start immediately if we have available running capacity
        if runningKeys.count < self.config.maxNumberOfRunningTasks {
            runningKeys.enqueueFront(key: key, evictedStrategy: .LIFO)
            startTask(for: key)
            return
        }
        
        // Queue for later execution and handle waiting queue overflow
        if let evictedKey = self.waitingQueue.enqueueFront(key: key, evictedStrategy: .LIFO) {
            consumeCallbacks(for: evictedKey, result: .failure(Errors.taskEvictedDueToPriorityConstraints(evictedKey)))
        }
    }
    
    /// Implements Last In, First Out priority strategy with await behavior for running tasks.
    ///
    /// LIFO(.await) strategy prioritizes recent tasks while allowing running tasks to complete
    /// naturally. This provides better responsiveness than FIFO while avoiding the complexity
    /// of task interruption.
    ///
    /// ## Execution Logic
    /// 1. **Duplicate check**: Skip if task is already running
    /// 2. **Queue cleanup**: Remove from waiting queue if present (re-submission case)
    /// 3. **Direct execution**: Start immediately if running capacity available  
    /// 4. **Queue for later**: Add to front of waiting queue (LIFO behavior)
    /// 5. **Eviction handling**: Remove oldest waiting tasks when queue is full
    ///
    /// ## Queue Management
    /// - **Running queue**: Uses FIFO eviction to maintain execution order stability
    /// - **Waiting queue**: Uses FIFO eviction to remove oldest waiting tasks when full
    /// - **Task promotion**: Most recent waiting tasks are promoted first when slots open
    ///
    /// ## Characteristics  
    /// - ✅ Recent tasks get priority over older submissions
    /// - ✅ No task interruption complexity or overhead
    /// - ✅ Better responsiveness than pure FIFO
    /// - ❌ Running tasks may delay high-priority requests
    /// - ❌ Potential starvation of older waiting tasks under high load
    ///
    /// - Parameter key: Task identifier to execute using LIFO(.await) strategy
    private func executeLIFOAwait(_ key: K) {
        // Skip if this task is already running (avoid duplicates)
        if runningKeys.contains(key: key) {
            return
        }
        
        // Remove from waiting queue if present (handles re-submission)
        if waitingQueue.contains(key: key) {
            waitingQueue.remove(key: key)
        }
        
        // Start immediately if we have available running capacity
        if runningKeys.count < self.config.maxNumberOfRunningTasks {
            runningKeys.enqueueFront(key: key, evictedStrategy: .FIFO)
            startTask(for: key)
            return
        }
        
        // Add to front of waiting queue (LIFO) and handle overflow
        if let evictedKey = self.waitingQueue.enqueueFront(key: key, evictedStrategy: .FIFO) {
            consumeCallbacks(for: evictedKey, result: .failure(Errors.taskEvictedDueToPriorityConstraints(evictedKey)))
        }
    }
    
    /// Implements Last In, First Out priority strategy with stop behavior for running tasks.
    ///
    /// LIFO(.stop) strategy provides maximum responsiveness by immediately stopping running tasks
    /// to make room for new high-priority requests. This is the most aggressive priority strategy
    /// and provides the best responsiveness at the cost of increased complexity.
    ///
    /// ## Execution Logic
    /// 1. **Duplicate check**: Skip if task is already running
    /// 2. **Queue cleanup**: Remove from waiting queue if present (re-submission case)
    /// 3. **Force execution**: Always start immediately, stopping other tasks if needed
    /// 4. **Task interruption**: Stop lowest-priority running task to make room
    /// 5. **Provider lifecycle**: Handle stopped provider based on its stop() return value
    /// 6. **Queue migration**: Move stopped task to waiting queue for later resumption
    ///
    /// ## Task Interruption Process
    /// When all running slots are occupied:
    /// - New task is added to running queue, evicting the oldest running task
    /// - Evicted task's DataProvider.stop() method is called
    /// - Provider is either kept (.reuse) or deallocated (.dealloc) based on stop() result
    /// - Stopped task is moved to waiting queue and will automatically resume when resources are available
    ///
    /// ## Provider State Management
    /// - **Reuse strategy**: Provider instance stays in memory, can resume from current state
    /// - **Dealloc strategy**: Provider is deallocated immediately, will be recreated on resume
    /// - **Automatic resumption**: Stopped tasks restart automatically when running slots become available
    ///
    /// ## Characteristics
    /// - ✅ Maximum responsiveness for high-priority tasks
    /// - ✅ Immediate execution regardless of current load
    /// - ✅ Intelligent provider lifecycle management
    /// - ❌ Higher complexity from task interruption and resumption
    /// - ❌ Potential efficiency loss if providers choose .dealloc frequently
    /// - ❌ More complex debugging due to task state transitions
    ///
    /// - Parameter key: Task identifier to execute using LIFO(.stop) strategy
    private func executeLIFOStop(_ key: K) {
        // Skip if this task is already running (avoid duplicates)
        if runningKeys.contains(key: key) {
            return
        }
        
        // Remove from waiting queue if present (handles re-submission)
        if waitingQueue.contains(key: key) {
            waitingQueue.remove(key: key)
        }
        
        // Force this task into the running queue, potentially evicting another task
        if let keyToStop = runningKeys.enqueueFront(key: key, evictedStrategy: .FIFO) {
            // Move the stopped task to waiting queue for automatic resumption later
            if let evictedKey = self.waitingQueue.enqueueFront(key: keyToStop, evictedStrategy: .FIFO) {
                // Notify evicted waiting task if waiting queue is full
                consumeCallbacks(for: evictedKey, result: .failure(Errors.taskEvictedDueToPriorityConstraints(evictedKey)))
            }
            
            // Stop the evicted DataProvider and handle its lifecycle based on return value
            if let dataProvider = dataProviders[keyToStop] {
                switch dataProvider.stop() {
                case .reuse:
                    // Keep provider in memory for efficient resumption
                    break
                case .dealloc:
                    // Deallocate provider immediately to free memory
                    dataProviders.removeValue(forKey: keyToStop)
                }
            }
        }
        
        // Start the new high-priority task immediately
        startTask(for: key)
    }
    
    /// Creates or reuses a DataProvider for the specified task and initiates execution.
    ///
    /// This method is the core of DataProvider lifecycle management and task execution coordination.
    /// It handles provider creation/reuse, event routing, result processing, cache integration,
    /// and automatic queue progression.
    ///
    /// ## DataProvider Lifecycle
    /// - **Creation**: New provider instances are created on-demand when not present
    /// - **Reuse**: Existing providers are reused when stop() returned .reuse
    /// - **Event handling**: Custom events are broadcast to all registered observers
    /// - **Result processing**: Final results are cached and delivered to all callbacks
    /// - **Cleanup**: Providers are cleaned up based on completion or interruption strategy
    ///
    /// ## Automatic Queue Progression
    /// When a task completes, the system automatically:
    /// 1. Removes the task from running queue
    /// 2. Promotes the next waiting task based on priority strategy
    /// 3. Starts the newly promoted task without external intervention
    /// 4. Maintains optimal resource utilization
    ///
    /// ## Event and Result Flow
    /// The publisher callbacks provide thread-safe coordination between:
    /// - **Custom Events**: Real-time progress updates broadcast to all observers
    /// - **Results**: Final outcomes cached and delivered to all result callbacks
    /// - **Error Handling**: Failures propagated to callbacks without caching
    /// - **Memory Management**: Automatic cleanup prevents observer/callback leaks
    ///
    /// ## Thread Safety
    /// All operations within this method are protected by semaphore synchronization:
    /// - Provider creation and lookup
    /// - Event and result callback registration management
    /// - Queue operations and task progression
    /// - Cache interactions and statistics reporting
    ///
    /// - Parameter key: Task identifier for provider lookup, creation, and execution
    /// - Note: This method assumes semaphore protection from calling context
    /// - Warning: The DataProvider's start() method is called at the end without additional synchronization
    private func startTask(for key: K) {
        // Create new DataProvider instance if not already present (supports reuse from .reuse strategy)
        if self.dataProviders[key] == nil {
            self.dataProviders[key] = DataProvider(key: key, customEventPublisher: { [weak self] customEvent in
                // Handle custom events (progress updates, status changes, etc.)
                DispatchQueue.global().async { [weak self] in
                    guard let taskManager = self else { return }
                    taskManager.semaphore.wait()
                    defer { taskManager.semaphore.signal() }
                    
                    // Broadcast event to all registered observers for this key
                    taskManager.customEventObservers[key]?.forEach { observer in
                        DispatchQueue.global().async {
                            observer(customEvent)
                        }
                    }
                }
            }, resultPublisher: { [weak self] result in
                // Handle final task result (success or failure)
                DispatchQueue.global().async { [weak self] in
                    guard let taskManager = self else { return }
                    taskManager.semaphore.wait()
                    defer { taskManager.semaphore.signal() }
                    
                    switch result {
                    case .success(let element):
                        // Cache successful results for future requests
                        taskManager.cache.set(element: element, for: key)
                        taskManager.consumeCallbacks(for: key, result: .success(element))
                    case .failure(let error):
                        // Don't cache failures; directly notify callbacks
                        taskManager.consumeCallbacks(for: key, result: .failure(error))
                    }
                    
                    // Clean up completed task and free resources
                    taskManager.dataProviders.removeValue(forKey: key)
                    taskManager.runningKeys.remove(key: key)
                    
                    // Promote next waiting task to maintain optimal throughput
                    let nextKey: K?
                    switch taskManager.config.priorityStrategy {
                    case .FIFO:
                        nextKey = taskManager.waitingQueue.dequeueBack()
                    case .LIFO:
                        nextKey = taskManager.waitingQueue.dequeueFront()
                    }
                    
                    guard let nextKey else { return }
                    
                    // Add promoted task to running queue with appropriate eviction strategy
                    switch taskManager.config.priorityStrategy {
                    case .FIFO:
                        taskManager.runningKeys.enqueueFront(key: nextKey, evictedStrategy: .LIFO)
                    case .LIFO:
                        taskManager.runningKeys.enqueueFront(key: nextKey, evictedStrategy: .FIFO)
                    }
                    
                    // Start the newly promoted task
                    taskManager.startTask(for: nextKey)
                }
            })
        }

        // Initiate task execution (provider is responsible for calling resultPublisher exactly once)
        dataProviders[key]!.start()
    }
    
    /// Delivers final task results to all registered callbacks and performs cleanup.
    ///
    /// This method is the final step in the task lifecycle, responsible for:
    /// - **Result delivery**: Distributing the final result to all registered callbacks
    /// - **Memory cleanup**: Removing callback and observer registrations to prevent leaks
    /// - **Fan-out notification**: Supporting multiple callbacks for the same task
    ///
    /// ## Callback Coordination
    /// Multiple callbacks can be registered for the same task when:
    /// - Different components request the same resource simultaneously
    /// - A task is requested multiple times before completion
    /// - Both event observers and result handlers are registered
    ///
    /// All registered callbacks receive the same result, enabling efficient resource sharing
    /// without duplicate task execution.
    ///
    /// ## Memory Management
    /// This method performs essential cleanup to prevent memory leaks:
    /// - **Result callbacks**: Cleared after delivery to prevent strong reference cycles
    /// - **Event observers**: Cleared after task completion to free observer registrations
    /// - **Automatic cleanup**: Occurs for both successful and failed task completion
    ///
    /// ## Error Handling
    /// Both successful and failed task results are delivered using the same mechanism:
    /// - **Success results**: Contain the computed value or nil for valid empty results
    /// - **Error results**: Contain detailed error information for debugging and recovery
    /// - **Consistent delivery**: All callbacks receive the same result regardless of outcome
    ///
    /// ## Threading
    /// All callback invocations are dispatched asynchronously to prevent:
    /// - **Deadlock**: Callbacks may perform additional synchronous operations
    /// - **Performance impact**: Long-running callbacks don't block the task manager
    /// - **Ordering issues**: Callbacks execute independently without imposed order
    ///
    /// - Parameters:
    ///   - key: Task identifier for callback lookup and cleanup
    ///   - result: Final task outcome to deliver to all registered callbacks
    ///
    /// - Note: This method assumes semaphore protection from calling context
    /// - Warning: After this method completes, no further callbacks can be registered for this key
    private func consumeCallbacks(for key: K, result: Result<Element?, Error>) {
        // Deliver result to all registered callbacks asynchronously
        resultCallbacks[key]?.forEach{ callback in
            DispatchQueue.global().async {
                callback(result)
            }
        }
        
        // Clean up callback and observer registrations to prevent memory leaks
        resultCallbacks.removeValue(forKey: key)
        customEventObservers.removeValue(forKey: key)
    }
}
