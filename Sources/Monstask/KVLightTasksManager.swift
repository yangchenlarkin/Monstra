import Foundation

public extension KVLightTasksManager {
    enum DataProvider {
        public typealias MonoprovideCallback = (Result<Element?, Error>) -> Void
        public typealias MultiprovideCallback = (Result<[K: Element?], Error>) -> Void

        public typealias Monoprovide = (K, @escaping MonoprovideCallback) -> Void
        public typealias AsyncMonoprovide = (K) async throws -> Element?
        public typealias SyncMonoprovide = (K) throws -> Element?
        public typealias Multiprovide = ([K], @escaping MultiprovideCallback) -> Void
        public typealias AsyncMultiprovide = ([K]) async throws -> [K: Element?]
        public typealias SyncMultiprovide = ([K]) throws -> [K: Element?]

        case monoprovide(Monoprovide)
        case asyncMonoprovide(AsyncMonoprovide)
        case syncMonoprovide(SyncMonoprovide)
        case multiprovide(maximumBatchCount: UInt = 20, Multiprovide)
        case asyncMultiprovide(maximumBatchCount: UInt = 20, AsyncMultiprovide)
        case syncMultiprovide(maximumBatchCount: UInt = 20, SyncMultiprovide)
    }

    struct Config {
        fileprivate let privateDataProvider: PrivateDataProvider

        public enum PriorityStrategy {
            case LIFO
            case FIFO
        }

        public let dataProvider: DataProvider

        public let maxNumberOfQueueingTasks: Int
        public let maxNumberOfRunningTasks: Int
        public let retryCount: RetryCount
        public let PriorityStrategy: PriorityStrategy

        /// Cache configuration that controls memory limits, TTL, key validation, and thread safety.
        ///
        /// The keyValidator in this configuration is used to automatically filter out invalid keys
        /// during provide operations. Keys that fail validation will return nil without triggering
        /// network requests, improving performance and preventing unnecessary API calls.
        public let cacheConfig: MemoryCache<K, Element>.Configuration

        /// Optional callback for cache statistics reporting
        public let cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)?

        /// Initializes a new KVLightTasksManager configuration.
        ///
        /// - Parameters:
        ///   - dataProvider: The data provider for providing elements
        ///   - maxNumberOfQueueingTasks: Maximum number of tasks in the queue (default: 16)
        ///   - maxNumberOfRunningTasks: Maximum concurrent threads (default: 4)
        ///   - retryCount: Retry configuration for failed requests (default: 0)
        ///   - PriorityStrategy: Queue priority strategy (default: .LIFO)
        ///   - cacheConfig: Cache configuration including key validation (default: .defaultConfig)
        ///     - The keyValidator in cacheConfig automatically filters invalid keys
        ///     - Invalid keys return nil without network requests
        ///   - cacheStatisticsReport: Optional callback for cache statistics
        init(
            dataProvider: DataProvider,
            maxNumberOfQueueingTasks: Int = 256,
            maxNumberOfRunningTasks: Int = 4,
            retryCount: RetryCount = 0,
            PriorityStrategy: PriorityStrategy = .LIFO,
            cacheConfig: MemoryCache<K, Element>.Configuration = .defaultConfig,
            cacheStatisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil
        ) {
            self.dataProvider = dataProvider

            switch dataProvider {
            case let .monoprovide(monoprovide):
                privateDataProvider = .monoprovide(monoprovide)
            case let .multiprovide(maximumBatchCount, multiprovide):
                privateDataProvider = .multiprovide(maximumBatchCount: maximumBatchCount, multiprovide)
            case let .asyncMonoprovide(asyncMonoprovide):
                privateDataProvider = .monoprovide { key, callback in
                    Task {
                        do {
                            let res = try await asyncMonoprovide(key)
                            callback(.success(res))
                        } catch {
                            callback(.failure(error))
                        }
                    }
                }
            case let .asyncMultiprovide(maximumBatchCount, asyncMultiprovide):
                privateDataProvider = .multiprovide(maximumBatchCount: maximumBatchCount) { keys, callback in
                    Task {
                        do {
                            let res = try await asyncMultiprovide(keys)
                            callback(.success(res))
                        } catch {
                            callback(.failure(error))
                        }
                    }
                }
            case let .syncMonoprovide(syncMonoprovide):
                privateDataProvider = .monoprovide { key, callback in
                    do {
                        let res = try syncMonoprovide(key)
                        callback(.success(res))
                    } catch {
                        callback(.failure(error))
                    }
                }
            case let .syncMultiprovide(maximumBatchCount, syncMultiprovide):
                privateDataProvider = .multiprovide(maximumBatchCount: maximumBatchCount) { keys, callback in
                    do {
                        let res = try syncMultiprovide(keys)
                        callback(.success(res))
                    } catch {
                        callback(.failure(error))
                    }
                }
            }

            self.maxNumberOfQueueingTasks = maxNumberOfQueueingTasks
            self.maxNumberOfRunningTasks = maxNumberOfRunningTasks
            self.retryCount = retryCount
            self.PriorityStrategy = PriorityStrategy
            self.cacheConfig = cacheConfig
            self.cacheStatisticsReport = cacheStatisticsReport
        }
    }
}

