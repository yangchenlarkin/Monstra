<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

# Large File Download Management Example

A comprehensive example demonstrating how to implement large file downloads with progress tracking, resume capability, and intelligent caching using the Monstra framework's `KVHeavyTasksManager` with both Alamofire and AFNetworking providers.

## 1. How to Run This Example

### 1.1 Requirements

- **Platforms**: 
  - iOS 13.0+
  - macOS 10.15+
  - tvOS 13.0+
  - watchOS 6.0+
- **Swift**: 5.5+
- **Dependencies**: 
  - Monstra framework (local development version)
  - Alamofire 5.8.0+
  - AFNetworking 4.0.0+

### 1.2 Download the Repo

```bash
git clone https://github.com/yangchenlarkin/Monstra.git
cd Monstra/Examples/KVHeavyTasksManager/LargeFileDownloadManagement
```

### 1.3 Open LargeFileDownloadManagement Using Xcode

**Important: Don't open the root project!**

Instead, open just the example package:

```bash
# From the LargeFileDownloadManagement directory
xed Package.swift
```

Or manually in Xcode:
1. Open Xcode
2. Go to `File → Open...`
3. Navigate to the `LargeFileDownloadManagement` folder
4. Select `Package.swift` (not the root Monstra project)
5. Click Open

This avoids conflicts with the main project and opens the example as a standalone Swift package.

## 2. Code Explanation

### 2.1 SimpleDataProvider (Educational, synchronous)

For learning purposes, this example also includes a very small provider: `SimpleDataProvider`.

Characteristics:
- Emits simple lifecycle events: `didStart` and `didFinish`
- Performs a blocking read with `Data(contentsOf:)` on a background queue
- No progress or resume support (keep it for educational use; prefer streaming in production)

Notes:
- `Data(contentsOf:)` is synchronous and loads the whole payload into memory; this provider is intentionally simple.
- For production, use `AlamofireDataProvider` or `AFNetworkingDataProvider` to get progress, cancellation, and resume.

#### Implementation

```swift
import Foundation
import Monstra

enum SimpleDataProviderEvent {
    case didStart
    case didFinish
}

/// Minimal synchronous provider for educational purposes only.
class SimpleDataProvider: Monstra.KVHeavyTaskBaseDataProvider<URL, Data, SimpleDataProviderEvent>, Monstra.KVHeavyTaskDataProviderInterface {
    let semaphore = DispatchSemaphore(value: 1)
    var isRunning = false {
        didSet { customEventPublisher(isRunning ? .didStart : .didFinish) }
    }

    func start() {
        semaphore.wait(); defer { semaphore.signal() }
        guard !isRunning else { return }
        isRunning = true

        DispatchQueue.global().async {
            let result: Result<Data?, Error>
            do {
                let data = try Data(contentsOf: self.key, options: .mappedIfSafe)
                result = .success(data)
            } catch {
                result = .failure(error)
            }

            self.semaphore.wait(); defer { self.semaphore.signal() }
            guard self.isRunning else { return }
            self.isRunning = false
            self.resultPublisher(result)
        }
    }

    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        semaphore.wait(); defer { semaphore.signal() }
        guard isRunning else { return .dealloc }
        isRunning = false
        return .dealloc
    }
}
```

Minimal usage:

```swift
// Uses SimpleDataProvider with a custom event type
typealias SimpleManager = KVHeavyTasksManager<URL, Data, SimpleDataProviderEvent, SimpleDataProvider>

let simpleManager = SimpleManager(config: .init())
let fileURL = URL(string: "https://example.com/file.bin")!

simpleManager.fetch(
    key: fileURL,
    customEventObserver: { event in
        switch event {
        case .didStart:  print("simple provider: didStart")
        case .didFinish: print("simple provider: didFinish")
        }
    },
    result: { result in
        switch result {
        case .success(let data):
            print("downloaded: \(data.count) bytes")
        case .failure(let error):
            print("failed: \(error)")
        }
    }
)
```
### 2.2 AlamofireDataProvider

The `AlamofireDataProvider` is a custom implementation of the `KVHeavyTaskDataProvider` protocol that handles file downloads using Alamofire.

#### Key Features:
- **Resume Capability**: Automatically resumes interrupted downloads using resume data caching
- **Progress Tracking**: Real-time progress updates with detailed metrics
- **Memory Cache Integration**: Uses Monstra's MemoryCache for resume data storage
- **Error Handling**: Comprehensive error management and reporting
- **Intelligent Caching**: Smart cache management with 1GB memory limit for resume data

