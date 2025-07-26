//
//  KVLightTasks.swift
//  Monstask
//
//  Created by Larkin on 2025/7/20.
//

import Foundation
import Monstore
import MonstraBase

public extension KVLightTasks {
    enum DataProvider {
        public typealias MonofetchCallback = (Result<Element?, Error>)->Void
        public typealias MultifetchCallback = (Result<[K: Element?], Error>)->Void
        
        public typealias Monofetch = (K, @escaping MonofetchCallback)->Void
        public typealias AsyncMonofetch = (K) async throws -> Element?
        public typealias SyncMonofetch = (K) throws -> Element?
        public typealias Multifetch = ([K], @escaping MultifetchCallback)->Void
        public typealias AsyncMultifetch = ([K]) async throws -> [K: Element?]
        public typealias SyncMultifetch = ([K]) throws -> [K: Element?]
        
        case monofetch(Monofetch)
        case asyncMonofetch(AsyncMonofetch)
        case syncMonofetch(SyncMonofetch)
        case multifetch(maximumBatchCount: UInt, Multifetch)
        case asyncMultifetch(maximumBatchCount: UInt, AsyncMultifetch)
        case syncMultifetch(maximumBatchCount: UInt, SyncMultifetch)
    }
    
    struct Config {
        fileprivate let privateDataProvider: PrivateDataProvider
        
        public enum KeyPriority {
            case LIFO
            case FIFO
        }
        public let dataProvider: DataProvider
        
        public let maximumTaskNumberInQueue: Int
        public let maximumConcurrentRunningThreadNumber: Int
        public let retryCount: RetryCount
        public let keyPriority: KeyPriority
        
        /// Cache configuration that controls memory limits, TTL, key validation, and thread safety.
        /// 
        /// The keyValidator in this configuration is used to automatically filter out invalid keys
        /// during fetch operations. Keys that fail validation will return nil without triggering
        /// network requests, improving performance and preventing unnecessary API calls.
        public let cacheConfig: MemoryCache<K, Element>.Configuration
        
        /// Optional callback for cache statistics reporting
        public let cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)?
        
        /// Initializes a new KVLightTasks configuration.
        /// 
        /// - Parameters:
        ///   - dataProvider: The data provider for fetching elements
        ///   - maximumTaskNumberInQueue: Maximum number of tasks in the queue (default: 1024)
        ///   - maximumConcurrentRunningThreadNumber: Maximum concurrent threads (default: 4)
        ///   - retryCount: Retry configuration for failed requests (default: 0)
        ///   - keyPriority: Queue priority strategy (default: .LIFO)
        ///   - cacheConfig: Cache configuration including key validation (default: .defaultConfig)
        ///     - The keyValidator in cacheConfig automatically filters invalid keys
        ///     - Invalid keys return nil without network requests
        ///   - cacheStatisticsReport: Optional callback for cache statistics
        init(dataProvider: DataProvider,
             maximumTaskNumberInQueue: Int = 1024,
             maximumConcurrentRunningThreadNumber: Int = 4,
             retryCount: RetryCount = 0,
             keyPriority: KeyPriority = .LIFO,
             cacheConfig: MemoryCache<K, Element>.Configuration = .defaultConfig,
             cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil) {
            self.dataProvider = dataProvider
            
            switch dataProvider {
            case .monofetch(let monofetch):
                self.privateDataProvider = .monofetch(monofetch)
            case .multifetch(let maximumBatchCount, let multifetch):
                self.privateDataProvider = .multifetch(maximumBatchCount: maximumBatchCount, multifetch)
            case .asyncMonofetch(let asyncMonofetch):
                self.privateDataProvider = .monofetch({ key, callback in
                    Task {
                        do {
                            let res = try await asyncMonofetch(key)
                            callback(.success(res))
                        } catch(let error) {
                            callback(.failure(error))
                        }
                    }
                })
            case .asyncMultifetch(let maximumBatchCount, let asyncMultifetch):
                self.privateDataProvider = .multifetch(maximumBatchCount: maximumBatchCount, { keys, callback in
                    Task {
                        do {
                            let res = try await asyncMultifetch(keys)
                            callback(.success(res))
                        } catch(let error) {
                            callback(.failure(error))
                        }
                    }
                })
            case .syncMonofetch(let syncMonofetch):
                self.privateDataProvider = .monofetch({ key, callback in
                    do {
                        let res = try syncMonofetch(key)
                        callback(.success(res))
                    } catch(let error) {
                        callback(.failure(error))
                    }
                })
            case .syncMultifetch(let maximumBatchCount, let syncMultifetch):
                self.privateDataProvider = .multifetch(maximumBatchCount: maximumBatchCount, { keys, callback in
                    do {
                        let res = try syncMultifetch(keys)
                        callback(.success(res))
                    } catch(let error) {
                        callback(.failure(error))
                    }
                })
            }
            
            
            self.maximumTaskNumberInQueue = maximumTaskNumberInQueue
            self.maximumConcurrentRunningThreadNumber = maximumConcurrentRunningThreadNumber
            self.retryCount = retryCount
            self.keyPriority = keyPriority
            self.cacheConfig = cacheConfig
            self.cacheStatisticsReport = cacheStatisticsReport
        }
    }
}