public extension KVLightTasksManager {
    typealias ResultCallback = (K, Result<Element?, Error>) -> Void
    typealias BatchResultCallback = ([(K, Result<Element?, Error>)]) -> Void

    convenience init(config: Config) {
        self.init(config)
    }

    convenience init(dataProvider: DataProvider) {
        self.init(Config(dataProvider: dataProvider))
    }

    convenience init(_ provide: @escaping DataProvider.Monoprovide) {
        self.init(dataProvider: .monoprovide(provide))
    }

    convenience init(_ provide: @escaping DataProvider.AsyncMonoprovide) {
        self.init(dataProvider: .asyncMonoprovide(provide))
    }

    convenience init(_ provide: @escaping DataProvider.SyncMonoprovide) {
        self.init(dataProvider: .syncMonoprovide(provide))
    }

    convenience init(maximumBatchCount: UInt = 20, _ provide: @escaping DataProvider.Multiprovide) {
        self.init(dataProvider: .multiprovide(maximumBatchCount: maximumBatchCount, provide))
    }

    convenience init(maximumBatchCount: UInt = 20, _ provide: @escaping DataProvider.AsyncMultiprovide) {
        self.init(dataProvider: .asyncMultiprovide(maximumBatchCount: maximumBatchCount, provide))
    }

    convenience init(maximumBatchCount: UInt = 20, _ provide: @escaping DataProvider.SyncMultiprovide) {
        self.init(dataProvider: .syncMultiprovide(maximumBatchCount: maximumBatchCount, provide))
    }