#### Download Strategy:
1. **Resume Data Cache**: Stores resume data in MemoryCache with 1GB limit
2. **Resume Logic**: Automatically resumes from partial downloads using cached resume data
3. **Progress Tracking**: Real-time progress updates via custom events
4. **Error Handling**: Comprehensive error management and reporting
5. **File Management**: Automatic directory creation and file path management

### 2.3 AFNetworkingDataProvider

The `AFNetworkingDataProvider` is a custom implementation of the `KVHeavyTaskDataProvider` protocol that handles file downloads using AFNetworking 4.x.

#### Key Features:
- **Modern AFNetworking**: Uses AFNetworking 4.x with URLSession-based architecture
- **Progress Tracking**: Real-time progress updates with AFNetworking's progress system
- **File Management**: Automatic directory creation and file path management
- **Error Handling**: Comprehensive error handling with proper cleanup
- **File Extension Preservation**: Maintains original file extensions for downloaded files

#### Download Strategy:
1. **Directory Creation**: Automatically creates download directories with proper permissions
2. **File Naming**: Generates unique filenames with preserved extensions using MD5 hashing
3. **Progress Tracking**: Real-time progress updates via AFNetworking's progress system
4. **File Reading**: Reads completed downloads and returns Data objects
5. **Session Management**: Proper URLSession lifecycle management

### 2.4 Usage (in main)

The main.swift file demonstrates advanced usage of both providers with `KVHeavyTasksManager`, including both modern async/await and traditional callback patterns. It showcases how to easily switch between providers using type aliases.

#### Key Features Demonstrated:

**0. Provider Switching with Type Aliases:**
```swift
typealias AFNetworkingManager = KVHeavyTasksManager<URL, Data, Progress, AFNetworkingDataProvider>
typealias AlamofireManager = KVHeavyTasksManager<URL, Data, Progress, AlamofireDataProvider>
```
This allows easy switching between providers by changing the type alias usage.

**1. Execution Merging (Multiple Callbacks, Single Download):**
```swift
// Multiple async tasks share the same download
await withTaskGroup(of: Void.self) { group in
    for i in 0..<10 {
        group.addTask {
            let result = await manager1.asyncFetch(key: chrome, customEventObserver: { progress in
                print("fetch task \(i). progress: \(progress.completedUnitCount) / \(progress.totalUnitCount)")
            })
            print("fetch task \(i). result: \(result)")
        }
    }
}
```
#### Key Framework Behavior:

**Multiple Callbacks, Single Execution**: The Monstra framework allows multiple callbacks to be registered for the same download task, but the actual download only happens once. This is demonstrated in the logs:

**File System & Caching Behavior:**
```
📁 Using system caches directory: /Users/zennish/Library/Caches
📁 Generated destination URL: /Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18
🚀 Starting download for key: https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg
fetch task 0. progress: 10943 / 229019705
fetch task 1. progress: 10943 / 229019705
fetch task 2. progress: 10943 / 229019705
...
fetch task 9. progress: 229019705 / 229019705
📁 AFNetworking destination callback called, returning: /Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18.dmg
📁 Download completed, file URL: /Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18.dmg
📁 Expected destination: /Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18.dmg
✅ Download completed successfully: 229019705 bytes
fetch task 0. result: success(Optional(229019705 bytes))
fetch task 1. result: success(Optional(229019705 bytes))
...
fetch task 9. result: success(Optional(229019705 bytes))
```

**What This Means:**
- **10 different callbacks** were registered for the same download
- **Only 1 actual download** was executed (as shown by the single "Starting new download from scratch" message)
- **All 10 callbacks** received progress updates and completion results
- **Efficient resource usage** - no duplicate downloads for the same URL

This pattern is useful for scenarios where multiple parts of your app need the same file, ensuring efficient downloads and consistent state across all consumers.


**2. Task Queueing (Sequential Downloads):**
```swift
// Custom configuration for limited concurrency
let config = Manager.Config(maxNumberOfQueueingTasks: 1, maxNumberOfRunningTasks: 1, priorityStrategy: .FIFO)
let manager = Manager(config: config)

// Downloads will execute sequentially
manager.fetch(key: chrome) { result in
    print("Chrome download completed")
}
manager.fetch(key: slack) { result in
    print("Slack download completed")
}
manager.fetch(key: evernote) { result in
    print("Evernote download completed")
}
```


