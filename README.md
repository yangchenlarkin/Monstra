# Monstra

[![Swift](https://img.shields.io/badge/Swift-5.5-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg)](https://cocoapods.org)

A high-performance Swift framework providing efficient task execution, memory caching, and data management utilities with intelligent execution merging, TTL caching, and retry logic.

## 🚀 Features

### Monstore - Memory Caching System
- **⚡ High Performance**: O(1) time complexity for core operations
- **🧠 Memory Efficient**: Object pooling and optimized data structures
- **⏰ TTL Support**: Automatic expiration with time-to-live functionality
- **🛡️ Thread Safe**: Designed for concurrent access patterns
- **📊 Comprehensive Testing**: Extensive unit and performance tests
- **📈 Performance Benchmarked**: Detailed performance analysis and comparisons
- **🎯 Queue Management**: Separate queues for execution and callbacks
- **🔄 Cache Stampede Prevention**: TTL randomization prevents simultaneous cache expiration
- **💥 Avalanche Protection**: Intelligent eviction policies prevent memory overflow
- **🛡️ Breakdown Protection**: Priority-based LRU eviction with memory limit enforcement
- **🔒 Null Element Caching**: Support for caching null/nil elements with separate TTL
- **🎯 Priority-Based Eviction**: Higher priority entries retained longer during eviction
- **📏 Memory Usage Tracking**: Configurable memory limits with automatic eviction
- **🔍 External Key Validation**: Customizable key validation function at initialization
- **📊 Statistics & Monitoring**: Built-in cache statistics and performance metrics
- **⚙️ Configurable Thread Safety**: Optional DispatchSemaphore synchronization
- **🧹 Automatic Cleanup**: Background removal of expired elements
- **💾 Cost-Aware Storage**: Memory cost calculation for accurate eviction decisions

### Monstask - Task Execution Framework

#### **MonoTask - Single-Instance Task Executor**
- **🔄 Execution Merging**: Multiple concurrent requests merged into single execution
- **⏱️ TTL Caching**: Results cached for configurable duration with automatic expiration
- **🔄 Advanced Retry Logic**: Exponential backoff, fixed intervals, and hybrid retry strategies
- **🎯 Manual Cache Control**: Fine-grained cache invalidation with execution strategy options
- **🚀 Multiple Execution Patterns**: Callback-based, async/await, and fire-and-forget modes
- **🛡️ Thread Safety**: Fine-grained locking with semaphores for concurrent access
- **🔍 Execution State Management**: Track running tasks with cancellation and restart options
- **📱 Queue Separation**: Separate queues for task execution and callback invocation

#### **KVLightTasksManager - Lightweight Task Management**
- **⚡ High Performance**: Optimized for fast, lightweight operations
- **🎯 Priority-Based Scheduling**: LIFO/FIFO strategies with configurable limits
- **🔄 Batch Processing**: Support for single and batch data provisioning
- **📊 Concurrent Execution**: Configurable concurrent task limits (default: 4 running, 256 queued)
- **🔒 Key Validation**: Automatic filtering of invalid keys to prevent unnecessary operations
- **📈 Statistics & Monitoring**: Built-in cache statistics and performance metrics
- **🧹 Memory Management**: Automatic cleanup with configurable resource limits

#### **KVHeavyTasksManager - Heavy Task Coordination**
- **🏗️ Resource-Intensive Operations**: Such as large file downloads, video processing, ML inference with progress tracking
- **📊 Progress Tracking**: Real-time updates with custom event publishing and broadcasting
- **🎯 Priority-Based Scheduling**: LIFO/FIFO strategies with interruption support
- **🔄 Task Lifecycle Management**: Start/stop/resume with provider state preservation
- **🛡️ Error Handling & Recovery**: Graceful degradation with detailed error propagation
- **📱 Concurrent Control**: Limited concurrent execution (default: 2 running, 64 queued)
- **🧹 Memory Optimization**: Automatic cleanup with configurable resource limits
- **📈 Performance Monitoring**: Built-in performance tracking and optimization

## 🚀 Quick Start

### Installation

#### Swift Package Manager (Recommended)

Add Monstra to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "v0.0.5")
]
```

Or add it directly in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/yangchenlarkin/Monstra.git`
3. Select the version you want to use

#### CocoaPods

Add Monstra to your `Podfile`:

```ruby
pod 'Monstra', '~> 0.0.5'
```

**Note**: Monstra is published as a unified framework, so you get all components together.

## 💡 Simple Examples

### 1. MemoryCache
Basic caching operations with TTL and LRU eviction.

### 2. MonoTask  
Single-instance task execution with caching and retry logic.

