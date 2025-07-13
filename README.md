# Monstore

A Swift package providing efficient memory caching utilities with LRU (Least Recently Used) eviction strategy.

## Features

- **LRUQueue**: High-performance LRU cache implementation with optimized doubly-linked list
- **LRUQueueWithTTL**: LRU cache with time-to-live (TTL) support
- **MemoryCache**: Core memory caching functionality
- **Heap**: Efficient heap data structure implementation
- **CPUTimeStamp**: High-precision CPU timestamp utilities

## LRUQueue

A fast and memory-efficient LRU (Least Recently Used) cache implementation.

### Key Features

- **O(1) operations**: Constant time complexity for get, set, and remove operations
- **Memory efficient**: Uses object pooling to reduce allocations
- **Thread-safe**: Safe for concurrent access
- **Predictable eviction**: Strict LRU eviction order
- **Type-safe**: Generic implementation supporting any Hashable key and value types

### Usage

```swift
import Monstore

// Create an LRU cache with capacity 100
let cache = LRUQueue<String, Int>(capacity: 100)

// Set values
cache.setValue(42, for: "answer")
cache.setValue(100, for: "score")

// Get values
let answer = cache.getValue(for: "answer") // Returns 42

// Remove values
let removed = cache.removeValue(for: "score") // Returns 100

// Check status
print(cache.count) // Current number of items
print(cache.isEmpty) // Whether cache is empty
print(cache.isFull) // Whether cache is at capacity
```

### Performance Characteristics

- **Insert/Update**: O(1) average case
- **Retrieve**: O(1) average case  
- **Remove**: O(1) average case
- **Memory**: O(n) where n is capacity
- **Eviction**: O(1) when capacity is exceeded

## LRUQueueWithTTL

An LRU cache with automatic expiration based on time-to-live (TTL).

### Usage

```swift
import Monstore

// Create TTL cache with 5 second expiration
let ttlCache = LRUQueueWithTTL<String, Int>(capacity: 100, ttl: 5.0)

// Set value with TTL
ttlCache.setValue(42, for: "answer")

// Get value (returns nil if expired)
let answer = ttlCache.getValue(for: "answer")

// Wait for expiration...
Thread.sleep(forTimeInterval: 6.0)
let expired = ttlCache.getValue(for: "answer") // Returns nil
```

## Installation

### Swift Package Manager

Add Monstore to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Monstore.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version you want to use

## Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 5.0+

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 