**Task Queueing Behavior:**
This configuration ensures downloads execute sequentially with limited concurrency. The logs show the sequential execution:

```
📁 Using system caches directory: /Users/zennish/Library/Caches
📁 Generated destination URL: /Users/zennish/Library/Caches/AlamofireDataProvider/b339168e62d77e242b7e9e454d82fb18
🚀 Starting new download for key: https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg
did fetch evernote. result: failure(Monstra.KVHeavyTasksManager<Foundation.URL, Foundation.Data, __C.NSProgress, LargeFileDownloadManagement.AlamofireDataProvider>.Errors.taskEvictedDueToPriorityConstraints(https://mac.desktop.evernote.com/builds/Evernote-latest.dmg))
downloading chrome: 0.0017893656792545428%
downloading chrome: 0.004180426308731819%
downloading chrome: 0.006571486938209094%
downloading chrome: 0.008958617774832957%
downloading chrome: 0.011349678404310231%
......
downloading chrome: 99.57528894729822%
downloading chrome: 99.69696537684388%
downloading chrome: 99.81857194340549%
downloading chrome: 99.94018549626549%
downloading chrome: 100.0%
✅ Download completed successfully: 229019705 bytes
📁 Using system caches directory: /Users/zennish/Library/Caches
📁 Generated destination URL: /Users/zennish/Library/Caches/AlamofireDataProvider/5825d1009072c995406c037b2fdc7507
🚀 Starting new download for key: https://downloads.slack-edge.com/desktop-releases/mac/universal/4.45.69/Slack-4.45.69-macOS.dmg
did fetch chrome. result: success(Optional(229019705 bytes))
downloading slack: 0.008185515174136616%
downloading slack: 0.016579784322574478%
downloading slack: 0.02497405347101234%
downloading slack: 0.033368322619450205%
downloading slack: 0.1747368217616714%
......
downloading slack: 99.78830551824257%
downloading slack: 99.92599594674667%
downloading slack: 100.0%
✅ Download completed successfully: 194966348 bytes
did fetch slack. result: success(Optional(229019705 bytes))
```

**What This Shows:**
- **Sequential execution**: Chrome downloads first, then Slack
- **Task eviction**: Evernote task was evicted due to priority constraints
- **Progress tracking**: Real-time progress updates for each download
- **Cache management**: Each download gets a unique cache file
- **Completion handling**: Results are delivered as each download finishes

---

**💡 Pro Tip**: Try different priority strategies to see how they affect task execution! As noted in the code:

```swift
let config2 = Manager.Config(maxNumberOfQueueingTasks: 1, maxNumberOfRunningTasks: 1, priorityStrategy: .FIFO) // try other strategies to see the difference
```

Experiment with different `priorityStrategy` values to observe how they change the download order and task handling behavior.

---

## 🔄 **Provider Comparison**

This example includes two different network data providers to demonstrate the flexibility of the Monstra framework:

### **AlamofireDataProvider**
- Uses **Alamofire** networking library
- Built-in resume capability with `resumeData` and MemoryCache integration
- Automatic file path management with MD5 hashing
- Progress tracking with Alamofire's progress system
- Resume data caching with 1GB memory limit

### **AFNetworkingDataProvider**  
- Uses **AFNetworking 4.x** networking library
- Modern URLSession-based architecture
- Automatic directory creation and file management
- Progress tracking with AFNetworking's progress system
- File extension preservation with MD5-based naming

**💡 Try switching between providers to see the difference:**

```swift
// try AlamofireDataProvider to see the difference
let manager = Manager<URL, Data, Progress, AlamofireDataProvider>()

// try AFNetworkingDataProvider to see the difference  
let manager = Manager<URL, Data, Progress, AFNetworkingDataProvider>()
```

Both providers implement the same `KVHeavyTaskDataProviderInterface`, so you can easily swap between them without changing your business logic!

### 2.4 SimpleDataProvider (Educational, synchronous)

For learning purposes, this example also includes a very small provider: `SimpleDataProvider`.

Characteristics:
- Emits simple lifecycle events: `didStart` and `didFinish`
- Performs a blocking read with `Data(contentsOf:)` on a background queue
- No progress or resume support (keep it for educational use; prefer streaming in production)

