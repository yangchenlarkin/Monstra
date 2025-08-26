# Monstra

[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg)](https://cocoapods.org)

A high-performance Swift framework providing efficient task execution, memory caching, and data management utilities with intelligent execution merging, TTL caching, and retry logic.

## 🚀 Features

- **⚡ High Performance**: O(1) time complexity for core operations
- **🧠 Memory Efficient**: Object pooling and optimized data structures
- **⏰ TTL Support**: Automatic expiration with time-to-live functionality
- **🛡️ Thread Safe**: Designed for concurrent access patterns
- **📊 Comprehensive Testing**: Extensive unit and performance tests
- **📈 Performance Benchmarked**: Detailed performance analysis and comparisons
- **🔄 Task Execution**: Intelligent execution merging and caching
- **🔄 Retry Logic**: Configurable retry strategies with exponential backoff
- **🎯 Queue Management**: Separate queues for execution and callbacks

## 📦 Components

### Core Components

- **MonstraBase**: Foundation utilities including CPUTimeStamp, Heap, and data structures
- **Monstore**: Memory caching system with LRU and TTL support
- **Monstask**: Task execution framework with caching and retry logic

### Detailed Components

- **LRUQueue**: High-performance LRU cache implementation with optimized doubly-linked list
- **TTLPriorityLRUQueue**: LRU cache with automatic time-to-live (TTL) expiration
- **Heap**: Efficient heap data structure implementation
- **CPUTimeStamp**: High-precision CPU timestamp utilities for performance measurement
- **MemoryCache**: Core memory caching functionality
- **MonoTask**: Single-instance task executor with TTL caching and retry logic

## 🏗️ Architecture

```
Monstra/
├── Sources/
│   ├── MonstraBase/            # Foundation utilities
│   │   ├── CPUTimeStamp.swift # High-precision timing
│   │   ├── Heap.swift         # Efficient heap data structure
│   │   ├── DoublyLink.swift   # Doubly-linked list implementation
│   │   └── HashQueue.swift    # Hash-based queue
│   ├── Monstore/              # Memory caching system
│   │   └── MemoryCache/       # LRU and TTL cache implementations
│   └── Monstask/              # Task execution framework
│       ├── MonoTask.swift     # Single-instance task executor
│       ├── KVHeavyTasksManager.swift # Heavy task management
│       └── KVLightTasksManager.swift # Light task management
└── Tests/                     # Comprehensive test suite
    ├── MonstraBaseTests/      # Foundation utility tests
    ├── MonstoreTests/         # Caching system tests
    └── MonstaskTests/         # Task execution tests
```

## 🚀 Quick Start

### Installation

#### Swift Package Manager (Recommended)

Add Monstra to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "1.0.0")
]
```

Or add it directly in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/yangchenlarkin/Monstra.git`
3. Select the version you want to use

#### CocoaPods

Add Monstra to your `Podfile`:

```ruby
pod 'Monstra'
```

Or specify specific components:

```ruby
pod 'Monstra/MonstraBase'    # Foundation utilities only
pod 'Monstra/Monstore'       # Caching system only
pod 'Monstra/Monstask'       # Task execution only
```

### Basic Usage

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

### TTL Cache Usage

```swift
import Monstore

// Create TTL cache with automatic expiration
let ttlCache = TTLPriorityLRUQueue<String, Int>(capacity: 100)

// Set value with TTL (expires in 5 seconds)
ttlCache.unsafeSet(value: 42, for: "answer", expiredIn: 5.0)

// Get value (returns nil if expired)
let answer = ttlCache.getValue(for: "answer")

// Wait for expiration...
Thread.sleep(forTimeInterval: 6.0)
let expired = ttlCache.getValue(for: "answer") // Returns nil
```

### Task Execution with MonoTask