public extension KVLightTasks {
    typealias ResultCallback = (K, Result<Element?, Error>) -> Void
    typealias BatchResultCallback = ([(K, Result<Element?, Error>)]) -> Void
    /// Fetches a single key and returns the result via callback.
    /// 
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    /// 
    /// - Parameters:
    ///   - key: The key to fetch
    ///   - completion: Callback that receives the result for the key
    func fetch(key: K, completion: @escaping ResultCallback) {
        fetchWithCallback(keys: [key], dispatchQueue: .global(), completion: completion)
    }
    
    /// Fetches multiple keys and returns results via callback for each key.
    /// 
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    /// 
    /// **Important**: This method guarantees that the completion callback will be called
    /// exactly once for each key in the input array, regardless of whether the key
    /// is found in cache or requires remote fetching. For example, if you pass 5 keys,
    /// the completion callback will be called exactly 5 times, once for each key.
    /// 
    /// - Parameters:
    ///   - keys: Array of keys to fetch
    ///   - completion: Callback that receives results for each key (called once per key)
    func fetch(keys: [K], completion: @escaping ResultCallback) {
        fetchWithCallback(keys: keys, dispatchQueue: .global(), completion: completion)
    }
    
    /// Fetches multiple keys and returns results via batch callback.
    /// 
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    /// 
    /// **Important**: This method guarantees that the batch callback will be called
    /// exactly once with all results, regardless of whether keys are found in cache
    /// or require remote fetching. The callback receives an array of (key, result) tuples.
    /// 
    /// **Note**: Duplicate keys in the input array are handled by deduplication at the
    /// unique key level, ensuring each unique key is fetched only once while still
    /// providing results for all input keys including duplicates.
    /// 
    /// - Parameters:
    ///   - keys: Array of keys to fetch (duplicates are allowed)
    ///   - multiCallback: Batch callback that receives all results at once
    func fetch(keys: [K], multiCallback: @escaping BatchResultCallback) {
        guard keys.count > 0 else { 
            multiCallback([])
            return
        }
        
        var results = [K: Result<Element?, Error>]()
        let resultsSemaphore = DispatchSemaphore(value: 1)
        let keysCount = Set<K>(keys).count
        fetchWithCallback(keys: keys) { key, result in
            resultsSemaphore.wait()
            results[key] = result
            
            if results.count == keysCount {
                DispatchQueue.global().async {
                    multiCallback(
                        keys.map { ($0, results[$0] ?? .success(nil)) }
                    )
                }
            }
            
            resultsSemaphore.signal()
        }
    }
    
