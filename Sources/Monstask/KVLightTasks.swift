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
    enum DataPovider {
        public typealias MonofetchCallback = (Result<Element?, Error>)->Void
        public typealias MultifetchCallback = (Result<[K: Element?], Error>)->Void
        public typealias Monofetch = (K, @escaping MonofetchCallback)->Void
        public typealias Multifetch = ([K], @escaping MultifetchCallback)->Void
        
        case monofetch(Monofetch)
        case multifetch(maxmumBatchCount: UInt, Multifetch)
        
        var concurrentFetchCount: UInt {
            switch self {
            case .monofetch:
                1
            case .multifetch(let maxmumBatchCount, _):
                maxmumBatchCount
            }
        }
    }
    
    struct Config {
        public enum KeyPriority {
            case LIFO
            case FIFO
        }
        public let dataProvider: DataPovider
        
        public let maxmumTaskNumberInQueue: Int
        public let maxmumConcurrentRunningThreadNumber: Int
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
        ///   - maxmumTaskNumberInQueue: Maximum number of tasks in the queue (default: 1024)
        ///   - maxmumConcurrentRunningThreadNumber: Maximum concurrent threads (default: 4)
        ///   - retryCount: Retry configuration for failed requests (default: 0)
        ///   - keyPriority: Queue priority strategy (default: .LIFO)
        ///   - cacheConfig: Cache configuration including key validation (default: .defaultConfig)
        ///     - The keyValidator in cacheConfig automatically filters invalid keys
        ///     - Invalid keys return nil without network requests
        ///   - cacheStatisticsReport: Optional callback for cache statistics
        init(dataProvider: DataPovider, maxmumTaskNumberInQueue: Int = 1024, maxmumConcurrentRunningThreadNumber: Int = 4, retryCount: RetryCount = 0, keyPriority: KeyPriority = .LIFO, cacheConfig: MemoryCache<K, Element>.Configuration = .defaultConfig, cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil) {
            self.dataProvider = dataProvider
            self.maxmumTaskNumberInQueue = maxmumTaskNumberInQueue
            self.maxmumConcurrentRunningThreadNumber = maxmumConcurrentRunningThreadNumber
            self.retryCount = retryCount
            self.keyPriority = keyPriority
            self.cacheConfig = cacheConfig
            self.cacheStatisticsReport = cacheStatisticsReport
        }
    }
}

public extension KVLightTasks {
    /// Fetches a single key and returns the result via callback.
    /// 
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    /// 
    /// - Parameters:
    ///   - key: The key to fetch
    ///   - monoCallback: Callback that receives the result for the key
    func fetch(key: K, monoCallback: @escaping MonoresultCallback) {
        fetchWithCallback(keys: [key], dispatchQueue: .global(), monoCallback: monoCallback)
    }
    
    /// Fetches multiple keys and returns results via callback for each key.
    /// 
    /// This method automatically handles cache validation and ignores invalid keys
    /// as indicated by the cache configuration's keyValidator. Invalid keys will
    /// return nil without triggering any network requests.
    /// 
    /// - Parameters:
    ///   - keys: Array of keys to fetch
    ///   - monoCallback: Callback that receives results for each key
    func fetch(keys: [K], monoCallback: @escaping MonoresultCallback) {
        fetchWithCallback(keys: keys, dispatchQueue: .global(), monoCallback: monoCallback)
    }
    
//    func fetch(keys: [K], mutiCallback: @escaping MultiresultCallback) {
//        
//    }
}

public class KVLightTasks<K: Hashable, Element> {
    private let config: Config
    private let cache: Monstore.MemoryCache<K, Element>
    private let keyQueue: KeyQueue<K>
    
    public init(config: Config) {
        self.config = config
        self.cache = .init(configuration: config.cacheConfig, statisticsReport: config.cacheStatisticsReport)
        self.keyQueue = .init(capacity: config.maxmumTaskNumberInQueue)
    }
    
