# 📚 Monstra Wiki Structure Guide

## 🏠 **Home Page (Wiki Landing)**

# Welcome to Monstra Wiki

Monstra is a high-performance Swift framework for task execution, memory caching, and data management.

## 📖 Quick Navigation

### Getting Started
- [Installation Guide](Installation-Guide)
- [Quick Start Tutorial](Quick-Start-Tutorial)
- [Basic Examples](Basic-Examples)

### Components
- [MonoTask Guide](MonoTask-Guide)
- [MemoryCache Guide](MemoryCache-Guide)
- [KVLightTasksManager Guide](KVLightTasksManager-Guide)
- [KVHeavyTasksManager Guide](KVHeavyTasksManager-Guide)

### Advanced Topics
- [Performance Optimization](Performance-Optimization)
- [Thread Safety](Thread-Safety)
- [Error Handling](Error-Handling)
- [Best Practices](Best-Practices)

### Community
- [Contributing](Contributing)
- [FAQ](FAQ)
- [Troubleshooting](Troubleshooting)
- [Migration Guides](Migration-Guides)

## 🔗 External Links
- [API Documentation](https://yangchenlarkin.github.io/Monstra/)
- [GitHub Repository](https://github.com/yangchenlarkin/Monstra)
- [Issues & Bug Reports](https://github.com/yangchenlarkin/Monstra/issues)

## 📄 **Individual Wiki Pages**

### **Installation-Guide**

# Installation Guide

## Swift Package Manager (Recommended)

### Xcode Integration
1. Open your project in Xcode
2. Go to **File → Add Package Dependencies**
3. Enter: `https://github.com/yangchenlarkin/Monstra.git`
4. Select version: `0.0.9` or `Up to Next Major`
5. Click **Add Package**

### Package.swift
```swift
dependencies: [
    .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "0.0.9")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["Monstra"]
    )
]
```

## CocoaPods

### Podfile
```ruby
pod 'Monstra', '~> 0.0.9'
```

Then run:
```bash
pod install
```

## Requirements
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 5.5+
- Xcode 13.0+

## Verification
```swift
import Monstra

let cache = MemoryCache<String, String>()
print("Monstra installed successfully!")
```

### **Quick-Start-Tutorial**

# Quick Start Tutorial

## 5-Minute Integration

### Step 1: Import Monstra
```swift
import Monstra
```

### Step 2: Create a MonoTask
```swift
let userTask = MonoTask<User> { callback in
    // Your API call
    APIClient.fetchCurrentUser { result in
        callback(result)
    }
}
```

### Step 3: Execute the Task
```swift
userTask.execute { result in
    switch result {
    case .success(let user):
        print("User: \(user.name)")
    case .failure(let error):
        print("Error: \(error)")
    }
}
```

### Step 4: Enjoy Automatic Benefits
- ✅ Multiple calls are merged into one
- ✅ Results are cached with TTL
- ✅ Automatic retry on failure
- ✅ Thread-safe execution

## Next Steps
- Read the [MonoTask Guide](MonoTask-Guide) for advanced features
- Check out [Basic Examples](Basic-Examples) for more use cases
- Learn about [Performance Optimization](Performance-Optimization)

### **MonoTask-Guide**

# MonoTask Complete Guide

## Overview
MonoTask ensures only one instance of a task runs at a time while providing intelligent result caching and retry capabilities.

## Basic Usage

### Simple Task
```swift
let task = MonoTask<String> { callback in
    // Simulate API call
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        callback(.success("Hello, World!"))
    }
}

task.execute { result in
    print(result) // "Hello, World!"
}
```

### With TTL Caching
```swift
let task = MonoTask<User>(ttl: 300) { callback in // 5 minutes cache
    APIClient.fetchUser { user in
        callback(.success(user))
    }
}
```

### With Retry Logic
```swift
let task = MonoTask<Data>(
    ttl: 60,
    retry: .exponentialBackoff(maxRetries: 3, baseDelay: 1.0)
) { callback in
    NetworkService.fetchData { result in
        callback(result)
    }
}
```

## Advanced Features

### Execution Strategies
```swift
// Force update (ignore cache)
task.execute(forceUpdate: true) { result in
    // Fresh data
}

// Clear cache with different strategies
task.clearResult(
    ongoingExecutionStrategy: .cancelExecution,
    shouldRestartWhenIDLE: true
)
```

### Async/Await Support
```swift
do {
    let result = try await task.asyncExecute()
    print("Result: \(result)")
} catch {
    print("Error: \(error)")
}
```

## Best Practices
1. **Use appropriate TTL values** - Balance freshness vs performance
2. **Handle errors gracefully** - Always provide error handling
3. **Choose retry strategies wisely** - Consider your use case
4. **Monitor cache hit rates** - Use for performance optimization

### **FAQ**

# Frequently Asked Questions

## General Questions

### Q: Is Monstra thread-safe?
**A:** Yes, all components are fully thread-safe and can be used from multiple threads simultaneously.

### Q: What are the performance characteristics?
**A:** 
- MonoTask: Sub-millisecond execution merging
- MemoryCache: 1M+ operations per second
- Zero memory leaks with proper lifecycle management

### Q: Does Monstra have dependencies?
**A:** No external dependencies. Only uses Foundation framework.

## MonoTask Questions

### Q: How does execution merging work?
**A:** When multiple requests for the same task arrive concurrently, only one execution happens and all callers receive the same result.

### Q: Can I customize retry behavior?
**A:** Yes, supports exponential backoff, fixed intervals, and custom retry strategies.

### Q: How do I handle cache invalidation?
**A:** Use `clearResult()` with different strategies: cancel ongoing, allow completion, or restart after completion.

## MemoryCache Questions

### Q: How is memory managed?
**A:** Automatic eviction based on TTL, priority, and memory limits. Configurable cost functions for custom memory accounting.

### Q: What happens when cache is full?
**A:** Priority-based LRU eviction removes least important items first.

### Q: Can I get cache statistics?
**A:** Yes, comprehensive statistics including hit rates, memory usage, and eviction counts.

## Troubleshooting

### Q: My tasks aren't merging, why?
**A:** Ensure you're using the same MonoTask instance. Different instances don't merge executions.

### Q: Memory usage keeps growing
**A:** Check your TTL settings and memory limits. Consider implementing custom cost functions.

### Q: Compilation errors with Swift versions
**A:** Monstra requires Swift 5.5+. Update your Xcode and Swift version.

### **Performance-Optimization**

# Performance Optimization Guide

## MonoTask Optimization

### 1. Choose Appropriate TTL
```swift
// Short-lived data
let realtimeTask = MonoTask<Price>(ttl: 5) { ... }

// Stable data  
let userProfileTask = MonoTask<User>(ttl: 300) { ... }

// Static data
let configTask = MonoTask<Config>(ttl: 3600) { ... }
```

### 2. Optimize Retry Strategies
```swift
// For critical operations
.exponentialBackoff(maxRetries: 5, baseDelay: 0.5)

// For non-critical operations  
.fixedInterval(maxRetries: 2, interval: 1.0)

// For custom logic
.custom { attempt in
    return attempt < 3 ? 0.1 * pow(2.0, Double(attempt)) : nil
}
```

## MemoryCache Optimization

### 1. Configure Memory Limits
```swift
let config = MemoryCache.Configuration(
    memoryLimit: MemoryUsageLimitation(
        itemCount: 1000,
        totalCost: 50 * 1024 * 1024 // 50MB
    )
)
```

### 2. Implement Cost Functions
```swift
let config = MemoryCache.Configuration(
    costProvider: { key, value in
        return MemoryLayout.size(ofValue: value)
    }
)
```

### 3. Monitor Statistics
```swift
cache.statistics.report = { stats in
    print("Hit rate: \(stats.hitRate)")
    print("Memory usage: \(stats.memoryUsage)")
    
    if stats.hitRate < 0.8 {
        // Consider adjusting TTL or cache size
    }
}
```

## Task Manager Optimization

### 1. Configure Concurrency Limits
```swift
// Light tasks - higher concurrency
let lightConfig = KVLightTasksManager.Config(
    concurrentExecutionLimit: 8,
    queueLimit: 512
)

// Heavy tasks - lower concurrency  
let heavyConfig = KVHeavyTasksManager.Config(
    concurrentExecutionLimit: 2,
    queueLimit: 32
)
```

### 2. Choose Priority Strategies
```swift
// LIFO for user-initiated actions
.priorityStrategy(.lifo)

// FIFO for background processing
.priorityStrategy(.fifo)
```

## Benchmarking

### Performance Testing Template
```swift
import XCTest
@testable import Monstra

class PerformanceTests: XCTestCase {
    func testMonoTaskPerformance() {
        let task = MonoTask<Int> { callback in
            callback(.success(42))
        }
        
        measure {
            let group = DispatchGroup()
            
            for _ in 0..<1000 {
                group.enter()
                task.execute { _ in
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
}
```

## 🚀 **How to Create These Pages**

### **Method 1: Web Interface**
1. Go to your repository's Wiki tab
2. Click **New Page**
3. Enter page title (e.g., "Installation-Guide")
4. Copy and paste the markdown content
5. Click **Save Page**

### **Method 2: Git Clone (Advanced)**
```bash
# Clone the wiki repository
git clone https://github.com/yangchenlarkin/Monstra.wiki.git

# Create markdown files
echo "# Home Content" > Home.md
echo "# Installation Guide" > Installation-Guide.md

# Commit and push
git add .
git commit -m "Add wiki pages"
git push origin master
```

## 📝 **Wiki Best Practices**

1. **Use clear navigation** - Link between related pages
2. **Keep content updated** - Sync with code changes
3. **Include examples** - Practical code snippets
4. **Use consistent formatting** - Follow markdown standards
5. **Cross-reference** - Link to API docs and GitHub issues
6. **Community contributions** - Allow others to edit and improve

The Wiki becomes a living documentation that complements your API reference and provides practical guidance for developers! 📚