    /// Fetches multiple keys and returns results asynchronously.
    /// 
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    /// 
    /// **Important**: This method guarantees that results will be returned for each key
    /// in the input array, regardless of whether the key is found in cache or requires
    /// remote fetching. For example, if you pass 5 keys, you will receive exactly 5 results.
    /// 
    /// **Note**: Duplicate keys in the input array are handled by deduplication at the
    /// unique key level, ensuring each unique key is fetched only once while still
    /// providing results for all input keys including duplicates.
    /// 
    /// This is the async/await version of the batch callback-based `fetch(keys:multiCallback:)` method.
    /// It provides a more modern Swift concurrency interface for batch key fetching.
    /// 
    /// - Parameter keys: Array of keys to fetch (duplicates are allowed)
    /// - Returns: Array of tuples containing (key, result) pairs
    func asyncFetch(keys: [K]) async -> [(K, Result<Element?, Error>)] {
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            fetch(keys: keys, multiCallback: { results in
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: results)
                }
            })
        }
    }
    
    /// Fetches a single key and returns the result asynchronously.
    ///
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    ///
    /// This is the async/await version of the callback-based `fetch(key:completion:)` method.
    /// It provides a more modern Swift concurrency interface for single key fetching.
    ///
    /// - Parameter key: The key to fetch
    /// - Returns: The fetched element, or nil if not found or invalid
    /// - Throws: Any error that occurs during the fetch operation
    func asyncFetchThrowing(key: K) async throws -> Element? {
        return try await withCheckedThrowingContinuation { continuation in
            fetch(key: key) { key, result in
                switch result {
                case .success(let element):
                    continuation.resume(returning: element)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Fetches a single key and returns the result asynchronously.
    /// 
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    /// 
    /// This is the async/await version of the callback-based `fetch(key:completion:)` method.
    /// It provides a more modern Swift concurrency interface for single key fetching.
    /// Unlike `asyncFetchThrowing`, this method returns a `Result` type that encapsulates
    /// both success and failure cases, allowing for more flexible error handling.
    /// 
    /// - Parameter key: The key to fetch
    /// - Returns: A Result containing the fetched element or an error
    func asyncFetch(key: K) async -> Result<Element?, Error> {
        return await withCheckedContinuation { continuation in
            fetch(key: key) { _, result in
                continuation.resume(returning: result)
            }
        }
    }
    
    convenience init(config: Config) {
        self.init(config)
    }
}

private extension KVLightTasks {
    enum PrivateDataProvider {
        case monofetch(DataProvider.Monofetch)
        case multifetch(maximumBatchCount: UInt, DataProvider.Multifetch)
    }
}

public class KVLightTasks<K: Hashable, Element> {
    private init(_ config: Config) {
        self.config = config
        self.cache = .init(configuration: config.cacheConfig, statisticsReport: config.cacheStatisticsReport)
        self.keyQueue = .init(capacity: config.maximumTaskNumberInQueue)
    }
    
    private let config: Config
    private let cache: Monstore.MemoryCache<K, Element>
    private let keyQueue: KeyQueue<K>
    
    //MARK: - fetch
    /// DispatchSemaphore for thread synchronization (used when enableThreadSynchronization=true)
    private let semaphore = DispatchSemaphore(value: 1)
    
    /// Internal method that handles the core fetching logic with cache integration.
    /// 
    /// This method processes keys in the following order:
    /// 1. Checks cache for each key using the configured cache settings
    /// 2. For cache hits (both null and non-null elements), immediately returns the cached value
    /// 3. For cache misses, queues the key for remote fetching
    /// 4. Automatically ignores invalid keys as defined by cacheConfig.keyValidator
    ///    - Invalid keys return .success(nil) without any network requests
    ///    - This prevents unnecessary network calls for keys that would be rejected by the cache
    /// 
    /// - Parameters:
    ///   - keys: Array of keys to process
    ///   - dispatchQueue: Optional dispatch queue for callback execution
    ///   - completion: Callback to receive results for each key
    private func fetchWithCallback(keys: [K], dispatchQueue: DispatchQueue? = nil, completion: @escaping ResultCallback) {
        semaphore.wait()
        defer { semaphore.signal() }
        var remoteKeys = [K]()
        keys.forEach { key in
            switch cache.getElement(for: key) {
            case .invalidKey:
                if let dispatchQueue {
                    dispatchQueue.async { completion(key, .success(nil)) }
                } else {
                    completion(key, .success(nil))
                }
            case .hitNullElement:
                if let dispatchQueue {
                    dispatchQueue.async { completion(key, .success(nil)) }
                } else {
                    completion(key, .success(nil))
                }
            case .hitNonNullElement(element: let element):
                if let dispatchQueue {
                    dispatchQueue.async { completion(key, .success(element)) }
                } else {
                    completion(key, .success(element))
                }
            case .miss:
                remoteKeys.append(key)
            }
        }
        
        if remoteKeys.count == 0 { return }
        
        let _remoteKeys = remoteKeys.filter { resultCallbacks[$0] == nil }
        cacheResultCallback(keys: remoteKeys, callback: completion)
        
        startTaskExecution(keys: _remoteKeys) { [weak self] key, res in
            guard let self else { return }
            semaphore.wait()
            defer { semaphore.signal() }
            if case .success(let element) = res {
                cache.set(element: element, for: key)
            }
            consumeCallbacks(key: key, dispatchQueue: dispatchQueue, result: res)
        }
    }
    
    //MARK: -  result callback allocation management
    private var resultCallbacks: [K: [ResultCallback]] = .init()
    private func cacheResultCallback(keys: [K], callback: @escaping ResultCallback) {
        for key in keys {
            if resultCallbacks[key] == nil {
                resultCallbacks[key] = .init()
            }
            resultCallbacks[key]?.append(callback)
        }
    }
    private func consumeCallbacks(key: K, dispatchQueue: DispatchQueue? = nil, result: Result<Element?, Error>) {
        resultCallbacks[key]?.forEach { callback in
            if let dispatchQueue {
                dispatchQueue.async { callback(key, result) }
            } else {
                callback(key, result)
            }
        }
        resultCallbacks.removeValue(forKey: key)
    }
    
    //MARK: - thread & task execution management
    private var activeThreadCount: Int = 0
    private func startTaskExecution(keys: [K], callback: @escaping ResultCallback) {
        if keys.count == 0 { return }
        let _keys = Set<K>(keys)
        let keys = Array<K>(_keys)
        switch config.privateDataProvider {
        case .monofetch(let monofetch):
            let additionalThreadCount = min(config.maximumConcurrentRunningThreadNumber - activeThreadCount, keys.count)
            activeThreadCount += additionalThreadCount
            
            for i in 0..<keys.count {
                if i < additionalThreadCount {
                    _startOneMonofetchThread(key: keys[i], fetch: monofetch, callback: callback)
                } else {
                    keyQueue.enqueueFront(key: keys[i])
                }
            }
        case .multifetch(let maximumBatchCount, let multifetch):
            var restKeys = keys
            while activeThreadCount < config.maximumConcurrentRunningThreadNumber {
                activeThreadCount += 1
                
                if restKeys.count <= maximumBatchCount {
                    _startOneMultifetchThread(keys: restKeys, batchCount: maximumBatchCount, fetch: multifetch, callback: callback)
                    restKeys = []
                    break
                } else {
                    let _keys = Array(restKeys[0..<Int(maximumBatchCount)])
                    restKeys = Array(restKeys[Int(maximumBatchCount)..<restKeys.count])
                    _startOneMultifetchThread(keys: _keys, batchCount: maximumBatchCount, fetch: multifetch, callback: callback)
                }
            }
            
            for key in restKeys {
                keyQueue.enqueueFront(key: key)
            }
        }
    }
    
    // Start individual monofetch thread
    private func _startOneMonofetchThread(key: K? = nil, fetch: @escaping DataProvider.Monofetch, callback: @escaping ResultCallback) {
        guard let key else {
            let nextKey: K?
            switch config.keyPriority {
            case .LIFO:
                nextKey = keyQueue.dequeueFront()
            case .FIFO:
                nextKey = keyQueue.dequeueBack()
            }
            guard let nextKey else {
                activeThreadCount -= 1
                return
            }
            _startOneMonofetchThread(key: nextKey, fetch: fetch, callback: callback)
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            
            _executeMonofetch(key: key, fetch: fetch) { [weak self] key, res in
                guard let self else { return }
                switch res {
                case .success(let element):
                    callback(key, .success(element))
                    _startOneMonofetchThread(fetch: fetch, callback: callback)
                case .failure(let error):
                    callback(key, .failure(error))
                }
            }
        }
    }
    
    private func _startOneMultifetchThread(keys: [K]? = nil, batchCount: UInt, fetch: @escaping DataProvider.Multifetch, callback: @escaping ResultCallback) {
        guard let keys else {
            let _keys: [K]
            switch config.keyPriority {
            case .LIFO:
                _keys = keyQueue.dequeueFront(count: batchCount)
            case .FIFO:
                _keys = keyQueue.dequeueBack(count: batchCount)
            }
            _startOneMultifetchThread(keys: _keys, batchCount: batchCount, fetch: fetch, callback: callback)
            return
        }
        guard keys.count > 0 else {
            activeThreadCount -= 1
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            _executeMultifetch(keys: keys, fetch: fetch) { [weak self] res in
                guard let self else { return }
                _startOneMultifetchThread(batchCount: batchCount, fetch: fetch, callback: callback)
                res.forEach { callback($0.0, $0.1) }
            }
        }
    }
    
    // Handle retry logic for monofetch operations
    private func _executeMonofetch(key: K, fetch: @escaping DataProvider.Monofetch, retryCount: RetryCount? = nil, callback: @escaping ResultCallback) {
        fetch(key) { [weak self] res in
            guard let self else { return }
            switch res {
            case .success(let element):
                callback(key, .success(element))
            case .failure(let error):
                let retryCount = retryCount ?? self.config.retryCount
                if let timeInterval = retryCount.shouldRetry {
                    Thread.sleep(forTimeInterval: timeInterval)
                    self._executeMonofetch(key: key, fetch: fetch, retryCount: retryCount.next(), callback: callback)
                } else {
                    callback(key, .failure(error))
                }
            }
        }
    }
    
    private func _executeMultifetch(keys: [K], fetch: @escaping DataProvider.Multifetch, retryCount: RetryCount? = nil, callback: @escaping BatchResultCallback) {
        fetch(keys) { [weak self] res in
            guard let self else { return }
            switch res {
            case .success(let elements):
                callback(keys.map { ($0, .success(elements[$0] ?? nil)) })
            case .failure(let error):
                let retryCount = retryCount ?? self.config.retryCount
                if let timeInterval = retryCount.shouldRetry {
                    Thread.sleep(forTimeInterval: timeInterval)
                    self._executeMultifetch(keys: keys, fetch: fetch, retryCount: retryCount.next(), callback: callback)
                } else {
                    callback(keys.map { ($0, .failure(error)) })
                }
            }
        }
    }
}
