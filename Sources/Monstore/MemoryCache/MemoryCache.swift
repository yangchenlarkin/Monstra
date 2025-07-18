//
//  MemoryCache.swift
//  Monstore
//
//  Created by Larkin on 2025/5/21.
//

import Foundation

/**
 A high-performance, in-memory key-value cache with configurable thread safety.
 
 Core Features:
 - TTL (time-to-live) expiration with automatic cleanup
 - Priority-based eviction (higher priority entries are retained longer)
 - LRU (least recently used) eviction within priority levels
 - Null value caching with separate TTL configuration
 - External key validation (validator is set at initialization)
 - TTL randomization to prevent cache stampede
 - Configurable thread safety (enabled by default)
 
 Thread Safety:
 - When enableThreadSynchronization=true (default): All operations are synchronized using NSLock
 - When enableThreadSynchronization=false: No synchronization provided, caller must ensure thread safety
 
 Performance Characteristics:
 - O(1) average case for get/set operations
 - Automatic expiration handling
 - Memory-efficient with configurable capacity limits
 
 Example Usage:
 ```swift
 // Thread-synchronized cache with custom validation
 let cache = MemoryCache<String, Data>(
     configuration: .init(
         enableThreadSynchronization: true,
         capacityLimitation: 1000,
         defaultTTL: 60,
         keyValidator: { $0.hasPrefix("https://") }
     )
 )
 
 // Non-synchronized cache for single-threaded scenarios
 let fastCache = MemoryCache<String, Int>(
     configuration: .init(enableThreadSynchronization: false, capacityLimitation: 500)
 )
 ```
*/

extension MemoryCache {
    // MARK: - Configuration
    
    /// Configuration options for the memory cache.
    struct Configuration {
        /// Whether to enable thread synchronization using NSLock (default: true)
        /// When true: All cache operations are synchronized for thread safety
        /// When false: No synchronization, caller must ensure thread safety
        let enableThreadSynchronization: Bool
        /// Maximum number of entries the cache can hold.
        let capacityLimitation: Int
        /// Default TTL for non-null values (in seconds).
        let defaultTTL: TimeInterval
        /// Default TTL for null values (in seconds).
        let defaultTTLForNullValue: TimeInterval
        /// Randomization range for TTL values to prevent cache stampede (in seconds).
        let ttlRandomizationRange: TimeInterval
        /// Key validation function that returns true for valid keys. Fixed at initialization.
        let keyValidator: ((Key) -> Bool)
        
        /// Creates a new configuration with specified parameters.
        /// - Parameters:
        ///   - enableThreadSynchronization: Enable NSLock synchronization for thread safety (default: true)
        ///   - capacityLimitation: Maximum cache size (default: unlimited)
        ///   - defaultTTL: Default TTL for non-nil values (default: .infinity)
        ///   - defaultTTLForNullValue: Default TTL for nil values (default: .infinity)
        ///   - ttlRandomizationRange: TTL randomization range (default: 0)
        ///   - keyValidator: Key validation closure (default: always true)
        init(
            enableThreadSynchronization: Bool = true,
            capacityLimitation: Int = 1024,
            defaultTTL: TimeInterval = .infinity,
            defaultTTLForNullValue: TimeInterval = .infinity,
            ttlRandomizationRange: TimeInterval = 0,
            keyValidator: @escaping (Key) -> Bool = {_ in true}
        ) {
            self.enableThreadSynchronization = enableThreadSynchronization
            self.defaultTTL = defaultTTL
            self.defaultTTLForNullValue = defaultTTLForNullValue
            self.ttlRandomizationRange = ttlRandomizationRange
            self.capacityLimitation = max(0, capacityLimitation)
            self.keyValidator = keyValidator
        }
        
        /// Default configuration (thread-synchronized with NSLock, unlimited size, no expiration, all keys valid)
        static var defaultConfig: Configuration { .init() }
    }
}

class MemoryCache<Key: Hashable, Element> {
    // MARK: - Initialization
    
    /// Creates a new memory cache with the specified configuration.
    /// - Parameter configuration: The configuration for this cache instance.
    init(configuration: Configuration = .defaultConfig) {
        self.configuration = configuration
        self.storageQueue = TTLPriorityLRUQueue(capacity: configuration.capacityLimitation)
    }
    
    // MARK: - Properties
    
    /// NSLock for thread synchronization (used when enableThreadSynchronization=true)
    private let lock = NSLock()
    /// The configuration for this cache instance.
    private let configuration: Configuration
    /// The underlying TTL-priority-LRU queue for storage.
    private let storageQueue: TTLPriorityLRUQueue<Key, CacheEntry>
    
