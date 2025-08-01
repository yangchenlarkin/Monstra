//
//  KVHeavyTasksManager.swift
//  Monstra
//
//  Created by Larkin on 2025/7/27.
//
//  KVHeavyTasksManager is designed to manage heavy computational tasks such as:
//  - Large file downloads (videos, 3D models, datasets)
//  - Complex image processing and generation
//  - Video encoding/decoding operations
//  - Machine learning model inference
//  - Any long-running, resource-intensive operations
//
//  This manager provides:
//  - Priority-based task scheduling (LIFO/FIFO)
//  - Concurrent task execution with configurable limits
//  - Progress tracking and cancellation support
//  - Caching of completed task results
//  - Retry mechanisms for failed operations
//  - Task lifecycle management (pause/resume/cancel)
//

import Foundation
import MonstraBase
import Monstore

/// Protocol defining the interface for heavy task data providers.
/// 
/// Heavy task data providers are responsible for executing individual resource-intensive operations
/// such as file downloads, image processing, video encoding, or any long-running computational tasks.
/// They provide custom event publishing, result delivery, and lifecycle management capabilities.
/// 
/// ## Key Features
/// - **Custom Event Publishing**: Real-time progress and status updates
/// - **Async/Await Support**: Modern Swift concurrency for better performance
/// - **Lifecycle Management**: Start, stop, and resume operations
/// - **Type Safety**: Generic types for keys and results
/// 
/// ## Associated Types
/// - `K`: The key type used to identify tasks (must be Hashable)
/// - `Element`: The result type returned by completed tasks
/// - `CustomEvent`: The event type for progress and status updates
public protocol KVHeavyTaskDataProvider {
    associatedtype K: Hashable
    associatedtype Element
    associatedtype CustomEvent
    
    /// Callback type for publishing custom events during task execution
    /// 
    /// This closure is called to publish progress updates, status changes,
    /// or any other custom events during task execution.
    typealias CustomEventPublisher = @Sendable (CustomEvent) -> Void
    
    /// The unique identifier for this task
    var key: K { get }
    
    /// Optional callback for publishing custom events during task execution
    var customEventPublisher: CustomEventPublisher { get }
    
    /// Initializes a new heavy task data provider
    /// 
    /// - Parameters:
    ///   - key: The unique identifier for this task
    ///   - customEventPublisher: Optional callback for publishing custom events
    init(key: K, customEventPublisher: @escaping CustomEventPublisher)
    
    /// Executes the heavy task asynchronously
    /// 
    /// This method should implement the main task logic. It can publish progress
    /// updates through the `customEventPublisher` and should handle cancellation
    /// gracefully by checking for task interruption.
    /// 
    /// - Returns: The result of the task execution, or nil if the task was cancelled
    /// - Throws: Any error that occurred during task execution
    func start() async throws -> Element?
    
    /// Stops the currently executing task
    /// 
    /// This method should gracefully stop the task execution and optionally
    /// return a resume function that can be called to restart the task from
    /// where it left off.
    /// 
    /// - Returns: An optional async closure that can resume the task, or nil if
    ///            the task cannot be resumed or is already stopped
    func stop() async -> (() async -> Void)?
}

/// Configuration and data provider types for KVHeavyTasksManager
public extension KVHeavyTasksManager {
    struct Config {
        /// Defines how the last inserted task should handle currently running tasks when using LIFO priority.
        /// 
        /// - `await`: The last inserted task will wait for the completion of all current running tasks
        /// - `cancel`: The last inserted task will cancel all current running tasks and take priority
        /// - `pause`: The last inserted task will pause all current running tasks and resume them later
        public enum LIFOStrategy {
            case await
            case stop
        }
        
        /// Defines the priority strategy for task execution order.
        /// 
        /// - `LIFO(strategy)`: Last In, First Out - the most recently added task gets priority
        ///   - `strategy`: Determines how to handle currently running tasks when a new task is inserted
        /// - `FIFO`: First In, First Out - tasks are executed in the order they were added
        public enum KeyPriority {
            case LIFO(LIFOStrategy)
            case FIFO
        }
        
        /// Maximum number of tasks that can be queued in memory
        public let maximumTaskNumberInQueue: Int
        
        /// Maximum number of concurrent threads for task execution
        public let maximumConcurrentRunningThreadNumber: Int
        
        /// Retry configuration for failed heavy task operations
        public let retryCount: RetryCount
        
