<div align="center">
  <img src="Logo.png" alt="Monstra Logo" width="50%">
</div>

[![Swift](https://img.shields.io/badge/Swift-5.5-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg)](https://cocoapods.org)

A high-performance Swift framework providing efficient task execution, memory caching, and data management utilities with intelligent execution merging, TTL caching, and retry logic.

## 🚀 Features

### Monstore - Caching System

#### MemoryCache
- **⏰ TTL & Priority Support**: Advanced time-to-live functionality with automatic expiration and configurable priority-based eviction
- **💥 Avalanche Protection**: Intelligent TTL randomization prevents cache stampede and simultaneous expiration cascades
- **🛡️ Breakdown Protection**: Comprehensive null value caching and robust key validation for enhanced reliability
- **📊 Statistics & Monitoring**: Built-in cache statistics, performance metrics, and real-time monitoring capabilities

### Monstask - Task Execution Framework

#### **MonoTask**

- **🔄 Execution Merging**: Multiple concurrent requests merged into single execution
- **⏱️ TTL Caching**: Results cached for configurable duration with automatic expiration
- **🔄 Advanced Retry Logic**: Exponential backoff, fixed intervals, and hybrid retry strategies
- **🎯 Manual Cache Control**: Fine-grained cache invalidation with execution strategy options

#### **KVLightTasksManager**
- **📈 Peak Shaving**: Prevents excessive task execution volume through Priority-Based Scheduling (LIFO/FIFO strategies with configurable limits)
- **🔄 Batch Processing**: Support for single and batch data provisioning to enhance backend execution efficiency
- **📊 Concurrent Execution**: Configurable concurrent task limits (default: 4 running, 256 queued)
- **🎯 Execution Merging**: Intelligent request deduplication and merging to prevent duplicate work and optimize resource usage
- **💾 Result Caching**: Integrated MemoryCache for optimized performance

#### **KVHeavyTasksManager**
- **📊 Progress Tracking**: Real-time progress updates with custom event publishing and broadcasting capabilities
- **🎯 Priority-Based Scheduling**: Advanced LIFO/FIFO strategies with intelligent interruption support
- **🔄 Task Lifecycle Management**: Complete start/stop/resume functionality with provider state preservation
- **📱 Concurrent Control**: Optimized concurrent execution limits (default: 2 running, 64 queued)
- **🎯 Execution Merging**: Intelligent request deduplication and merging to prevent duplicate work and optimize resource usage
- **💾 Result Caching**: Integrated MemoryCache for enhanced performance and efficiency

## 🚀 Quick Start

### Installation

#### Swift Package Manager (Recommended)

Add Monstra to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "0.0.5")
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

## 🎯 When to Use Each Component

| Component | Best For | Key Features |
|-----------|----------|-------------|
| **MonoTask** | Single expensive operations | Execution merging, TTL caching, retry logic |
| **KVLightTasksManager** | Fast, lightweight operations | Batch processing, key validation, high throughput |
| **KVHeavyTasksManager** | Resource-intensive operations | Progress tracking, lifecycle management, error recovery |

#### **Some Scenarios for Each Component**

- **MonoTask**: API calls, database queries, expensive computations that benefit from caching and deduplication
- **KVLightTasksManager**: User profile fetching, search results, configuration loading, high-frequency operations
- **KVHeavyTasksManager**: File downloads, video processing, ML inference, long-running operations with progress updates

## 💡 Simple Examples

### 1. MemoryCache
Basic caching operations with TTL, priority-based and LRU eviction.

**Simple Example (Default Configuration):**
```swift
import Monstra

// Create a basic cache with default configuration
let cache = MemoryCache<String, Int>()

// Set values with different priorities and TTL
cache.set(element: 42, for: "answer", priority: 10.0, expiredIn: 3600.0) // 1 hour, high priority
cache.set(element: 100, for: "score", priority: 1.0) // Default TTL, low priority
cache.set(element: nil, for: "user-999") // Cache null value

// Get values using the FetchResult enum
switch cache.getElement(for: "answer") {
case .hitNonNullElement(let value):
    print("Found answer: \(value)")
case .hitNullElement:
    print("Found null value")
case .miss:
    print("Key not found or expired")
case .invalidKey:
    print("Invalid key")
}

// Check cache status
print("Cache count: \(cache.count)")
print("Cache capacity: \(cache.capacity)")
print("Is empty: \(cache.isEmpty)")
print("Is full: \(cache.isFull)")

// Remove specific element
let removed = cache.removeElement(for: "score")
print("Removed: \(removed ?? -1)")

// Clean up expired elements
cache.removeExpiredElements()
```

**Detailed Configuration Example:**
```swift
// Advanced configuration with all options
let imageCache = MemoryCache<String, Data>(
    configuration: .init(
        // Thread Safety: Enable DispatchSemaphore synchronization for concurrent access
        enableThreadSynchronization: true,
        
        // Memory & Capacity Limits: Maximum 100 items, 50MB memory usage
        memoryUsageLimitation: .init(
            capacity: 100,    // Maximum number of cached items
            memory: 50        // Maximum memory usage in MB
        ),
        
        // TTL Settings: How long items stay in cache
        defaultTTL: 1800.0,              // 30 minutes for regular elements
        defaultTTLForNullElement: 300.0, // 5 minutes for null/nil elements
        
        // Cache Stampede Prevention: Randomize TTL by ±30 seconds
        ttlRandomizationRange: 30.0,     // Prevents all items expiring simultaneously
        
        // Key Validation: Only accept keys starting with "img_"
        keyValidator: { key in
            return key.hasPrefix("img_")  // Custom validation logic
        },
        
        // Memory Cost Calculation: Use actual data size for eviction decisions
        costProvider: { data in
            return data.count             // Return size in bytes
        }
    )
)
```

### 2. MonoTask  
**Single Task Execution & Merging**: Handles individual task execution, request merging and result cache, such as module initialization, configuration file reading, and API call consolidation with result caching (e.g., UserProfile, e-commerce Cart operations)

**Simple Example (Default Configuration):**
```swift
import Monstra

// Create a basic task with minimal configuration
let networkTask = MonoTask<Data> { callback in
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

// Alternatively, you can use an asynchornic block to create MonoTask

// Multiple execution patterns - only one network request
// Note: All executions benefit from MonoTask's execution merging

// Execute with async/await
let result1: Result<Data, Error> = await networkTask.asyncExecute()
switch result1 {
case .success(let data):
    print("Got data: \(data.count) bytes")
case .failure(let error):
    print("Error: \(error)")
}

// Execute with async/await and try/catch
do {
    let result2: Data = try await networkTask.executeThrows() // Second execution, returns cached result
    print("Result2: \(result2)")
} catch {
    print("Result2 error: \(error)")
}

 // Fire-and-forget execution
networkTask.justExecute()

// Callback-based execution
networkTask.execute { result in
    switch result {
    case .success(let data):
        print("Result3 (callback): \(data.count) bytes")
    case .failure(let error):
        print("Result3 (callback) error: \(error)")
    }
}
```

**Detailed Configuration Example:**
```swift
// Advanced configuration with custom retry and queue settings
let fileProcessor1 = MonoTask<ProcessedData>(
    retry: 3,  // Simple retry count configuration
    
    // Result Caching: Use default cache configuration
    resultExpireDuration: 300.0,      // 5 minutes cache duration
    
    // Task Queue: Custom dispatch queue for task execution
    taskQueue: DispatchQueue.global(qos: .utility),  // Background priority queue
    
    // Callback Queue: Custom dispatch queue for callbacks
    callbackQueue: DispatchQueue.global(qos: .userInitiated)  // High priority queue
) { callback in
    // Your file processing logic here
    let filePath = "/path/to/large/file.txt"
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let processedData = ProcessedData(content: data, metadata: ["size": data.count])
        callback(.success(processedData))
    } catch {
        callback(.failure(error))
    }
}
// Advanced configuration with custom retry and queue settings
let fileProcessor2 = MonoTask<ProcessedData>(
    // Retry Strategy: Exponential backoff with 3 attempts
    retry: .count(
        count: 3,    // Maximum retry attempts
        intervalProxy: .exponentialBackoff(
            initialTimeInterval: 1.0,  // Start with 1 second delay
            scaleRate: 2.0             // Double the delay each retry
        )
    ),
    
    // Result Caching: Use default cache configuration
    resultExpireDuration: 300.0,      // 5 minutes cache duration
    
    // Task Queue: Custom dispatch queue for task execution
    taskQueue: DispatchQueue.global(qos: .utility),  // Background priority queue
    
    // Callback Queue: Custom dispatch queue for callbacks
    callbackQueue: DispatchQueue.global(qos: .userInitiated)  // High priority queue
) { callback in
    // Your file processing logic here
    let filePath = "/path/to/large/file.txt"
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let processedData = ProcessedData(content: data, metadata: ["size": data.count])
        callback(.success(processedData))
    } catch {
        callback(.failure(error))
    }
}
```

**Async Task Block Example:**
```swift
// Async/await initialization with modern Swift concurrency
let unzipTask = MonoTask<[String]>(
    // Retry Strategy: Fixed interval retry for file operations
    retry: .count(
        count: 2,    // Retry twice for file system issues
        intervalProxy: .fixed(timeInterval: 1.0)  // Wait 1 second between retries
    ),
    
    // Result Caching: Cache unzipped file list for 10 minutes
    resultExpireDuration: 600.0,      // 10 minutes cache duration
    
    // Task Queue: Background queue for file operations
    taskQueue: DispatchQueue.global(qos: .utility),
    
    // Callback Queue: Main queue for UI updates
    callbackQueue: DispatchQueue.main
) {
    // Async task block that returns Result directly
    do {
        let archivePath = "/path/to/archive.zip"
        let extractPath = "/path/to/extract/"
        
        // Simulate async unzip operation
        let extractedFiles = try await unzipArchive(at: archivePath, to: extractPath)
        return .success(extractedFiles)
    } catch {
        return .failure(error)
    }
}

// Usage with async/await
let extractedFiles = try await unzipTask.executeThrows()
print("Extracted \(extractedFiles.count) files")
```

### 3. KVLightTasksManager
**High-Volume Task Execution**: Handles high-volume operations with peak shaving, such as image downloads, local database batch reads, map tile downloads and cache warming operations

**Simple Example (Default Configuration):**
```swift
import Monstra

// Create a lightweight tasks manager for handling image downloads
let imageTaskManager = KVLightTasksManager<UIImage> { (imageURL: URL, completion: @escaping (Result<UIImage?, Error>) -> Void) in
    // Simple image download task
    URLSession.shared.dataTask(with: imageURL) { data, response, error in
        if let error = error {
            completion(.failure(error))
        } else if let data = data, let image = UIImage(data: data) {
            completion(.success(image))
        } else {
            completion(.failure(NSError(domain: "ImageError", code: -1, userInfo: nil)))
        }
    }.resume()
}

// Fetch multiple images
let imageURLs = [
    "https://example.com/image1.jpg",
    "https://example.com/image2.jpg", 
    "https://example.com/image3.jpg"
].compactMap { URL(string: $0) }

// Fetch images individually
for (index, url) in imageURLs.enumerated() {
    imageTaskManager.fetch(key: url) { key, result in
        switch result {
        case .success(let image):
            if let image = image {
                print("Image \(index + 1) downloaded successfully: \(image.size)")
            } else {
                print("Image \(index + 1) returned nil")
            }
        case .failure(let error):
            print("Image \(index + 1) failed: \(error)")
        }
    }
}

// Fetch multiple images at once with batch callback
imageTaskManager.fetch(keys: imageURLs) { key, result in
    switch result {
    case .success(let image):
        if let image = image {
            print("Image downloaded: \(image.size)")
        } else {
            print("Image returned nil")
        }
    case .failure(let error):
        print("Image failed: \(error)")
    }
}
```

**Batch Processing Example:**
```swift
// Create a manager for batch fetching user profile data
let userProfileManager = KVLightTasksManager<[String: UserProfile?]> { (userIDs: [String], completion: @escaping (Result<[String: UserProfile?], Error>) -> Void) in
    // Simulate batch API call to fetch multiple user profiles
    DispatchQueue.global(qos: .utility).async {
        // Simulate network delay
        Thread.sleep(forTimeInterval: 0.1)
        
        var profiles: [String: UserProfile?] = [:]
        
        // Simulate batch API response
        for userID in userIDs {
            let profile = UserProfile(
                id: userID,
                name: "User \(userID)",
                email: "user\(userID)@example.com",
                avatar: "https://example.com/avatars/\(userID).jpg"
            )
            profiles[userID] = profile
        }
        
        completion(.success(profiles))
    }
}

// Fetch multiple user profiles in a single batch
let userIDs = ["user1", "user2", "user3"]

// Using batch callback for all results at once
userProfileManager.fetch(keys: userIDs, multiCallback: { results in
    print("Batch loaded \(results.count) users:")
    for (userID, result) in results {
        switch result {
        case .success(let profile):
            if let profile = profile {
                print("  ✓ \(profile.name) (\(profile.email))")
            } else {
                print("  - \(userID): No profile found")
            }
        case .failure(let error):
            print("  ✗ \(userID): \(error)")
        }
    }
})

// Using individual callbacks for each user (still benefits from batch processing)
userProfileManager.fetch(keys: userIDs) { userID, result in
    switch result {
    case .success(let profile):
        if let profile = profile {
            print("Individual: \(profile.name) loaded")
        } else {
            print("Individual: \(userID) - No profile found")
        }
    case .failure(let error):
        print("Individual: \(userID) - \(error)")
    }
}
```

**Advanced Configuration Example:**
```swift
// Create a manager with custom configuration for image downloads
let imageManager = KVLightTasksManager<UIImage>(
    config: .init(
        dataProvider: .multiprovide(maximumBatchCount: 4) { (imageURLs: [String], completion: @escaping (Result<[String: UIImage?], Error>) -> Void) in
            // Download multiple images in parallel
            let group = DispatchGroup()
            var results = [String: UIImage?]()
            let lock = NSLock()
            
            for urlString in imageURLs {
                group.enter()
                
                guard let url = URL(string: urlString) else {
                    lock.lock()
                    results[urlString] = nil
                    lock.unlock()
                    group.leave()
                    continue
                }
                
                URLSession.shared.dataTask(with: url) { data, response, error in
                    defer { group.leave() }
                    
                    lock.lock()
                    if let data = data, let image = UIImage(data: data) {
                        results[urlString] = image
                    } else {
                        results[urlString] = nil
                    }
                    lock.unlock()
                }.resume()
            }
            
            group.notify(queue: .main) {
                completion(.success(results))
            }
        },
        maxNumberOfQueueingTasks: 32,     // Queue up to 32 image requests
        maxNumberOfRunningTasks: 4,       // Download 4 images simultaneously
        retryCount: 1,                    // Retry failed downloads once
        PriorityStrategy: .FIFO,          // Process oldest requests first
        cacheConfig: .init(
            capacity: 100,                // Cache up to 100 images
            memory: 50,                   // 50MB memory limit
            defaultTTL: 3600.0,           // 1 hour cache duration
            enableThreadSynchronization: true
        )
    )
)

// Download multiple images
let imageURLs = [
    "https://example.com/image1.jpg",
    "https://example.com/image2.jpg",
    "https://example.com/image3.jpg"
]

// Download all images
imageManager.fetch(keys: imageURLs) { url, result in
    switch result {
    case .success(let image):
        if let image = image {
            print("✓ Downloaded: \(image.size)")
        } else {
            print("- Failed to download: \(url)")
        }
    case .failure(let error):
        print("✗ Error: \(error)")
        }
    }
```



### 4. KVHeavyTasksManager

**Resource-Intensive Operations**: Handles demanding tasks such as large file downloads, video processing, and ML inference with comprehensive progress tracking

**Note**: Due to the complexity of HeavyTasksManager's data provider, please reference the Advanced Examples section directly for comprehensive usage examples.





## 🚀 Advanced Examples

### **⚡ MonoTask - Task Execution Scenarios**
| Scenario | Best Practices | Example Link |
|----------|----------------|--------------|
| **API Response Caching** | Cache API responses to reduce network calls | Coming Soon |
| **Module Initialization** | Cache app configuration with retry logic | Coming Soon |
| **UserProfile Manager** | Single-instance user profile management with caching | Coming Soon |

### **🚀 KVLightTasksManager - Light Task Scenarios**
| Scenario | Best Practices | Example Link |
|----------|----------------|--------------|
| **Image Download** | Efficient image downloading with caching and batch processing | Coming Soon |
| **Object Fetch Task** | Batch fetch objects by ID list with performance enhancement | Coming Soon |
| **Small Unzip Task** | Efficient batch processing of small archive files with caching and progress tracking | Coming Soon |

### **🏗️ KVHeavyTasksManager - Heavy Task Scenarios**
| Scenario | Best Practices | Example Link |
|----------|----------------|--------------|
| **Large File Download Management** | Large file downloads with progress tracking | [Large File Downloader](Examples/KVHeavyTasksManager/LargeFileDownloadManagement) |
| **Large File Unzip** | Processing large archive files with progress tracking and resource management | Coming Soon |





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







## 🙏 Acknowledgments

- Inspired by high-performance cache implementations
- Built with Swift's excellent type system and performance characteristics
- Tested extensively for production readiness
- Special thanks to the Swift community for feedback and contributions
- Special thanks to [Cursor](https://cursor.sh) - AI-first code editor for enhancing development productivity

---

**Made with ❤️ for the Swift community** 
