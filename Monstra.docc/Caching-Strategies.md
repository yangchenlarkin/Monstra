# Caching Strategies

Learn about different caching strategies and patterns available in Monstra for optimal performance.

## Overview

Monstra provides multiple caching components designed for different use cases. Understanding when to use each component helps you build efficient applications.

## MemoryCache Strategies

### Basic Caching Pattern

```swift
import Monstra

// Simple caching for frequently accessed data
let userCache = MemoryCache<String, User>()

func getUser(id: String) async -> User? {
    // Check cache first
    switch userCache.getElement(for: id) {
    case .hitNonNullElement(let user):
        return user
    case .hitNullElement:
        return nil // User doesn't exist, cached null
    case .miss, .invalidKey:
        // Cache miss, fetch from network
        let user = await fetchUserFromNetwork(id: id)
        userCache.set(element: user, for: id, expiredIn: 3600) // 1 hour TTL
        return user
    }
}
```

### Advanced Configuration

```swift
// High-performance image cache with memory limits
let imageCache = MemoryCache<String, UIImage>(
    configuration: .init(
        enableThreadSynchronization: true,
        memoryUsageLimitation: .init(capacity: 1000, memory: 500), // 500MB
        defaultTTL: 3600, // 1 hour
        ttlRandomizationRange: 60, // Prevent stampede
        keyValidator: { $0.hasPrefix("https://") },
        costProvider: { image in
            // Calculate memory cost
            guard let cgImage = image.cgImage else { return 0 }
            return cgImage.bytesPerRow * cgImage.height
        }
    )
)
```

### Stampede Prevention

```swift
// Use TTL randomization to prevent cache stampede
let apiCache = MemoryCache<String, Data>(
    configuration: .init(
        defaultTTL: 300, // 5 minutes
        ttlRandomizationRange: 30, // ±30 seconds randomization
        defaultTTLForNullElement: 60 // 1 minute for null values
    )
)

// This prevents all cached items from expiring simultaneously
// when multiple instances access the same data
```

## MonoTask Caching

### Request Deduplication

```swift
import Monstra

// Network request deduplication
let networkTask = MonoTask<Data>(
    resultExpireDuration: 300, // 5 minutes cache
    retry: .count(count: 3, intervalProxy: .exponentialBackoff(
        initialTimeInterval: 1.0,
        scaleRate: 2.0
    ))
) { callback in
    // Expensive network operation
    performNetworkRequest(callback: callback)
}

// Multiple concurrent calls = single network request
Task {
    async let result1 = networkTask.asyncExecute() // Network call
    async let result2 = networkTask.asyncExecute() // Cached result
    async let result3 = networkTask.asyncExecute() // Cached result

    let results = await [result1, result2, result3]
    // All get the same result from single execution
}
```

### Force Update Pattern

```swift
// Force refresh when data might be stale
let profileTask = MonoTask<UserProfile>(
    resultExpireDuration: 1800 // 30 minutes
) { callback in
    fetchUserProfile(callback: callback)
}

// Normal execution uses cache
let cachedProfile = await profileTask.asyncExecute()

// Force update bypasses cache
let freshProfile = await profileTask.asyncExecute(forceUpdate: true)
```

## Task Manager Caching

### KVLightTasksManager Pattern

```swift
import Monstra

// Batch processing with caching
let userManager = KVLightTasksManager<[String: User?]> { (userIds, completion) in
    // Batch API call for multiple users
    Task {
        let users = await batchFetchUsers(ids: userIds)
        completion(.success(users))
    }
}

// Individual requests benefit from batch processing
userManager.fetch(key: "user-123") { _, result in
    // Handles single user request
}

userManager.fetch(keys: ["user-1", "user-2", "user-3"]) { id, result in
    // Batch request processed efficiently
}
```

### KVHeavyTasksManager Pattern

```swift
import Monstra

// Resource-intensive operations with progress
let downloadManager = KVHeavyTasksManager<URL, Data, DownloadEvent, DownloadProvider>()

// Progress tracking for large downloads
downloadManager.fetch(key: downloadURL) { url, result in
    switch result {
    case .success(let data):
        print("Downloaded \(data.count) bytes")
    case .failure(let error):
        print("Download failed: \(error)")
    }
} customEventObserver: { event in
    switch event {
    case .progress(let percent):
        print("Download progress: \(percent)%")
    case .started:
        print("Download started")
    case .completed:
        print("Download completed")
    }
}
```

## Choosing the Right Strategy

### Use MemoryCache When:
- **Simple key-value storage** with TTL expiration
- **Memory-constrained environments** needing capacity limits
- **Thread-safe caching** with configurable synchronization
- **Priority-based eviction** is required

### Use MonoTask When:
- **Single expensive operation** that benefits from deduplication
- **Network requests** or database queries
- **Retry logic** is needed for unreliable operations
- **Result caching** with TTL is required

### Use KVLightTasksManager When:
- **High-volume operations** with batching capabilities
- **Concurrent lightweight tasks** (images, API calls, etc.)
- **Key-based result caching** is needed
- **Peak shaving** for high-frequency operations

### Use KVHeavyTasksManager When:
- **Resource-intensive operations** (downloads, processing, ML)
- **Progress tracking** is required
- **Lifecycle management** (start/stop/resume) is needed
- **Large-scale concurrent operations** with limits

## Performance Considerations

### Memory Usage
- Configure appropriate capacity and memory limits
- Use cost providers for accurate memory tracking
- Consider null element caching to reduce repeated lookups

### Cache Invalidation
- Use appropriate TTL values based on data freshness requirements
- Implement force update patterns when cache invalidation is needed
- Consider cache stampede prevention for high-traffic scenarios

### Concurrency
- Choose appropriate synchronization modes for your use case
- Use execution merging to reduce redundant operations
- Consider queue management for callback delivery

## Best Practices

1. **Set appropriate TTL values** based on data freshness requirements
2. **Use cost providers** for accurate memory tracking in complex objects
3. **Enable TTL randomization** to prevent cache stampede in production
4. **Choose the right component** for your specific use case
5. **Monitor cache performance** and adjust configuration as needed
6. **Handle cache misses gracefully** with proper fallback logic