        /// Priority strategy for task execution order
        public let keyPriority: KeyPriority
        
        /// Cache configuration for heavy task results
        public let cacheConfig: MemoryCache<K, Element>.Configuration
        
        /// Optional callback for cache statistics reporting
        public let cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)?
        
        /// Initializes a new KVHeavyTasksManager configuration.
        /// 
        /// - Parameters:
        ///   - maximumTaskNumberInQueue: Maximum number of tasks in the queue (default: 50)
        ///   - maximumConcurrentRunningThreadNumber: Maximum concurrent threads (default: 4)
        ///   - retryCount: Retry configuration for failed requests (default: 0)
        ///   - keyPriority: Priority strategy for task execution (default: .LIFO(.await))
        ///   - cacheConfig: Cache configuration for heavy task results (default: .defaultConfig)
        ///   - cacheStatisticsReport: Optional callback for cache statistics
        public init(maximumTaskNumberInQueue: Int = 50,
             maximumConcurrentRunningThreadNumber: Int = 4,
             retryCount: RetryCount = 0,
             keyPriority: KeyPriority = .LIFO(.await),
             cacheConfig: MemoryCache<K, Element>.Configuration = .defaultConfig,
             cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil) {
            self.maximumTaskNumberInQueue = maximumTaskNumberInQueue
            self.maximumConcurrentRunningThreadNumber = maximumConcurrentRunningThreadNumber
            self.retryCount = retryCount
            self.keyPriority = keyPriority
            self.cacheConfig = cacheConfig
            self.cacheStatisticsReport = cacheStatisticsReport
        }
    }
}

/// The manager automatically uses the same key and element types as the task handler:
/// - `K`: Same as TaskHandler.K (the key type for identifying tasks)
/// - `Element`: Same as TaskHandler.Element (the result type from completed tasks)
public extension KVHeavyTasksManager {
    /// Type alias ensuring K is the same as TaskHandler's associated type
    typealias K = TaskHandler.K
    /// Type alias ensuring Element is the same as TaskHandler's associated type
    typealias Element = TaskHandler.Element
}

/// Manager for heavy computational tasks that require significant resources and time.
/// 
/// KVHeavyTasksManager coordinates the execution of heavy tasks through task handlers.
/// It provides priority-based scheduling, concurrent execution limits, caching, and
/// comprehensive lifecycle management for resource-intensive operations.
/// 
/// - `TaskHandler`: The type of task handler that conforms to KVHeavyTaskHandler protocol
public class KVHeavyTasksManager<TaskHandler: KVHeavyTaskDataProvider> {
    public init(config: Config) {
        self.config = config
        self.cache = .init(configuration: config.cacheConfig, statisticsReport: config.cacheStatisticsReport)
        self.keyQueue = .init(capacity: config.maximumTaskNumberInQueue)
        self.pausedTaskHandles = .init(capacity: config.maximumTaskNumberInQueue)
        self.runningTaskHandlers = .init(capacity: config.maximumTaskNumberInQueue)
    }
    
    private let config: Config
    private let cache: Monstore.MemoryCache<K, Element>
    private let keyQueue: KeyQueue<TaskHandlerWrapper>
    private let pausedTaskHandles: KeyQueue<TaskHandlerWrapper>
    private let runningTaskHandlers: KeyQueue<TaskHandlerWrapper>
}

private extension KVHeavyTasksManager {
    private func start(_ key: K) {
        let wrapper = TaskHandlerWrapper(key: key)
        if !keyQueue.contains(key: wrapper) && !pausedTaskHandles.contains(key: wrapper) && !runningTaskHandlers.contains(key: wrapper) {
            if keyQueue.count + pausedTaskHandles.count + runningTaskHandlers.count < config.maximumTaskNumberInQueue {
//                keyQueue.enqueueFront(key: wrapper)
            } else {
                switch config.keyPriority {
                case .LIFO(.await):
                    return
                case .LIFO(.stop):
                    return
                case .FIFO:
                    return
                }
            }
        }
    }
}

private extension KVHeavyTasksManager {
    struct TaskHandlerWrapper: Hashable {
        let key: K
        var taskHandler: TaskHandler?
        
        static func == (lhs: KVHeavyTasksManager<TaskHandler>.TaskHandlerWrapper, rhs: KVHeavyTasksManager<TaskHandler>.TaskHandlerWrapper) -> Bool {
            lhs.key == rhs.key
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }
}
