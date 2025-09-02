# Getting Started

Learn how to integrate Monstra into your Swift project and get started with the core components.

## Installation

### Swift Package Manager (Recommended)

Add Monstra to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "0.0.7")
]
```

Or add it directly in Xcode:
1. File → Add Package Dependencies
2. Enter `https://github.com/yangchenlarkin/Monstra.git`
3. Select version 0.0.7 or later

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'Monstra', '~> 0.0.7'
```

## Quick Start

Here's how to get started with each component:

### MemoryCache

```swift
import Monstra

// Create a cache with default configuration
let cache = MemoryCache<String, Data>()

// Store data with TTL
cache.set(element: imageData, for: "profile-image", expiredIn: 3600)

// Retrieve data
switch cache.getElement(for: "profile-image") {
case .hitNonNullElement(let data):
    print("Found cached data: \(data.count) bytes")
case .miss:
    print("Data not found or expired")
case .invalidKey:
    print("Invalid key format")
}
```

### MonoTask

```swift
import Monstra

// Create a task with caching
let networkTask = MonoTask<Data>(
    resultExpireDuration: 300,  // 5 minutes cache
    retry: .count(count: 3, intervalProxy: .exponentialBackoff(
        initialTimeInterval: 1.0,
        scaleRate: 2.0
    ))
) { callback in
    // Your network request
    performNetworkRequest(callback: callback)
}

// Execute with async/await
let result = await networkTask.asyncExecute()
```

### KVLightTasksManager

```swift
import Monstra

// Create a manager for concurrent operations
let imageManager = KVLightTasksManager<UIImage> { (urlString, completion) in
    guard let url = URL(string: urlString) else {
        completion(.failure(NetworkError.invalidURL))
        return
    }

    URLSession.shared.dataTask(with: url) { data, _, error in
        if let error = error {
            completion(.failure(error))
        } else if let data = data, let image = UIImage(data: data) {
            completion(.success(image))
        } else {
            completion(.failure(NetworkError.invalidData))
        }
    }.resume()
}

// Fetch multiple images concurrently
let imageURLs = ["url1", "url2", "url3"]
imageManager.fetch(keys: imageURLs) { url, result in
    switch result {
    case .success(let image):
        // Handle successful image load
        print("Loaded image from \(url)")
    case .failure(let error):
        // Handle error
        print("Failed to load image: \(error)")
    }
}
```

## Next Steps

- Explore <doc:Caching-Strategies> for advanced caching patterns
- Learn about <doc:Execution-Patterns> for task management
- Check out the <doc:Examples> for real-world usage scenarios