    public typealias MonoresultCallback = (K, Result<Element?, Error>) -> Void
    public typealias MultiresultCallback = ([(K, Result<Element?, Error>)]) -> Void
    
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
    ///   - monoCallback: Callback to receive results for each key
    private func fetchWithCallback(keys: [K], dispatchQueue: DispatchQueue? = nil, monoCallback: @escaping MonoresultCallback) {
        semaphore.wait()
        defer { semaphore.signal() }
        var remoteKeys = [K]()
        keys.forEach { key in
            switch cache.getElement(for: key) {
            case .invalidKey:
                if let dispatchQueue {
                    dispatchQueue.async { monoCallback(key, .success(nil)) }
                } else {
                    monoCallback(key, .success(nil))
                }
            case .hitNullElement:
                if let dispatchQueue {
                    dispatchQueue.async { monoCallback(key, .success(nil)) }
                } else {
                    monoCallback(key, .success(nil))
                }
            case .hitNonNullElement(element: let element):
                if let dispatchQueue {
                    dispatchQueue.async { monoCallback(key, .success(element)) }
                } else {
                    monoCallback(key, .success(element))
                }
            case .miss:
                remoteKeys.append(key)
            }
        }
        
        if remoteKeys.count == 0 { return }
        
        let _remoteKeys = remoteKeys.filter { monoresultCallbacks[$0] == nil }
        cacheMonoresultCallback(keys: remoteKeys, callback: monoCallback)
        
        startThread(keys: _remoteKeys) { [weak self] key, res in
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
    private var monoresultCallbacks: [K: [MonoresultCallback]] = .init()
    private func cacheMonoresultCallback(keys: [K], callback: @escaping MonoresultCallback) {
        for key in keys {
            if monoresultCallbacks[key] == nil {
                monoresultCallbacks[key] = .init()
            }
            monoresultCallbacks[key]?.append(callback)
        }
    }
    private func consumeCallbacks(key: K, dispatchQueue: DispatchQueue? = nil, result: Result<Element?, Error>) {
        monoresultCallbacks[key]?.forEach { callback in
            if let dispatchQueue {
                dispatchQueue.async { callback(key, result) }
            } else {
                callback(key, result)
            }
        }
        monoresultCallbacks.removeValue(forKey: key)
    }
    
    //MARK: - thread & task execution management
    private var threadCount: Int = 0
    private func startThread(keys: [K], callback: @escaping MonoresultCallback) {
        if keys.count == 0 { return }
        
        switch config.dataProvider {
        case .monofetch(let monofetch):
            let additionalThreadCount = min(config.maxmumConcurrentRunningThreadNumber - threadCount, keys.count)
            threadCount += additionalThreadCount
            
            for i in 0..<keys.count {
                if i < additionalThreadCount {
                    _startOneMonofetchThread(key: keys[i], fetch: monofetch, callback: callback)
                } else {
                    keyQueue.enqueueFront(key: keys[i])
                }
            }
        case .multifetch(let maxmumBatchCount, let multifetch):
            var restKeys = keys
            while threadCount < config.maxmumConcurrentRunningThreadNumber {
                threadCount += 1
                
                if restKeys.count <= maxmumBatchCount {
                    _startOneMutifetchThread(keys: restKeys, batchCount: maxmumBatchCount, fetch: multifetch, callback: callback)
                    restKeys = []
                    break
                } else {
                    let _keys = Array(restKeys[0..<Int(maxmumBatchCount)])
                    restKeys = Array(restKeys[Int(maxmumBatchCount)..<restKeys.count])
                    _startOneMutifetchThread(keys: _keys, batchCount: maxmumBatchCount, fetch: multifetch, callback: callback)
                }
            }
            
            for key in restKeys {
                keyQueue.enqueueFront(key: key)
            }
        }
    }
    
    //仅启动线程
    private func _startOneMonofetchThread(key: K? = nil, fetch: @escaping DataPovider.Monofetch, callback: @escaping MonoresultCallback) {
        guard let key else {
            let _key: K?
            switch config.keyPriority {
            case .LIFO:
                _key = keyQueue.dequeueFront()
            case .FIFO:
                _key = keyQueue.dequeueBack()
            }
            guard let _key else {
                threadCount -= 1
                return
            }
            _startOneMonofetchThread(key: _key, fetch: fetch, callback: callback)
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
    
    private func _startOneMutifetchThread(keys: [K]? = nil, batchCount: UInt, fetch: @escaping DataPovider.Multifetch, callback: @escaping MonoresultCallback) {
        guard let keys else {
            let _keys: [K]
            switch config.keyPriority {
            case .LIFO:
                _keys = keyQueue.dequeueFront(count: batchCount)
            case .FIFO:
                _keys = keyQueue.dequeueBack(count: batchCount)
            }
            _startOneMutifetchThread(keys: _keys, batchCount: batchCount, fetch: fetch, callback: callback)
            return
        }
        guard keys.count > 0 else {
            threadCount -= 1
            return
        }
        
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            _executeMultifetch(keys: keys, fetch: fetch) { [weak self] res in
                guard let self else { return }
                _startOneMutifetchThread(batchCount: batchCount, fetch: fetch, callback: callback)
                res.forEach { callback($0.0, $0.1) }
            }
        }
    }
    
    //仅处理重试问题
    private func _executeMonofetch(key: K, fetch: @escaping DataPovider.Monofetch, retryCount: RetryCount? = nil, callback: @escaping MonoresultCallback) {
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
    
    private func _executeMultifetch(keys: [K], fetch: @escaping DataPovider.Multifetch, retryCount: RetryCount? = nil, callback: @escaping MultiresultCallback) {
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
