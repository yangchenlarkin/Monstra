# MemoryCache

A high-performance, in-memory key-value cache with configurable thread safety and memory management for iOS and macOS applications.

## Overview

MemoryCache provides a comprehensive caching solution with advanced features including TTL (Time-to-Live) expiration, priority-based eviction, LRU (Least Recently Used) eviction, and null value caching support.

### Key Advantages

**TTL Randomization** prevents cache stampede and thundering herd problems by randomizing expiration times, ensuring that cached items don't expire simultaneously. This prevents multiple requests from hitting the backend simultaneously when cache entries expire, protecting your backend services from sudden traffic spikes.

**Null Value Caching** allows you to distinguish between cache misses and actual null values. This prevents repeated expensive operations for non-existent data, effectively implementing a "negative cache" that reduces backend load and improves response times for missing data.

**Memory Usage Tracking** provides fine-grained control over cache memory consumption with automatic eviction when limits are exceeded. This prevents memory leaks and ensures your app maintains optimal performance even under high memory pressure, making it suitable for memory-constrained environments like mobile devices.

**Performance Statistics** provides comprehensive cache performance monitoring with automatic tracking of hit rates, access patterns, and cache effectiveness. This enables data-driven optimization of cache strategies and helps identify performance bottlenecks in your application.

## Core Features

### Thread Safety
- **Synchronized Mode**: All operations are thread-safe using NSLock
- **Non-Synchronized Mode**: No synchronization; caller must ensure thread safety
- **Configurable**: Choose thread safety level based on your use case

### Caching Capabilities
- **TTL (Time-to-Live) Expiration**: Automatic cleanup of expired entries
- **Priority-Based Eviction**: Higher priority entries are retained longer during eviction
- **LRU (Least Recently Used) Eviction**: Within priority levels, least recently used entries are evicted first
- **Null Value Caching**: Support for caching null/nil values with separate TTL configuration
- **External Key Validation**: Customizable key validation function set at initialization
- **TTL Randomization**: Prevents cache stampede by randomizing expiration times
- **Memory Usage Tracking**: Configurable memory limits with automatic eviction
- **Performance Statistics**: Comprehensive cache performance monitoring with hit rate tracking

### Performance Characteristics
- **Time Complexity**: O(1) average case for get/set operations
- **Memory Efficiency**: Configurable capacity and memory limits
- **Automatic Expiration**: Background cleanup of expired entries
- **Eviction Policy**: Priority-based LRU eviction with memory limit enforcement

## Components

### MemoryCache
The main caching class that provides:
- Thread-safe get/set operations with optional NSLock synchronization
- TTL-based expiration with randomization support
- Memory cost tracking with customizable cost calculation
- Priority and LRU eviction strategies
- Null value caching with separate TTL configuration
- External key validation
- Memory limit enforcement with automatic eviction
- Performance statistics tracking with hit rate and success rate calculation

### TTLPriorityLRUQueue
A cache that combines TTL, priority, and LRU eviction policies:
- Each entry has an expiration time (TTL), a priority, and is tracked for recency
- When the cache is full, expired entries are evicted first, then lower-priority entries, then least recently used
- Provides O(1) average case for access and update by key
- Efficient expiration and eviction with background cleanup

### PriorityLRUQueue
A priority-based LRU queue that maintains separate LRU queues for each priority level:
- Elements with lower priority are evicted first
- Within the same priority, least recently used elements are evicted first
- Provides O(1) average case for access, update, and removal by key
- Efficient doubly-linked list implementation for LRU tracking

### Heap
A generic heap (priority queue) supporting custom ordering and capacity limits:
- Supports both min and max heap configurations
- Custom comparison functions for flexible ordering
- Event callbacks for insert, remove, and index changes
- Efficient O(log n) insert and remove operations

### CPUTimeStamp
High-precision CPU timestamp for accurate time measurements:
- Nanosecond-level precision using mach timebase
- Supports arithmetic and comparison for time intervals
- Used for cache expiration logic and performance measurement
- Efficient conversion between CPU ticks and seconds

## Usage

### Basic Usage
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

### Advanced Configuration
```swift
let config = MemoryCache.Configuration(
    enableThreadSynchronization: true,
    memoryUsageLimitation: .init(capacity: 1000, memory: 100), // 100MB limit
    defaultTTL: 1800, // 30 minutes
    defaultTTLForNullValue: 300, // 5 minutes for null values
    ttlRandomizationRange: 60, // ±60 seconds randomization
    keyValidator: { key in
        // Custom key validation logic
        return key.count > 0 && key.count < 100
    },
    costProvider: { element in
        // Custom memory cost calculation
        return MemoryLayout.size(ofValue: element)
    }
)
```

### Cache Operations
```swift
// Set values with optional priority and TTL
let evictedValues = cache.set(
    value: imageData,
    for: "image_key",
    priority: 1.0, // Higher priority = less likely to be evicted
    expiredIn: 3600 // 1 hour TTL
)

// Get values (automatically updates LRU order)
let value = cache.getValue(for: "image_key")

// Remove specific values
let removedValue = cache.removeValue(for: "image_key")

// Check cache status
let isEmpty = cache.isEmpty
let count = cache.count
let capacity = cache.capacity

// Access cache statistics
let stats = cache.statistics
print("Hit rate: \(stats.hitRate)")
print("Success rate: \(stats.successRate)")
print("Total accesses: \(stats.totalAccesses)")
```
```

## Memory Cost Calculation

The `costProvider` closure is crucial for accurate memory management:

```swift
// For UIImage: return actual image data size
costProvider: { image in
    guard let cgImage = image.cgImage else { return 0 }
    return cgImage.bytesPerRow * cgImage.height
}

// For String: return character count (approximate)
costProvider: { $0.count * 2 }

// For Data: return actual byte count
costProvider: { $0.count }

// For complex objects: sum up all data
costProvider: { obj in
    return obj.stringData.count + obj.binaryData.count + obj.metadata.count
}
```

### Cache Statistics

MemoryCache provides comprehensive performance monitoring with automatic statistics tracking:

```swift
// Create cache with statistics reporting
let cache = MemoryCache<String, Data>(
    configuration: .init(),
    statisticsReport: { stats, result in
        print("Cache operation: \(result), Hit rate: \(stats.hitRate)")
    }
)

// Perform cache operations
cache.set(value: data, for: "key1")
_ = cache.getValue(for: "key1")  // hit
_ = cache.getValue(for: "key2")  // miss

// Access statistics
let stats = cache.statistics
print("Hit rate: \(stats.hitRate)")           // 0.5 (1 hit / 2 valid accesses)
print("Success rate: \(stats.successRate)")   // 0.5 (1 hit / 2 total accesses)
print("Invalid keys: \(stats.invalidKeyCount)")
print("Null value hits: \(stats.nullValueHitCount)")
print("Non-null value hits: \(stats.nonNullValueHitCount)")
print("Misses: \(stats.missCount)")

// Reset statistics for performance testing
cache.resetStatistics()
```
```

## Performance

- **High throughput**: Optimized for high-frequency cache operations
- **Low memory overhead**: Efficient data structures and memory management
- **Thread safety**: Optional synchronization with minimal performance impact
- **Automatic cleanup**: Background expiration and eviction
- **Memory limit enforcement**: Automatic eviction when memory limits are exceeded

## Requirements

- iOS 12.0+ / macOS 10.14+
- Swift 5.0+
- Xcode 12.0+

## Installation

Add MemoryCache to your project dependencies and import the module:

```swift
import Monstore
```

## License

This library is part of the Monstra framework. See the main LICENSE file for details. 