```swift
import Monstra

// Create a task with caching and retry logic
let networkTask = MonoTask<Data>(
    retry: .count(count: 3, intervalProxy: .exponentialBackoff(initialTimeInterval: 1.0)),
    resultExpireDuration: 300.0 // 5 minutes cache
) { callback in
    // Your network request logic here
    let url = URL(string: "https://api.example.com/data")!
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            callback(.failure(error))
        } else if let data = data {
            callback(.success(data))
        }
    }.resume()
}

// Execute with async/await
let result1: Result<Data, Error> = await networkTask.asyncExecute()
switch result1 {
case .success(let data):
    print("Got data: \(data.count) bytes")
case .failure(let error):
    print("Error: \(error)")
}

// Multiple execution patterns - only one network request
// Note: All executions benefit from MonoTask's execution merging

do {
    let result2: Data = try await networkTask.executeThrows() // Second execution, returns cached result
    print("Result2: \(result2)")
} catch {
    print("Result2 error: \(error)")
}

networkTask.justExecute() // Fire-and-forget execution

// Callback-based execution for result3
networkTask.execute { result in
    switch result {
    case .success(let data):
        print("Result3 (callback): \(data.count) bytes")
    case .failure(let error):
        print("Result3 (callback) error: \(error)")
    }
}
```

### 3. KVLightTasksManager
Lightweight task management for high-frequency operations.

### 4. KVHeavyTasksManager
Heavy task coordination for resource-intensive operations.





## 🚀 Advanced Examples