Minimal usage:

```swift
// Uses SimpleDataProvider with a custom event type
typealias SimpleManager = KVHeavyTasksManager<URL, Data, SimpleDataProviderEvent, SimpleDataProvider>

let simpleManager = SimpleManager(config: .init())
let fileURL = URL(string: "https://example.com/file.bin")!

simpleManager.fetch(
    key: fileURL,
    customEventObserver: { event in
        switch event {
        case .didStart:  print("simple provider: didStart")
        case .didFinish: print("simple provider: didFinish")
        }
    },
    result: { result in
        switch result {
        case .success(let data):
            print("downloaded: \(data.count) bytes")
        case .failure(let error):
            print("failed: \(error)")
        }
    }
)
```

Notes:
- `Data(contentsOf:)` is synchronous and loads the whole payload into memory; this provider is intentionally simple.
- For production, use `AlamofireDataProvider` or `AFNetworkingDataProvider` to get progress, cancellation, and resume.

## 🏗️ **Implementation Details**

### **Current Code Structure**
The example includes three main Swift files:

1. **`main.swift`** - Main execution file demonstrating both providers
2. **`AlamofireDataProvider.swift`** - Alamofire-based download provider with resume caching
3. **`AFNetworkingDataProvider.swift`** - AFNetworking 4.x-based download provider

### **Key Implementation Features**

#### **Resume Data Caching (AlamofireDataProvider)**
```swift
static let resumeDataCache: MemoryCache<URL, Data> = .init(
    configuration: .init(
        memoryUsageLimitation: .init(memory: 1024), 
        costProvider: { $0.count }
    )
) // 1GB limit for resume data
```

#### **File Extension Preservation (AFNetworkingDataProvider)**
```swift
let fileName = key.absoluteString.md5()
let fileExtension = key.pathExtension.isEmpty ? "download" : key.pathExtension
let destinationURL = downloadFolder.appendingPathComponent("\(fileName).\(fileExtension)")
```

#### **Easy Provider Switching**
```swift
// Switch between providers by changing the type alias
let manager1 = AFNetworkingManager(config: .init())
let manager2 = AlamofireManager(config: config2)
```

---

## 🌐 **Demo URLs & File Types**

The example downloads three different types of files to demonstrate various scenarios:

- **Chrome DMG** (`googlechrome.dmg`) - Large macOS application installer (~229MB)
- **Slack DMG** (`Slack-4.45.69-macOS.dmg`) - Medium-sized application installer (~195MB)  
- **Evernote DMG** (`Evernote-latest.dmg`) - Application installer for priority constraint testing

These files are chosen because they:
- Represent real-world download scenarios
- Have different sizes for testing memory management
- Are publicly accessible for demonstration purposes
- Show how the framework handles various file types and sizes

---

## 📚 **Enhanced Framework Documentation**

The Monstra framework has been enhanced with clearer documentation for better developer experience:

### **MemoryCache Cost Provider Clarification**
The `MemoryCache.Configuration.costProvider` now includes clear documentation about cost units:

```swift
/// ## Important Notes:
/// - **Cost Unit**: The returned value represents memory cost in **bytes**
/// - The returned element should be **positive** and **reasonable** (avoid extremely large elements)
/// - Should be **consistent** for the same input (deterministic)
/// - **Performance**: This closure is called frequently during eviction, so keep it fast
/// - **Memory limit**: Total cost across all elements should not exceed `MemoryUsageLimitation.memory`
/// - **Default behavior**: Returns 0 if not specified, relying on automatic memory layout calculation
public let costProvider: (Element) -> Int
```

**Key Benefits:**
- **Clear Unit Specification**: Developers know to return values in bytes
- **Accurate Memory Management**: Proper byte-level precision for eviction decisions
- **Better Performance**: Understanding that costProvider is called frequently during eviction
- **Consistent Behavior**: Guidelines for deterministic and reasonable cost calculations

**Example Usage:**
```swift
let cache = MemoryCache<String, Data>(configuration: .init(
    costProvider: { data in data.count }  // Returns bytes for Data objects
))

let stringCache = MemoryCache<String, String>(configuration: .init(
    costProvider: { string in string.utf8.count }  // Returns bytes for String objects
))
```

This enhancement ensures developers can make informed decisions about memory cost calculations and cache management strategies.



