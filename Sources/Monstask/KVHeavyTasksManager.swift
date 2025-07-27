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

/// Protocol defining the interface for heavy task handlers.
/// 
/// Heavy task handlers are responsible for executing individual heavy computational tasks.
/// They provide progress tracking, result delivery, and lifecycle management capabilities.
/// 
/// - `K`: The key type used to identify tasks (must be Hashable)
/// - `Element`: The result type returned by completed tasks
public protocol KVHeavyTaskHandler: AnyObject {
    associatedtype K: Hashable
    associatedtype Element
    
    /// Callback type for progress updates during task execution
    typealias ProgressCallback = ()->Void
    /// Callback type for task completion results
    typealias ResultCallback = (Result<Element?, Error>)->Void
    
    /// Callback invoked during task execution to report progress
    var progressCallback: ProgressCallback { get }
    /// Callback invoked when task completes (successfully or with error)
    var resultCallback: ResultCallback { get }
    
    /// Initializes a new heavy task handler with progress and result callbacks
    /// 
    /// - Parameters:
    ///   - progressCallback: Optional callback for progress updates
    ///   - resultCallback: Required callback for task completion results
    init(progressCallback: ProgressCallback?, resultCallback: @escaping ProgressCallback)
    
    /// Starts execution of the heavy task identified by the given key
    /// - Parameter key: The unique identifier for the task to execute
    func start(key: K)
    
    /// Pauses the currently executing task (if any)
    func pause()
    
    /// Resumes a previously paused task
    func resume()
    
    /// Cancels the currently executing task
    func cancel()
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
            case cancel
            case pause
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
        init(maximumTaskNumberInQueue: Int = 50,
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

/// Manager for heavy computational tasks that require significant resources and time.
/// 
/// KVHeavyTasksManager coordinates the execution of heavy tasks through task handlers.
/// It provides priority-based scheduling, concurrent execution limits, caching, and
/// comprehensive lifecycle management for resource-intensive operations.
/// 
/// - `TaskHandler`: The type of task handler that conforms to KVHeavyTaskHandler protocol
/// 
/// The manager automatically uses the same key and element types as the task handler:
/// - `K`: Same as TaskHandler.K (the key type for identifying tasks)
/// - `Element`: Same as TaskHandler.Element (the result type from completed tasks)
public class KVHeavyTasksManager<TaskHandler: KVHeavyTaskHandler> {
    /// Type alias ensuring K is the same as TaskHandler's associated type
    public typealias K = TaskHandler.K
    /// Type alias ensuring Element is the same as TaskHandler's associated type
    public typealias Element = TaskHandler.Element
    
    // TODO: Implement task queue management
    // TODO: Implement priority-based scheduling
    // TODO: Implement concurrent execution control
    // TODO: Implement caching integration
    // TODO: Implement retry mechanisms
    // TODO: Implement progress tracking
}