    /// Internal wrapper for cache entries to support null value caching.
    private struct CacheEntry {
        /// The actual value (can be nil for null caching).
        let value: Element?
        /// Whether this entry represents a null value.
        let isNullValue: Bool
        
        init(value: Element?) {
            self.value = value
            self.isNullValue = value == nil
        }
    }
}

// MARK: - Public API

extension MemoryCache {
    /// Returns true if the cache is empty.
    var isEmpty: Bool {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        return storageQueue.isEmpty
    }
    
    /// Returns true if the cache is full.
    var isFull: Bool {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        return storageQueue.isFull
    }
    
    /// The current number of elements in the cache.
    var count: Int {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        return storageQueue.count
    }
    
    /// The maximum capacity of the cache.
    var capacity: Int {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() } 
        return storageQueue.capacity
    }
    
    /**
     Inserts or updates a value for the given key.
     
     - Parameters:
       - value: The value to store (can be nil for null caching)
       - key: The key to associate with the value
       - priority: The priority for eviction (higher is less likely to be evicted)
       - duration: The TTL (in seconds) for the entry. Defaults to configuration default
     
     - Returns: The evicted value, if any
     
          - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
     @discardableResult
     func set(
        value: Element?,
        for key: Key,
        priority: Double = .zero,
        expiredIn duration: TimeInterval? = nil
    ) -> Element? {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        
        // Step 1: Validate key using external validator
        guard configuration.keyValidator(key) else { return nil }
        
        // Step 2: Handle null value caching
        if value == nil {
            // Calculate TTL for null value
            let finalTTL = calculateFinalTTL(
                originalDuration: duration ?? configuration.defaultTTLForNullValue,
                isNullValue: true
            )
            
            // Store null value in cache
            let cacheEntry = CacheEntry(value: nil)
            let evictedEntry = storageQueue.set(
                value: cacheEntry,
                for: key,
                priority: priority,
                expiredIn: finalTTL
            )
            return evictedEntry?.value
        }
        
        // Step 3: Calculate final TTL with randomization
        let finalTTL = calculateFinalTTL(
            originalDuration: duration ?? configuration.defaultTTL,
            isNullValue: false
        )
        
        // Step 4: Store in queue
        let cacheEntry = CacheEntry(value: value)
        let evictedEntry = storageQueue.set(
            value: cacheEntry,
            for: key,
            priority: priority,
            expiredIn: finalTTL
        )
        return evictedEntry?.value
    }
    
    /**
     Retrieves the value for the given key if present and valid.
     
     - Parameter key: The key to look up
     - Returns: The value if present and valid, or nil if expired, missing, or invalid
     
          - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
     func getValue(for key: Key) -> Element? {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        
        guard configuration.keyValidator(key) else { return nil }
        let cacheEntry = storageQueue.getValue(for: key)
        return cacheEntry?.value
    }
    
    /**
     Removes the value for the given key, if present.
     
     - Parameter key: The key to remove
     - Returns: The removed value, or nil if not found
     
          - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
     @discardableResult
     func removeValue(for key: Key) -> Element? {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        
        let cacheEntry = storageQueue.removeValue(for: key)
        return cacheEntry?.value
    }
}

// MARK: - Private Implementation

private extension MemoryCache {
    /// Calculates the final TTL with randomization applied.
    /// - Parameters:
    ///   - originalDuration: The original TTL duration
    ///   - isNullValue: Whether this is for a null value
    /// - Returns: The final TTL with randomization applied
    func calculateFinalTTL(originalDuration: TimeInterval, isNullValue: Bool) -> TimeInterval {
        // Don't randomize infinite TTL
        guard originalDuration != .infinity else { return originalDuration }
        
        // Apply randomization if configured
        if configuration.ttlRandomizationRange > 0 {
            let randomOffset = Double.random(in: -configuration.ttlRandomizationRange...configuration.ttlRandomizationRange)
            return max(0, originalDuration + randomOffset)
        }
        
        return originalDuration
    }
    
    /// Acquires the NSLock if thread safety is enabled in configuration.
    func acquireLockIfNeeded() {
        guard configuration.enableThreadSynchronization else { return }
        lock.lock()
    }
    
    /// Releases the NSLock if thread safety is enabled in configuration.
    func releaseLockIfNeeded() {
        guard configuration.enableThreadSynchronization else { return }
        lock.unlock()
    }
}