    enum Errors: Error {
        case evictedByPriorityStrategy
    }

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
                // Capture results dictionary safely to prevent memory corruption
                let capturedResults = results
                DispatchQueue.global().async {
                    multiCallback(
                        keys.map { ($0, capturedResults[$0] ?? .success(nil)) }
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
            fetch(key: key) { _, result in
                switch result {
                case let .success(element):
                    continuation.resume(returning: element)
                case let .failure(error):
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
}

private extension KVLightTasksManager {
    enum PrivateDataProvider {
        case monoprovide(DataProvider.Monoprovide)
        case multiprovide(maximumBatchCount: UInt, DataProvider.Multiprovide)
    }
}

public class KVLightTasksManager<K: Hashable, Element> {
    private init(_ config: Config) {
        self.config = config
        cache = .init(configuration: config.cacheConfig, statisticsReport: config.cacheStatisticsReport)
        keyQueue = .init(capacity: config.maxNumberOfQueueingTasks)
    }

    private let config: Config
    private let cache: MemoryCache<K, Element>
    private let keyQueue: HashQueue<K>

    // MARK: - fetch

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
    private func fetchWithCallback(
        keys: [K],
        dispatchQueue: DispatchQueue? = nil,
        completion: @escaping ResultCallback
    ) {
        semaphore.wait()
        defer { semaphore.signal() }
        let dispatchQueue = dispatchQueue ?? DispatchQueue.global()
        var remoteKeys = [K]()
        for key in keys {
            switch cache.getElement(for: key) {
            case .invalidKey:
                dispatchQueue.async { completion(key, .success(nil)) }
            case .hitNullElement:
                dispatchQueue.async { completion(key, .success(nil)) }
            case let .hitNonNullElement(element: element):
                dispatchQueue.async { completion(key, .success(element)) }
            case .miss:
                remoteKeys.append(key)
            }
        }

        if remoteKeys.count == 0 { return }

        let _remoteKeys = remoteKeys.filter { resultCallbacks[$0] == nil }
        cacheResultCallback(keys: remoteKeys, callback: completion)

        startTaskExecution(keys: _remoteKeys) { [weak self] key, res in
            DispatchQueue.global().async {
                guard let self else { return }
                self.semaphore.wait()
                defer { self.semaphore.signal() }
                if case let .success(element) = res {
                    self.cache.set(element: element, for: key)
                }
                self.consumeCallbacks(key: key, dispatchQueue: dispatchQueue, result: res)
            }
        }
    }

    // MARK: -  result callback allocation management

    private var resultCallbacks: [K: [ResultCallback]] = .init()
    private func cacheResultCallback(keys: [K], callback: @escaping ResultCallback) {
        for key in keys {
            if resultCallbacks[key] == nil {
                resultCallbacks[key] = .init()
            }
            resultCallbacks[key]?.append(callback)
        }
    }

    private func consumeCallbacks(key: K, dispatchQueue: DispatchQueue, result: Result<Element?, Error>) {
        resultCallbacks[key]?.forEach { callback in
            dispatchQueue.async { callback(key, result) }
        }
        resultCallbacks.removeValue(forKey: key)
    }

    // MARK: - thread & task execution management

    private var activeThreadCount: Int = 0
    private func startTaskExecution(keys: [K], callback: @escaping ResultCallback) {
        if keys.count == 0 { return }
        var _keys = Set<K>()
        let keys = keys.filter { key in
            if _keys.contains(key) { return false }
            _keys.insert(key)
            return true
        }

        switch config.privateDataProvider {
        case let .monoprovide(monoprovide):
            let additionalThreadCount = min(config.maxNumberOfRunningTasks - activeThreadCount, keys.count)
            activeThreadCount += additionalThreadCount

            for i in 0 ..< keys.count {
                if i < additionalThreadCount {
                    _startOneMonoprovideThread(key: keys[i], provide: monoprovide, callback: callback)
                }
            }
            if additionalThreadCount < keys.count {
                _pushKeyIntoHashQueue(keys: keys[additionalThreadCount...], callback: callback)
            }

        case let .multiprovide(maximumBatchCount, multiprovide):
            var restKeys = keys
            while activeThreadCount < config.maxNumberOfRunningTasks {
                activeThreadCount += 1

                if restKeys.count <= maximumBatchCount {
                    _startOneMultiprovideThread(
                        keys: restKeys,
                        batchCount: maximumBatchCount,
                        provide: multiprovide,
                        callback: callback
                    )
                    restKeys = []
                    break
                } else {
                    let _keys = Array(restKeys[0 ..< Int(maximumBatchCount)])
                    restKeys = Array(restKeys[Int(maximumBatchCount) ..< restKeys.count])
                    _startOneMultiprovideThread(
                        keys: _keys,
                        batchCount: maximumBatchCount,
                        provide: multiprovide,
                        callback: callback
                    )
                }
            }

            _pushKeyIntoHashQueue(keys: restKeys[...], callback: callback)
        }
    }

    // Start individual monoprovide thread
    private func _startOneMonoprovideThread(
        key: K? = nil,
        provide: @escaping DataProvider.Monoprovide,
        callback: @escaping ResultCallback
    ) {
        guard let key else {
            let nextKey: K?
            switch config.PriorityStrategy {
            case .LIFO:
                nextKey = keyQueue.dequeueFront()
            case .FIFO:
                nextKey = keyQueue.dequeueBack()
            }
            guard let nextKey else {
                activeThreadCount -= 1
                return
            }
            _startOneMonoprovideThread(key: nextKey, provide: provide, callback: callback)
            return
        }

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }

            _executeMonoprovide(key: key, provide: provide) { [weak self] key, res in
                DispatchQueue.global().async { [weak self] in
                    guard let self else { return }
                    semaphore.wait()
                    defer { semaphore.signal() }
                    switch res {
                    case let .success(element):
                        callback(key, .success(element))
                        _startOneMonoprovideThread(provide: provide, callback: callback)
                    case let .failure(error):
                        callback(key, .failure(error))
                    }
                }
            }
        }
    }

    private func _startOneMultiprovideThread(
        keys: [K]? = nil,
        batchCount: UInt,
        provide: @escaping DataProvider.Multiprovide,
        callback: @escaping ResultCallback
    ) {
        guard let keys else {
            let _keys: [K]
            switch config.PriorityStrategy {
            case .LIFO:
                _keys = keyQueue.dequeueFront(count: batchCount)
            case .FIFO:
                _keys = keyQueue.dequeueBack(count: batchCount)
            }
            _startOneMultiprovideThread(keys: _keys, batchCount: batchCount, provide: provide, callback: callback)
            return
        }
        guard keys.count > 0 else {
            activeThreadCount -= 1
            return
        }

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            _executeMultiprovide(keys: keys, provide: provide) { [weak self] res in
                DispatchQueue.global().async { [weak self] in
                    guard let self else { return }
                    semaphore.wait()
                    defer { semaphore.signal() }
                    _startOneMultiprovideThread(batchCount: batchCount, provide: provide, callback: callback)
                    res.forEach { res in DispatchQueue.global().async { callback(res.0, res.1) } }
                }
            }
        }
    }

    // Handle retry logic for monoprovide operations
    private func _executeMonoprovide(
        key: K,
        provide: @escaping DataProvider.Monoprovide,
        retryCount: RetryCount? = nil,
        callback: @escaping ResultCallback
    ) {
        provide(key) { [weak self] res in
            guard let self else { return }
            switch res {
            case let .success(element):
                callback(key, .success(element))
            case let .failure(error):
                let retryCount = retryCount ?? self.config.retryCount
                if retryCount.shouldRetry {
                    Thread.sleep(forTimeInterval: retryCount.timeInterval)
                    self._executeMonoprovide(
                        key: key,
                        provide: provide,
                        retryCount: retryCount.next(),
                        callback: callback
                    )
                } else {
                    callback(key, .failure(error))
                }
            }
        }
    }

    private func _executeMultiprovide(
        keys: [K],
        provide: @escaping DataProvider.Multiprovide,
        retryCount: RetryCount? = nil,
        callback: @escaping BatchResultCallback
    ) {
        provide(keys) { [weak self] res in
            guard let self else { return }
            switch res {
            case let .success(elements):
                callback(keys.map { ($0, .success(elements[$0] ?? nil)) })
            case let .failure(error):
                let retryCount = retryCount ?? self.config.retryCount
                if retryCount.shouldRetry {
                    Thread.sleep(forTimeInterval: retryCount.timeInterval)
                    self._executeMultiprovide(
                        keys: keys,
                        provide: provide,
                        retryCount: retryCount.next(),
                        callback: callback
                    )
                } else {
                    callback(keys.map { ($0, .failure(error)) })
                }
            }
        }
    }

    private func _pushKeyIntoHashQueue(keys: ArraySlice<K>, callback: @escaping ResultCallback) {
        guard keys.count > 0 else { return }
        switch config.PriorityStrategy {
        case .LIFO:
            // For LIFO priority: when queue is full, evict oldest keys (FIFO eviction)
            // This ensures newest keys get priority and oldest keys are removed
            for key in keys {
                if let e = keyQueue.enqueueFront(key: key, evictedStrategy: .FIFO) {
                    callback(e, .failure(Errors.evictedByPriorityStrategy))
                }
            }
        case .FIFO:
            // For FIFO priority: when queue is full, reject new keys (LIFO eviction)
            // This maintains strict order by not evicting existing keys
            for key in keys {
                if let e = keyQueue.enqueueFront(key: key, evictedStrategy: .LIFO) {
                    callback(e, .failure(Errors.evictedByPriorityStrategy))
                }
            }
        }
    }
}