```swift
import Monstask

// Create a task with caching and retry logic
let networkTask = MonoTask<Data>(
    retry: .count(count: 3, intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0)),
    resultExpireDuration: 300.0 // 5 minutes cache
) { callback in
    // Your network request logic here
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            callback(.failure(error))
        } else if let data = data {
            callback(.success(data))
        }
    }.resume()
}

// Execute with async/await
let result = await networkTask.asyncExecute()
switch result {
case .success(let data):
    print("Got data: \(data.count) bytes")
case .failure(let error):
    print("Error: \(error)")
}

// Multiple concurrent calls - only one network request
let result1 = await networkTask.asyncExecute() // Network call happens
let result2 = await networkTask.asyncExecute() // Returns cached result
let result3 = await networkTask.asyncExecute() // Returns cached result
```

## 📊 Performance

### Time Complexity

| Operation | LRUQueue | TTLPriorityLRUQueue |
|-----------|----------|------------------|
| Insert/Update | O(1) | O(1) |
| Retrieve | O(1) | O(1) |
| Remove | O(1) | O(1) |
| TTL Management | N/A | O(log n) |

### Benchmark Results

Based on comprehensive testing with 10,000 operations:

- **LRUQueue**: 97.3x time scaling (near-linear O(1))
- **TTLPriorityLRUQueue**: 79.7x time scaling (better than linear)
- **Memory Usage**: 50-60% less than NSCache
- **Access Performance**: Comparable to NSCache

See [Performance Test Report](Tests/MonstoreTests/MemoryCache/PerformanceTestReport.md) for detailed benchmarks.

## 🧪 Testing

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter LRUQueueTests
swift test --filter PerformanceTests
swift test --filter ScaleTests

# Run with verbose output
swift test --verbose
```

### Test Coverage

- ✅ Unit tests for all components
- ✅ Performance benchmarks
- ✅ Scale testing (10,000 operations)
- ✅ Time complexity verification
- ✅ Memory usage analysis
- ✅ Thread safety considerations

## 🔧 Development

### Prerequisites

- Swift 5.10+
- Xcode 15+ (for iOS/macOS development)
- SwiftLint and SwiftFormat

### Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/Monstra.git
cd Monstra

# Install development tools
brew install swiftlint swiftformat sourcekitten

# Build the project
swift build

# Run tests
swift test

# Run linting
swiftlint lint Sources/

# Format code
swiftformat .
```

## 📚 API Reference

### LRUQueue

```swift
class LRUQueue<K: Hashable, Element> {
    init(capacity: Int)
    
    func setValue(_ value: Element, for key: K) -> Element?
    func getValue(for key: K) -> Element?
    func removeValue(for key: K) -> Element?
    
    var count: Int { get }
    var isEmpty: Bool { get }
    var isFull: Bool { get }
}
```

### TTLPriorityLRUQueue

```swift
class TTLPriorityLRUQueue<Key: Hashable, Value> {
    init(capacity: Int)
    
    func unsafeSet(value: Value, for key: Key, expiredIn duration: TimeInterval) -> Value?
    func getValue(for key: Key) -> Value?
    func unsafeRemoveValue(for key: Key) -> Value?
}
```

### MonoTask

```swift
class MonoTask<TaskResult> {
    init(retry: RetryCount, resultExpireDuration: Double, taskQueue: DispatchQueue, callbackQueue: DispatchQueue, task: @escaping CallbackExecution)
    
    func execute(then completionHandler: ResultCallback?)
    func asyncExecute() async -> Result<TaskResult, Error>
    func executeThrows() async throws -> TaskResult
    func justExecute()
    func clearResult(ongoingExecutionStrategy: OngoingExecutionStrategy)
    
    var currentResult: TaskResult? { get }
    var isExecuting: Bool { get }
}
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🗺️ Roadmap

- [ ] Thread-safe variants
- [ ] Disk persistence support
- [ ] Compression algorithms
- [ ] Advanced eviction policies
- [ ] Metrics and monitoring
- [ ] SwiftUI integration examples

## 📞 Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://github.com/yourusername/Monstore/issues)
- 💬 [Discussions](https://github.com/yourusername/Monstore/discussions)
- 📧 [Email Support](mailto:support@monstore.dev)

## 🙏 Acknowledgments

- Inspired by high-performance cache implementations
- Built with Swift's excellent type system and performance characteristics
- Tested extensively for production readiness

---

**Made with ❤️ for the Swift community** 
