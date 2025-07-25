//
//  MemoryCache.swift
//  Monstore
//
//  Created by Larkin on 2025/5/21.
//

import Foundation

/**
 A high-performance, in-memory key-value cache with configurable thread safety and memory management.
 
 ## Core Features
 
 - **TTL (Time-to-Live) Expiration**: Automatic cleanup of expired entries
 - **Priority-Based Eviction**: Higher priority entries are retained longer during eviction
 - **LRU (Least Recently Used) Eviction**: Within priority levels, least recently used entries are evicted first
 - **Null Value Caching**: Support for caching null/nil values with separate TTL configuration
 - **External Key Validation**: Customizable key validation function set at initialization
 - **TTL Randomization**: Prevents cache stampede by randomizing expiration times
 - **Configurable Thread Safety**: Optional NSLock synchronization for concurrent access
 - **Memory Usage Tracking**: Configurable memory limits with automatic eviction
 
 ## Thread Safety
 
 - **Synchronized Mode** (`enableThreadSynchronization=true`): All operations are thread-safe using NSLock
 - **Non-Synchronized Mode** (`enableThreadSynchronization=false`): No synchronization; caller must ensure thread safety
 
 ## Performance Characteristics
 
 - **Time Complexity**: O(1) average case for get/set operations
 - **Memory Efficiency**: Configurable capacity and memory limits
 - **Automatic Expiration**: Background cleanup of expired entries
 - **Eviction Policy**: Priority-based LRU eviction with memory limit enforcement
 
 ## Example Usage
 
 ```swift
 // Thread-synchronized cache with custom validation and memory limits
 let imageCache = MemoryCache<String, UIImage>(
     configuration: .init(
         enableThreadSynchronization: true,
         memoryUsageLimitation: .init(capacity: 1000, memory: 500), // 500MB limit
         defaultTTL: 3600, // 1 hour
         keyValidator: { $0.hasPrefix("https://") },
         costProvider: { image in
             guard let cgImage = image.cgImage else { return 0 }
             return cgImage.bytesPerRow * cgImage.height // Returns bytes
         }
     )
 )
 
 // Non-synchronized cache for single-threaded scenarios
 let fastCache = MemoryCache<String, Int>(
     configuration: .init(
         enableThreadSynchronization: false,
         memoryUsageLimitation: .init(capacity: 500, memory: 100)
     )
 )
 ```
 */

/// Represents memory and capacity constraints for the cache.
/// Used to configure cache limits for memory-sensitive or size-sensitive scenarios.
struct MemoryUsageLimitation {
    /// Maximum memory usage allowed (in MB).
    static let unlimitedMemoryUsage: Int = 1024 * 1024 * 1024 // In MB, approximately 1024TB
    
    /// Maximum number of items allowed in the cache.
    let capacity: Int
    /// Maximum memory usage allowed (in MB).
    let memory: Int
    
    /// Creates a new usage limitation with specified constraints.
    /// - Parameters:
    ///   - capacity: Maximum number of items (default: 1024)
    ///   - memory: Maximum memory usage in MB (default: unlimited)
    init(capacity: Int = 1024, memory: Int = Self.unlimitedMemoryUsage) {
        self.capacity = max(0, capacity)
        self.memory = min(max(0, memory), Self.unlimitedMemoryUsage)
    }
}

extension MemoryCache {
    // MARK: - Configuration
    
    /// Configuration options for the memory cache behavior and limits.
    struct Configuration {
        /// Whether to enable thread synchronization using NSLock (default: true)
        /// When true: All cache operations are synchronized for thread safety
        /// When false: No synchronization, caller must ensure thread safety
        let enableThreadSynchronization: Bool
        
        /// Memory and capacity constraints for the cache.
        let memoryUsageLimitation: MemoryUsageLimitation
        
        /// Default TTL for non-null values (in seconds).
        let defaultTTL: TimeInterval
        
        /// Default TTL for null values (in seconds).
        let defaultTTLForNullValue: TimeInterval
        
        /// Randomization range for TTL values to prevent cache stampede (in seconds).
        let ttlRandomizationRange: TimeInterval
        
