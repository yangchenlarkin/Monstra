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

open class KVHeavyTaskBaseDataProvider<K: Hashable, Element, CustomEvent> {
    /// Callback type for publishing custom events during task execution
    ///
    /// This closure is called to publish progress updates, status changes,
    /// or any other custom events during task execution.
    public typealias CustomEventPublisher = @Sendable (CustomEvent) -> Void
    public typealias ResultPublisher = @Sendable (Result<Element?, Error>)->Void
    
    /// The unique identifier for this task
    public internal(set) var key: K
    
    /// Optional callback for publishing custom events during task execution
    public internal(set) var customEventPublisher: CustomEventPublisher
    
    /// should be called just once after start
    public internal(set) var resultPublisher: ResultPublisher
    
    /// Initializes a new heavy task data provider
    ///
    /// - Parameters:
    ///   - key: The unique identifier for this task
    ///   - customEventPublisher: Optional callback for publishing custom events
    required public init(key: K, customEventPublisher: @escaping CustomEventPublisher, resultPublisher: @escaping ResultPublisher) {
        self.key = key
        self.customEventPublisher = customEventPublisher
        self.resultPublisher = resultPublisher
    }
}

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
public protocol KVHeavyTaskDataProviderInterface {
    associatedtype ResumeData
    /// Executes the heavy task asynchronously
    /// 
    /// This method should implement the main task logic. It can publish progress
    /// updates through the `customEventPublisher` and should handle cancellation
    /// gracefully by checking for task interruption.
    /// 
    /// - Returns: The result of the task execution, or nil if the task was cancelled
    /// - Throws: Any error that occurred during task execution
    func start(resumeData: ResumeData?) async
    
    /// Stops the currently executing task
    /// 
    /// This method should gracefully stop the task execution and optionally
    /// return a resume function that can be called to restart the task from
    /// where it left off.
    /// 
    /// - Returns: if need resume
    @discardableResult
    func stop() async -> ResumeData?
}

extension KVHeavyTaskDataProviderInterface {
    func start(resumeData: ResumeData?, _ callback: (()->Void)? = nil) {
        Task {
            await start(resumeData: resumeData)
            callback?()
        }
    }
    
    func stop(_ callback: ((ResumeData?)->Void)? = nil) {
        Task {
            callback?(await stop())
        }
    }
}

