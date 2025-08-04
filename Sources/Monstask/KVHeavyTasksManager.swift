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
public protocol KVHeavyTaskDataProvider: AnyObject {
    associatedtype K: Hashable
    associatedtype Element
    associatedtype CustomEvent
    
    /// Callback type for publishing custom events during task execution
    /// 
    /// This closure is called to publish progress updates, status changes,
    /// or any other custom events during task execution.
    typealias CustomEventPublisher = @Sendable (CustomEvent) -> Void
    typealias ResultPublisher = @Sendable (Result<Element?, Error>)->Void
    
    /// The unique identifier for this task
    var key: K { get }
    
    /// Optional callback for publishing custom events during task execution
    var customEventPublisher: CustomEventPublisher { get }
    
    /// should be called just once after start
    var resultPublisher: ResultPublisher { get }
    
    /// Initializes a new heavy task data provider
    /// 
    /// - Parameters:
    ///   - key: The unique identifier for this task
    ///   - customEventPublisher: Optional callback for publishing custom events
    init(key: K, customEventPublisher: @escaping CustomEventPublisher, resultPublisher: @escaping ResultPublisher)
    
    /// Executes the heavy task asynchronously
    /// 
    /// This method should implement the main task logic. It can publish progress
    /// updates through the `customEventPublisher` and should handle cancellation
    /// gracefully by checking for task interruption.
    /// 
    /// - Returns: The result of the task execution, or nil if the task was cancelled
    /// - Throws: Any error that occurred during task execution
    func start() async 
    
    /// Stops the currently executing task
    /// 
    /// This method should gracefully stop the task execution and optionally
    /// return a resume function that can be called to restart the task from
    /// where it left off.
    /// 
    /// - Returns: if need resume
    func stop() async -> Bool
    func resume() async
}

public extension KVHeavyTaskDataProvider {
    func resume() async {}
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
        public enum PriorityStrategy {
            case LIFO(LIFOStrategy)
            case FIFO
        }
        
        /// Maximum number of tasks that can be queued in memory
        public let maxNumberOfQueueingTasks: Int
        
        /// Maximum number of concurrent threads for task execution
        public let maxNumberOfRunningTasks: Int
        
        /// Retry configuration for failed heavy task operations
        public let retryCount: RetryCount
        
        /// Priority strategy for task execution order
        public let PriorityStrategy: PriorityStrategy
        
        /// Cache configuration for heavy task results
        public let cacheConfig: MemoryCache<K, Element>.Configuration
        
        /// Optional callback for cache statistics reporting
        public let cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)?
        
        /// Initializes a new KVHeavyTasksManager configuration.
        /// 
        /// - Parameters:
        ///   - maxNumberOfQueueingTasks: Maximum number of tasks in the queue (default: 50)
        ///   - maxNumberOfRunningTasks: Maximum concurrent threads (default: 4)
        ///   - retryCount: Retry configuration for failed requests (default: 0)
        ///   - PriorityStrategy: Priority strategy for task execution (default: .LIFO(.await))
        ///   - cacheConfig: Cache configuration for heavy task results (default: .defaultConfig)
        ///   - cacheStatisticsReport: Optional callback for cache statistics
        public init(maxNumberOfQueueingTasks: Int = 50,
             maxNumberOfRunningTasks: Int = 4,
             retryCount: RetryCount = 0,
             PriorityStrategy: PriorityStrategy = .LIFO(.await),
             cacheConfig: MemoryCache<K, Element>.Configuration = .defaultConfig,
             cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil) {
            self.maxNumberOfQueueingTasks = maxNumberOfQueueingTasks
            self.maxNumberOfRunningTasks = maxNumberOfRunningTasks
            self.retryCount = retryCount
            self.PriorityStrategy = PriorityStrategy
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
        self.keyQueue = .init(capacity: config.maxNumberOfQueueingTasks)
        self.pausedTaskHandles = .init(capacity: config.maxNumberOfQueueingTasks)
        self.runningTaskHandlers = .init(capacity: config.maxNumberOfQueueingTasks)
    }
    
    private let config: Config
    private let cache: Monstore.MemoryCache<K, Element>
    private let keyQueue: KeyQueue<TaskHandlerWrapper>
    private let pausedTaskHandles: KeyQueue<TaskHandlerWrapper>
    private let runningTaskHandlers: KeyQueue<TaskHandlerWrapper>
}

private extension KVHeavyTasksManager {
    private func start(_ key: K) {
        //arrange wrapper
        var wrapper = TaskHandlerWrapper.init(key: key)
        if !keyQueue.contains(key: wrapper) && !pausedTaskHandles.contains(key: wrapper) && !runningTaskHandlers.contains(key: wrapper) {
            if keyQueue.count + pausedTaskHandles.count + runningTaskHandlers.count < config.maxNumberOfQueueingTasks {
            } else {
                switch config.PriorityStrategy {
                case .LIFO(.await):
                    return
                case .LIFO(.stop):
                    return
                case .FIFO:
                    return
                }
            }
        }
        
        //start or resume:
//        if let taskHandler = wrapper.taskHandler {
//            Task {
//                do {
//                    let res = try await taskHandler.start(resumeToken: resumeTokens[key])
//                    switch res {
//                    case .toBeResumed(let resumeToken):
//                        //put key into waiting queue
//                        resumeTokens[key] = resumeToken
//                        break
//                    case .cancel:
//                        //put key into keyQueue
//                        break
//                    case .result(let element):
//                        //publish element
//                        //remove key from running queue
//                        break
//                    }
//                } catch(let error) {
//                    //publish error
//                }
//            }
//        } else {
//            wrapper.taskHandler = .init(key: key, customEventPublisher: {_ in})
//        }
    }
}

private extension KVHeavyTasksManager {
    class TaskHandlerWrapper: Hashable {
        let key: K
        var taskHandler: TaskHandler?
        init(key: K, taskHandler: TaskHandler? = nil) {
            self.key = key
            self.taskHandler = taskHandler
        }
        
        static func == (lhs: KVHeavyTasksManager<TaskHandler>.TaskHandlerWrapper, rhs: KVHeavyTasksManager<TaskHandler>.TaskHandlerWrapper) -> Bool {
            lhs.key == rhs.key
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(key)
        }
    }
}