        /// Key validation function that returns true for valid keys. Fixed at initialization.
        let keyValidator: (Key) -> Bool
        
        /// Function to calculate memory cost of elements in bytes.
        ///
        /// This closure is called for each element to determine its memory footprint for eviction decisions.
        /// The returned value should represent the actual memory usage in bytes.
        ///
        /// ## Usage Guidelines:
        /// - **For reference types (classes)**: Return the actual memory size (e.g., image data size, buffer length)
        /// - **For value types**: Can return 0 as memory layout is automatically calculated by the system
        /// - **For complex objects**: Sum up all contained data sizes (strings, arrays, etc.)
        /// - **For nil values**: Return 0 (handled automatically by the cache)
        ///
        /// ## Examples:
        /// ```swift
        /// // For UIImage: return actual image data size
        /// costProvider: { image in
        ///     guard let cgImage = image.cgImage else { return 0 }
        ///     return cgImage.bytesPerRow * cgImage.height
        /// }
        ///
        /// // For String: return character count (approximate)
        /// costProvider: { $0.count * 2 }
        ///
        /// // For Data: return actual byte count
        /// costProvider: { $0.count }
        ///
        /// // For complex objects: sum up all data
        /// costProvider: { obj in
        ///     return obj.stringData.count + obj.binaryData.count + obj.metadata.count
        /// }
        /// ```
        ///
        /// ## Important Notes:
        /// - The returned value should be **positive** and **reasonable** (avoid extremely large values)
        /// - Should be **consistent** for the same input (deterministic)
        /// - **Performance**: This closure is called frequently during eviction, so keep it fast
        /// - **Memory limit**: Total cost across all elements should not exceed `MemoryUsageLimitation.memory`
        /// - **Default behavior**: Returns 0 if not specified, relying on automatic memory layout calculation
        let costProvider: (Element) -> Int
        
        /// Creates a new configuration with specified parameters.
        /// - Parameters:
        ///   - enableThreadSynchronization: Enable NSLock synchronization for thread safety (default: true)
        ///   - memoryUsageLimitation: Memory and capacity constraints (default: unlimited)
        ///   - defaultTTL: Default TTL for non-nil values (default: .infinity)
        ///   - defaultTTLForNullValue: Default TTL for nil values (default: .infinity)
        ///   - ttlRandomizationRange: TTL randomization range (default: 0)
        ///   - keyValidator: Key validation closure (default: always true)
        ///   - costProvider: Memory cost calculation closure in bytes. Should return actual memory usage for accurate eviction decisions (default: returns 0)
        init(
            enableThreadSynchronization: Bool = true,
            memoryUsageLimitation: MemoryUsageLimitation = .init(),
            defaultTTL: TimeInterval = .infinity,
            defaultTTLForNullValue: TimeInterval = .infinity,
            ttlRandomizationRange: TimeInterval = 0,
            keyValidator: @escaping (Key) -> Bool = {_ in true},
            costProvider: @escaping (Element) -> Int = {_ in 0}
        ) {
            self.enableThreadSynchronization = enableThreadSynchronization
            self.defaultTTL = defaultTTL
            self.defaultTTLForNullValue = defaultTTLForNullValue
            self.ttlRandomizationRange = ttlRandomizationRange
            self.memoryUsageLimitation = memoryUsageLimitation
            self.keyValidator = keyValidator
            self.costProvider = costProvider
        }
        
        /// Default configuration (thread-synchronized with NSLock, unlimited size, no expiration, all keys valid)
        static var defaultConfig: Configuration { .init() }
    }
}

/// A high-performance, in-memory key-value cache with configurable thread safety and memory management.
/// 
/// This cache provides automatic expiration, priority-based eviction, and memory usage tracking.
/// It's designed for scenarios where you need fine-grained control over cache behavior and memory usage.
class MemoryCache<Key: Hashable, Element> {
    // MARK: - Initialization
    