public extension KVHeavyTaskDataProviderInterface {
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
            case FIFO
            case LIFO(LIFOStrategy)
        }
        
        /// Maximum number of tasks that can be queued in memory
        public let maxNumberOfQueueingTasks: Int
        
        /// Maximum number of concurrent threads for task execution
        public let maxNumberOfRunningTasks: Int
        
        /// Priority strategy for task execution order
        public let priorityStrategy: PriorityStrategy
        
        /// Cache configuration for heavy task results
        public let cacheConfig: MemoryCache<K, Element>.Configuration
        
        /// Optional callback for cache statistics reporting
        public let cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)?
        public let resumeDataCacheConfig: MemoryCache<K, DataProvider.ResumeData>.Configuration
        
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
                    priorityStrategy: PriorityStrategy = .LIFO(.await),
                    cacheConfig: MemoryCache<K, Element>.Configuration = .defaultConfig,
                    resumeDataCacheConfig: MemoryCache<K, DataProvider.ResumeData>.Configuration = .defaultConfig,
                    cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil) {
            self.maxNumberOfQueueingTasks = maxNumberOfQueueingTasks
            self.maxNumberOfRunningTasks = maxNumberOfRunningTasks
            self.priorityStrategy = priorityStrategy
            self.cacheConfig = cacheConfig
            self.resumeDataCacheConfig = resumeDataCacheConfig
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
public class KVHeavyTasksManager<K, Element, CustomEvent, DataProvider: KVHeavyTaskBaseDataProvider<K, Element, CustomEvent>> where DataProvider: KVHeavyTaskDataProviderInterface {
    public init(config: Config) {
        self.config = config
        self.cache = .init(configuration: config.cacheConfig, statisticsReport: config.cacheStatisticsReport)
        self.resumeDataCache = .init(configuration: config.resumeDataCacheConfig)
        self.waitingQueue = .init(capacity: config.maxNumberOfQueueingTasks)
        self.runningKeys = .init(capacity: config.maxNumberOfRunningTasks)
    }
    
    public let config: Config
    private let cache: Monstore.MemoryCache<K, Element>
    
    private let resumeDataCache: Monstore.MemoryCache<K, DataProvider.ResumeData>
    private let waitingQueue: KeyQueue<K>
    private let runningKeys: KeyQueue<K>
    
    // Removed unused dataProvider dictionary (using dataProviders instead)
    
    private var customEventObservers: [K: [DataProvider.CustomEventPublisher]] = .init()
    private var resultCallbacks: [K: [DataProvider.ResultPublisher]] = .init()
    private var dataProviders: [K: DataProvider] = .init()
    
    private var semaphore: DispatchSemaphore = .init(value: 1)
}

// Opt-in to Sendable semantics using internal synchronization.
// The manager uses a DispatchSemaphore to protect shared mutable state.
extension KVHeavyTasksManager: @unchecked Sendable {}

public extension KVHeavyTasksManager {
    enum Errors: Error {
        case evictedByPriorityStrategy(K)
    }
    
    func fetch(key: K,
               customEventObserver: DataProvider.CustomEventPublisher? = nil,
               result resultCallback: DataProvider.ResultPublisher? = nil) {
        start(key, customEventObserver: customEventObserver, resultCallback: resultCallback)
    }
}

private extension KVHeavyTasksManager {
    private func start(_ key: K, customEventObserver: DataProvider.CustomEventPublisher?, resultCallback: DataProvider.ResultPublisher?) {
        switch cache.getElement(for: key) {
        case .hitNonNullElement(let element):
            resultCallback?(.success(element))
            return
            
        case .hitNullElement:
            fallthrough
        case .invalidKey:
            resultCallback?(.success(nil))
            return
            
        case .miss:
            break
        }
        
        semaphore.wait()
        defer { semaphore.signal() }
        
        // cache callback
        if let customEventObserver {
            if !customEventObservers.keys.contains(key) {
                customEventObservers[key] = .init()
            }
            customEventObservers[key]?.append(customEventObserver)
        }
        
        if !resultCallbacks.keys.contains(key) {
            resultCallbacks[key] = .init()
        }
        if let resultCallback {
            resultCallbacks[key]?.append(resultCallback)
        }
        
        // try to excute
        switch config.priorityStrategy {
        case .FIFO:
            executeFIFO(key)
        case .LIFO(.await):
            executeLIFOAwait(key)
        case .LIFO(.stop):
            executeLIFOStop(key)
        }
    }
    
    private func executeFIFO(_ key: K) {
        if runningKeys.count < self.config.maxNumberOfRunningTasks {
            runningKeys.enqueueFront(key: key, evictedStrategy: .LIFO)
            startTask(for: key)
            return
        }
        
        if let evictedKey = self.waitingQueue.enqueueFront(key: key, evictedStrategy: .LIFO) {
            consumeCallbacks(for: evictedKey, result: .failure(Errors.evictedByPriorityStrategy(evictedKey)))
        }
    }
    
    private func executeLIFOAwait(_ key: K) {
        if runningKeys.count < self.config.maxNumberOfRunningTasks {
            runningKeys.enqueueFront(key: key, evictedStrategy: .FIFO)
            startTask(for: key)
            return
        }
        
        if let evictedKey = self.waitingQueue.enqueueFront(key: key, evictedStrategy: .FIFO) {
            consumeCallbacks(for: evictedKey, result: .failure(Errors.evictedByPriorityStrategy(evictedKey)))
        }
    }
    
    private func executeLIFOStop(_ key: K) {
        if let keyToStop = runningKeys.enqueueFront(key: key, evictedStrategy: .FIFO) {
            if let evictedKey = self.waitingQueue.enqueueFront(key: keyToStop, evictedStrategy: .FIFO) {
                consumeCallbacks(for: evictedKey, result: .failure(Errors.evictedByPriorityStrategy(evictedKey)))
            }
            if let dataProvider = dataProviders[keyToStop] {
                dataProviders.removeValue(forKey: keyToStop)
                dataProvider.stop() { [weak self] resumeData in
                    guard let self else { return }
                    guard let resumeData else { return }
                    resumeDataCache.set(element: resumeData, for: keyToStop)
                }
            }
        }
        startTask(for: key)
    }
    
    private func startTask(for key: K) {
        let dataProvider = DataProvider(key: key, customEventPublisher: { [weak self] customEvent in
            guard let strongSelf = self else { return }
            strongSelf.semaphore.wait()
            let observers = strongSelf.customEventObservers[key]
            strongSelf.semaphore.signal()
            
            guard let observers else { return }
            
            for observer in observers {
                DispatchQueue.global().async {
                    observer(customEvent)
                }
            }
        }, resultPublisher: { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.semaphore.wait()
            defer { strongSelf.semaphore.signal() }
            
            switch result {
            case .success(let element):
                strongSelf.cache.set(element: element, for: key)
                strongSelf.consumeCallbacks(for: key, result: .success(element))
            case .failure(let error):
                strongSelf.consumeCallbacks(for: key, result: .failure(error))
            }
            
            // Clean up provider for finished key
            strongSelf.dataProviders.removeValue(forKey: key)
            
            strongSelf.runningKeys.remove(key: key)
            
            let nextKey: K?
            switch strongSelf.config.priorityStrategy {
            case .FIFO:
                nextKey = strongSelf.waitingQueue.dequeueBack()
            case .LIFO:
                nextKey = strongSelf.waitingQueue.dequeueFront()
            }
            
            guard let nextKey else { return }
            
            switch strongSelf.config.priorityStrategy {
            case .FIFO:
                strongSelf.runningKeys.enqueueFront(key: nextKey, evictedStrategy: .LIFO)
            case .LIFO:
                strongSelf.runningKeys.enqueueFront(key: nextKey, evictedStrategy: .FIFO)
            }
            
            strongSelf.startTask(for: nextKey)
        })

        dataProvider.start(resumeData: resumeDataCache.getElement(for: key).element)
        self.dataProviders[key] = dataProvider
    }
    
    private func consumeCallbacks(for key: K, result: Result<Element?, Error>) {
        resumeDataCache.removeElement(for: key)
        resultCallbacks[key]?.forEach{ callback in
            DispatchQueue.global().async {
                print(self.resultCallbacks)
                callback(result)
            }
        }
        customEventObservers.removeValue(forKey: key)
    }
}