### **🧠 MemoryCache - Caching Scenarios**
| Scenario | Best Practices | Example Link |
|----------|----------------|--------------|
| **Image Caching Strategy** | Efficient image caching with TTL and memory limits | [Image Caching Examples](docs/AdvancedUsage.md#image-caching-strategy) |
| **Search Result Caching** | Cache search results to improve user experience | [Search Caching Examples](docs/AdvancedUsage.md#search-result-caching) |
| **Database Query Caching** | Cache expensive database queries | [DB Query Examples](docs/AdvancedUsage.md#database-query-caching) |

### **⚡ MonoTask - Task Execution Scenarios**
| Scenario | Best Practices | Example Link |
|----------|----------------|--------------|
| **API Response Caching** | Cache API responses to reduce network calls | [API Caching Examples](docs/AdvancedUsage.md#api-response-caching) |
| **Configuration Management** | Cache app configuration with retry logic | [Config Management Examples](docs/AdvancedUsage.md#configuration-management) |

### **🚀 KVLightTasksManager - Light Task Scenarios**
| Scenario | Best Practices | Example Link |
|----------|----------------|--------------|
| **User Profile Fetching** | High-frequency user data operations | [User Profile Examples](docs/AdvancedUsage.md#user-profile-fetching) |
| **Real-time Data Streaming** | Streaming data with caching and deduplication | [Streaming Examples](docs/AdvancedUsage.md#real-time-data-streaming) |

### **🏗️ KVHeavyTasksManager - Heavy Task Scenarios**
| Scenario | Best Practices | Example Link |
|----------|----------------|--------------|
| **File Download Management** | Large file downloads with progress tracking | [File Download Examples](docs/AdvancedUsage.md#file-download-management) |
| **Video Processing Pipeline** | Multi-phase video processing with ML inference | [Video Processing Examples](docs/AdvancedUsage.md#video-processing-pipeline) |

*Note: All example links point to the Advanced Usage documentation (Coming Soon)*

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

## 📋 Requirements

### Platform Support
- **iOS**: 13.0+
- **macOS**: 10.15+
- **tvOS**: 13.0+
- **watchOS**: 6.0+

### Swift Version
- **Swift**: 5.5+

### Dependencies
- **Foundation**: Built-in (no external dependencies)
- **Alamofire**: Only for example executable (not required for core library)

## 🔧 Development

### Prerequisites

- Swift 5.5+
- Xcode 13+ (for iOS/macOS development)
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

## 🛡️ Key Advantages & Protection Mechanisms

### **Monstore Protection Features**

### **Cache Stampede Prevention**
Monstra prevents cache stampede attacks through TTL randomization. When multiple cache entries expire simultaneously, it can cause a sudden surge of requests to your backend. Monstra randomizes expiration times within a configurable range to distribute the load.

```swift
let cache = MemoryCache<String, Data>(
    configuration: .init(
        ttlRandomizationRange: 30.0 // ±30 seconds randomization
    )
)
```

### **Avalanche Protection**
Monstra protects against memory avalanches by implementing intelligent eviction policies. When memory usage approaches limits, the system automatically evicts the least valuable entries based on priority, recency, and expiration status.

```swift
let cache = MemoryCache<String, UIImage>(
    configuration: .init(
        memoryUsageLimitation: .init(
            capacity: 1000,    // Max 1000 images
            memory: 500        // Max 500MB
        )
    )
)
```

### **Breakdown Protection**
Monstra prevents cache breakdowns through priority-based LRU eviction. Critical data with higher priority is retained longer, while less important data is evicted first when capacity is reached.

```swift
// Set high priority for critical data
cache.set(element: userProfile, for: "user-123", priority: 10.0)

// Set low priority for temporary data
cache.set(element: searchResults, for: "search-query", priority: 1.0)
```

### **Null Element Caching**
Monstra supports caching null/nil elements with separate TTL configuration, preventing repeated database queries for non-existent data.

```swift
let cache = MemoryCache<String, User?>(
    configuration: .init(
        defaultTTL: 3600.0,           // Regular data: 1 hour
        defaultTTLForNullElement: 300.0  // Null data: 5 minutes
    )
)

// Cache both existing and non-existing users
cache.set(element: user, for: "user-123")      // Regular cache
cache.set(element: nil, for: "user-999")      // Null cache
```

### **Monstask Protection Features**

#### **MonoTask - Execution Merging & Deduplication**
MonoTask prevents duplicate work through intelligent execution merging. When multiple concurrent requests are made for the same task, only one execution occurs while all callbacks receive the same result.

```swift
let task = MonoTask<String>(resultExpireDuration: 60.0) { callback in
    // Expensive network call
    performExpensiveOperation(callback)
}

// Multiple concurrent calls - only one network request
Task {
    let result1 = await task.asyncExecute() // Network call happens
    let result2 = await task.asyncExecute() // Returns cached result
    let result3 = await task.asyncExecute() // Returns cached result
}
```

#### **MonoTask - Advanced Retry Strategies**
MonoTask provides sophisticated retry mechanisms with exponential backoff, fixed intervals, and hybrid approaches to handle transient failures gracefully.

```swift
// Exponential backoff with 3 retries
let retryTask = MonoTask<Data>(
    retry: .count(
        count: 3, 
        intervalProxy: .exponentialBackoff(
            initialTimeInterval: 1.0, 
            scaleRate: 2.0
        )
    ),
    resultExpireDuration: 300.0
) { callback in
    performNetworkRequest(callback)
}

// Fixed interval retry
let fixedRetryTask = MonoTask<Data>(
    retry: .count(
        count: 5, 
        intervalProxy: .fixed(timeInterval: 2.0)
    )
) { callback in
    performDatabaseQuery(callback)
}
```

#### **MonoTask - Execution State Management**
MonoTask provides fine-grained control over task execution states with cancellation, restart, and completion strategies.

```swift
// Cancel ongoing execution immediately
task.clearResult(ongoingExecutionStrategy: .cancel)

// Let execution complete, then restart
task.clearResult(ongoingExecutionStrategy: .restart)

// Let execution complete normally, just clear cache
task.clearResult(ongoingExecutionStrategy: .allowCompletion)

// Check if task is currently executing
if task.isExecuting {
    showLoadingSpinner()
} else {
    hideLoadingSpinner()
}
```

#### **MonoTask - Multiple Execution Patterns**
MonoTask supports various execution patterns to fit different use cases and coding styles.

```swift
// Async/await (recommended for modern Swift)
let result = await task.asyncExecute()
switch result {
case .success(let data):
    updateUI(with: data)
case .failure(let error):
    showErrorMessage(error)
}

// Callback-based (for legacy code integration)
task.execute { result in
    switch result {
    case .success(let data):
        updateUI(with: data)
    case .failure(let error):
        showErrorMessage(error)
    }
}

// Fire-and-forget (for pre-warming cache)
task.justExecute()
// Later, this will likely return cached result
let result = await task.asyncExecute()
```

#### **Task Managers - Priority-Based Scheduling**
KVLightTasksManager and KVHeavyTasksManager provide priority-based scheduling with LIFO/FIFO strategies for optimal resource utilization.

```swift
let lightManager = KVLightTasksManager<String, User>(
    config: .init(
        dataProvider: .asyncMonoprovide { key in
            try await API.fetchUser(id: key)
        },
        PriorityStrategy: .LIFO,  // Latest requests get priority
        maxNumberOfRunningTasks: 4,
        maxNumberOfQueueingTasks: 256
    )
)

let heavyManager = KVHeavyTasksManager<String, Video>(
    config: .init(
        dataProvider: .asyncMonoprovide { key in
            try await VideoProcessor.process(key)
        },
        PriorityStrategy: .FIFO,  // Fair processing order
        maxNumberOfRunningTasks: 2,  // Limited for heavy operations
        maxNumberOfQueueingTasks: 64
    )
)
```

### **Component Comparison & Use Cases**

| Component | Best For | Concurrent Tasks | Queue Size | Key Features |
|-----------|----------|------------------|------------|--------------|
| **MonoTask** | Single expensive operations | 1 (merged) | Unlimited | Execution merging, TTL caching, retry logic |
| **KVLightTasksManager** | Fast, lightweight operations | 4 running | 256 queued | Batch processing, key validation, high throughput |
| **KVHeavyTasksManager** | Resource-intensive operations | 2 running | 64 queued | Progress tracking, lifecycle management, error recovery |

#### **When to Use Each Component**

- **MonoTask**: API calls, database queries, expensive computations that benefit from caching and deduplication
- **KVLightTasksManager**: User profile fetching, search results, configuration loading, high-frequency operations
- **KVHeavyTasksManager**: File downloads, video processing, ML inference, long-running operations with progress updates

## 🎯 Typical Scenarios & Best Practices

### 1. **API Response Caching**
```swift
// Cache API responses to reduce network calls
let userProfileTask = MonoTask<UserProfile>(
    retry: .count(count: 2, intervalProxy: .fixed(interval: 1.0)),
    resultExpireDuration: 1800.0 // 30 minutes
) { callback in
    // API call logic
    apiClient.fetchUserProfile { result in
        callback(result)
    }
}

// Use in your view models
class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    
    func loadProfile() async {
        let result = await userProfileTask.asyncExecute()
        await MainActor.run {
            self.profile = try? result.get()
        }
    }
}
```

### 2. **Image Caching Strategy**
```swift
// Efficient image caching with TTL
let imageCache = MemoryCache<String, UIImage>(capacity: 200)

// Set with expiration
imageCache.setValue(image, for: imageURL.absoluteString)

// Automatic cleanup of expired images
imageCache.removeExpiredElements()
```

### 3. **Search Result Caching**
```swift
// Cache search results to improve UX
let searchTask = MonoTask<[SearchResult]>(
    retry: .count(count: 1, intervalProxy: .fixed(interval: 0.5)),
    resultExpireDuration: 300.0 // 5 minutes
) { callback in
    searchService.search(query: query) { results in
        callback(.success(results))
    }
}
```

### 4. **Configuration Management**
```swift
// Cache app configuration
let configTask = MonoTask<AppConfig>(
    retry: .count(count: 3, intervalProxy: .exponentialBackoff(initialTimeInterval: 2.0)),
    resultExpireDuration: 3600.0 // 1 hour
) { callback in
    configService.fetchConfig { config in
        callback(.success(config))
    }
}
```

### 5. **Database Query Caching**
```swift
// Cache expensive database queries
let queryCache = MemoryCache<String, [DatabaseRecord]>(capacity: 100)

// Use query hash as key
let queryHash = "SELECT * FROM users WHERE active = true"
if let cached = queryCache.getValue(for: queryHash) {
    return cached
}

// Execute query and cache result
let results = database.execute(query)
queryCache.setValue(results, for: queryHash)
return results
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
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`swift test`)
6. Run linting (`swiftlint lint Sources/`)
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Submit a pull request

### Code Style
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comprehensive documentation comments
- Ensure all public APIs have unit tests
- Maintain performance benchmarks

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🗺️ Roadmap

- [ ] Thread-safe variants
- [ ] Disk persistence support
- [ ] Compression algorithms
- [ ] Advanced eviction policies
- [ ] Metrics and monitoring
- [ ] SwiftUI integration examples

## 📖 Detailed Documentation

- **📚 API Reference**: [Full API Documentation](docs/API.md) *(Coming Soon)*
- **🔧 Advanced Usage**: [Advanced Patterns & Examples](docs/AdvancedUsage.md) *(Coming Soon)*
- **📊 Performance Guide**: [Performance Optimization](docs/Performance.md) *(Coming Soon)*
- **🏗️ Architecture**: [System Design & Architecture](docs/Architecture.md) *(Coming Soon)*

## 📞 Support

- 🐛 [Issue Tracker](https://github.com/yangchenlarkin/Monstra/issues)
- 💬 [Discussions](https://github.com/yangchenlarkin/Monstra/discussions)
- 📧 [Email Support](mailto:yangchenlarkin@gmail.com)

## 🙏 Acknowledgments

- Inspired by high-performance cache implementations
- Built with Swift's excellent type system and performance characteristics
- Tested extensively for production readiness
- Special thanks to the Swift community for feedback and contributions

---

**Made with ❤️ for the Swift community** 