    /// Creates a new memory cache with the specified configuration.
    /// - Parameter configuration: The configuration for this cache instance.
    init(configuration: Configuration = .defaultConfig, statisticsReport: ((CacheStatistics, CacheRecord) -> Void)? = nil) {
        self.configuration = configuration
        self.storageQueue = TTLPriorityLRUQueue(capacity: configuration.memoryUsageLimitation.capacity)
        self.statistics = .init(report: statisticsReport)
    }
    
    // MARK: - Properties
    
    /// NSLock for thread synchronization (used when enableThreadSynchronization=true)
    private let lock = NSLock()
    
    /// The configuration for this cache instance.
    private let configuration: Configuration
    
    /// The underlying TTL-priority-LRU queue for storage.
    private let storageQueue: TTLPriorityLRUQueue<Key, CacheEntry>
    
    /// Current total memory cost of all cached entries in bytes.
    private var totalCost: Int = 0
    
    private(set) var statistics: CacheStatistics
    
    /// Internal wrapper for cache entries to support null value caching.
    private struct CacheEntry {
        /// The actual value (can be nil for null caching).
        let value: Element?
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
    
    /// Returns true if the cache is at capacity.
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
     Inserts or updates a value for the given key with optional priority and expiration.
     
     This method handles both regular values and null values, applying appropriate TTL settings
     and memory cost tracking. When the cache exceeds its memory limit, it automatically
     evicts the least recently used entries.
     
     - Parameters:
       - value: The value to store (can be nil for null caching)
       - key: The key to associate with the value
       - priority: The priority for eviction (higher is less likely to be evicted)
       - duration: The TTL (in seconds) for the entry. Defaults to configuration default
     
     - Returns: Array of evicted values due to capacity or memory limits
     
     - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
    @discardableResult
    func set(
        value: Element?,
        for key: Key,
        priority: Double = .zero,
        expiredIn duration: TimeInterval? = nil
    ) -> [Element] {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        
        // Step 1: Validate key using external validator
        guard configuration.keyValidator(key) else { return [] }
        
        var evictedValues: [Element] = []
        
        // Step 2: Handle null value caching
        if value == nil {
            let finalTTL = calculateFinalTTL(
                originalDuration: duration ?? configuration.defaultTTLForNullValue,
                isNullValue: true
            )
            
            let cacheEntry = CacheEntry(value: nil)
            let evictedEntry = storageQueue.set(
                value: cacheEntry,
                for: key,
                priority: priority,
                expiredIn: finalTTL
            )
            
            // Handle evicted entry from storage queue
            if let evictedValue = evictedEntry?.value {
                decreaseCost(for: evictedValue)
                evictedValues.append(evictedValue)
            }
            
            // Null values have minimal cost, but we still track them
            increaseCost(for: nil)
            
            return evictedValues
        }
        
        if cost(of: value) > configuration.memoryUsageLimitation.memory * 1024 * 1024 {
            if let value {
                return [value]
            }else {
                return []
            }
        }
        
        // Step 3: Calculate final TTL with randomization
        let finalTTL = calculateFinalTTL(
            originalDuration: duration ?? configuration.defaultTTL,
            isNullValue: false
        )
        
        // Step 4: Store in queue and handle evictions
        let cacheEntry = CacheEntry(value: value)
        let evictedEntry = storageQueue.set(
            value: cacheEntry,
            for: key,
            priority: priority,
            expiredIn: finalTTL
        )
        
        // Handle evicted entry from storage queue
        if let evictedValue = evictedEntry?.value {
            decreaseCost(for: evictedValue)
            evictedValues.append(evictedValue)
        }
        
        // Add cost for new entry
        increaseCost(for: value)
        
        // Step 5: Check memory limits and evict if necessary
        let memoryLimitInBytes = configuration.memoryUsageLimitation.memory * 1024 * 1024 // Convert MB to bytes
        while totalCost > memoryLimitInBytes {
            // Get the least recently used entry to evict
            if let evictedValue = storageQueue.removeValue()?.value {
                decreaseCost(for: evictedValue)
                evictedValues.append(evictedValue)
            } else {
                // If no more entries to evict, break to avoid infinite loop
                break
            }
        }
        
        return evictedValues
    }
    
    
    enum FetchResult {
        case invalidKey
        case hitNullValue
        case hitNonNullValue(value: Element)
        case miss
        
        var value: Element? {
            switch self {
            case .hitNonNullValue(let value):
                return value
            default:
                return nil
            }
        }
        
        var isMiss: Bool {
            switch self {
            case .miss:
                return true
            default:
                return false
            }
        }
    }
    /**
     Retrieves the value for the given key if present and not expired.
     
     This method validates the key using the configured validator and returns the value
     if it exists and hasn't expired. The access updates the LRU order of the entry.
     
     - Parameter key: The key to look up
     - Returns: The value if present and valid, or nil if expired, missing, or invalid
     
     - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
    func getValue(for key: Key) -> FetchResult {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        
        guard configuration.keyValidator(key) else {
            statistics.record(.invalidKey)
            return .invalidKey
        }
        
        let cacheEntry = storageQueue.getValue(for: key)
        
        guard let cacheEntry else {
            statistics.record(.miss)
            return .miss
        }
        
        guard let value = cacheEntry.value else {
            statistics.record(.hitNullValue)
            return .hitNullValue
        }
        
        statistics.record(.hitNonNullValue)
        return .hitNonNullValue(value: value)
    }
    
    /**
     Removes the value for the given key, if present.
     
     This method removes the entry from the cache and updates the memory cost tracking.
     The removed value is returned if it existed in the cache.
     
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
    
    /**
     Removes and returns the least recently used value from the cache.
     
     This method removes the least recently used entry from the cache and returns its value.
     The removal follows the cache's eviction policy (priority-based LRU).
     
     - Returns: The removed value, or nil if the cache is empty
     
     - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
    @discardableResult
    func removeValue() -> Element? {
       acquireLockIfNeeded()
       defer { releaseLockIfNeeded() }
       
       let cacheEntry = storageQueue.removeValue()
       return cacheEntry?.value
   }
    
    /**
     Removes all expired values from the cache.
     
     This method iterates through the cache and removes all entries that have expired
     based on their TTL (Time-to-Live) settings. This is useful for periodic cleanup
     to free up memory and maintain cache efficiency.
     
     - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
    func removeExpiredValues() {
        acquireLockIfNeeded()
        defer { releaseLockIfNeeded() }
        
        storageQueue.removeExpiredValues()
    }
    
    /**
     Removes cache entries to reduce the cache size to a specified percentage of its current size.
     
     This method first removes all expired values, then continues removing the least recently used
     entries until the cache size reaches the specified percentage of its original size.
     
     - Parameter toPercent: The target percentage (0.0 to 1.0) of current cache size to retain
     
     - Note: Thread safety depends on the `enableThreadSynchronization` configuration option
     */
    func removeValues(toPercent: Double) {
        let percent = max(0, min(toPercent, 1))
        let restCount = Int(percent * Double(storageQueue.count))
        storageQueue.removeExpiredValues()
        while storageQueue.count > restCount {
            removeValue()
        }
    }
    
    func resetStatistics() {
        statistics.reset()
    }
}

// MARK: - Private Implementation

private extension MemoryCache {
    /// Calculates the final TTL with randomization applied to prevent cache stampede.
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
    
    /// Increases the total memory cost by the cost of the given value.
    /// - Parameter value: The value whose cost should be added
    func increaseCost(for value: Element?) {
        totalCost += cost(of: value)
    }
    
    /// Decreases the total memory cost by the cost of the given value.
    /// - Parameter value: The value whose cost should be subtracted
    func decreaseCost(for value: Element?) {
        totalCost = max(0, totalCost - cost(of: value))
    }
    
    /// Calculates the memory cost of a value in bytes.
    /// - Parameter value: The value to calculate cost for
    /// - Returns: The memory cost in bytes
    func cost(of value: Element?) -> Int {
        guard let value else { return 0 }
        return MemoryLayout<Element>.size + min(max(0, configuration.costProvider(value)), MemoryUsageLimitation.unlimitedMemoryUsage)
    }
}
