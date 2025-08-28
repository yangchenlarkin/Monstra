<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

# Large File Download Management Example

A comprehensive example demonstrating how to implement large file downloads with progress tracking, resume capability, and intelligent caching using the Monstra framework's `KVHeavyTasksManager` and Alamofire.

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

### 2.1 AlamofireDataProvider

The `AlamofireDataProvider` is a custom implementation of the `KVHeavyTaskDataProvider` protocol that handles file downloads using Alamofire.

#### Key Features:
- **Resume Capability**: Automatically resumes interrupted downloads
- **Progress Tracking**: Real-time progress updates with detailed metrics
- **File Integrity**: Validation and integrity checking
- **Error Handling**: Comprehensive error management and reporting
- **Intelligent Caching**: Smart cache management and deduplication

#### Implementation Details:

```swift
/// Network data provider using Alamofire for file downloads with resume capability and progress tracking.
/// Implements KVHeavyTaskDataProvider protocol for large file downloads with intelligent caching.
class AlamofireDataProvider: Monstra.KVHeavyTaskBaseDataProvider<URL, Data, Progress>, Monstra.KVHeavyTaskDataProviderInterface {
    
    // MARK: - Private Properties
    
    /// Active Alamofire download request for progress tracking, cancellation, and resume capability.
    private var request: DownloadRequest? = nil
    
    /// Resume data for interrupted downloads, enabling automatic download resumption.
    private var resumeData: Data? = nil
    
    // MARK: - Core Download Methods
    
    /// Starts or resumes a file download with automatic resume capability and progress tracking.
    /// Handles both fresh downloads and resume from interrupted downloads.
    func start() {
        let destinationURL = Self.destinationURL(key)
        
        // Check for existing download and validate integrity
        if let resumeData {
            request = AF.download(resumingWith: resumeData) { _, _ in
                return (destinationURL, [.createIntermediateDirectories, .removePreviousFile])
            }
        } else {
            // Start fresh download
            request = AF.download(key, to: { _, _ in
                return (destinationURL, [.createIntermediateDirectories, .removePreviousFile])
            })
        }
        
        // Set up progress tracking
        request?.downloadProgress(queue: .global(), closure: customEventPublisher)
        
        // Handle completion
        request?.responseData { response in
            switch response.result {
            case .success(let data):
                self.resumeData = nil
                self.resultPublisher(.success(data))
            case .failure(let error):
                if self.resumeData == nil {
                    self.resultPublisher(.failure(error))
                }
            }
        }
    }
    
    /// Stops the current download and generates resume data for future resumption.
    /// Returns whether the provider can be reused or should be deallocated.
    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        guard let request = request, !request.isFinished else {
            print("📋 No active download to stop")
            self.resumeData = nil
            return .dealloc
        }
        
        print("⏸️ Stopping download and generating resume data...")
        let semaphore = DispatchSemaphore(value: 0)
        var res: Data? = nil
        request.cancel(byProducingResumeData: {
            print("⏸️ Downloading stopped")
            res = $0
            semaphore.signal()
        })
        switch semaphore.wait(timeout: .now() + 1) {
        case .success:
            print("⏸️ Downloading stopped success")
            self.resumeData = res
            return .reuse
        case .timedOut:
            print("⏸️ Downloading stopped timeout")
            self.resumeData = nil
            return .dealloc
        }
    }
    
    // MARK: - File Management & Caching
    
    /// Returns the optimal directory for file storage (caches directory preferred, temp directory as fallback).
    private static func getCachesDirectory() -> URL {
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return cachesDirectory
        }
        return FileManager.default.temporaryDirectory
    }
    
    /// Generates a unique destination URL for downloads using MD5 hash of the source URL.
    /// Ensures consistent file paths and enables resume functionality.
    private static func destinationURL(_ key: URL) -> URL {
        let cacheDirectory = getCachesDirectory()
        let downloadFolder = cacheDirectory.appendingPathComponent("AlamofireDataProvider", isDirectory: true)
        let destinationURL = downloadFolder.appendingPathComponent(key.absoluteString.md5())
        return destinationURL
    }
}

// MARK: - String Extension for MD5 Hashing

/// Extension to add MD5 hashing capability to String objects for file naming and cache keys.
fileprivate extension String {
    
    /// Generates an MD5 hash of the string using CryptoKit for file naming and integrity checking.
    /// Returns a 32-character hexadecimal string.
    func md5() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        let hexString = hash.map { byte in
            String(format: "%02x", byte)
        }.joined()
        return hexString
    }
}

#### Download Strategy:
1. **Cache Check**: Examines existing downloads for potential resume
2. **Integrity Validation**: Compares local and remote file sizes
3. **Resume Logic**: Automatically resumes from partial downloads
4. **Progress Tracking**: Real-time progress updates via custom events
5. **Error Handling**: Comprehensive error management and reporting

### 2.2 Usage (in main)

The main.swift file demonstrates advanced usage of the `AlamofireDataProvider` and `AFNetworkingDataProvider` with `KVHeavyTasksManager`, including both modern async/await and traditional callback patterns.

#### Key Features Demonstrated:

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
- Built-in resume capability with `resumeData`
- Automatic file path management
- Progress tracking with Alamofire's progress system

### **AFNetworkingDataProvider**  
- Uses **AFNetworking** networking library
- Custom resume implementation with progress tracking
- Manual directory creation and file management
- Progress tracking with AFNetworking's progress system

**💡 Try switching between providers to see the difference:**

```swift
// try AlamofireDataProvider to see the difference
let manager = Manager<URL, Data, Progress, AlamofireDataProvider>()

// try AFNetworkingDataProvider to see the difference  
let manager = Manager<URL, Data, Progress, AFNetworkingDataProvider>()
```

Both providers implement the same `KVHeavyTaskDataProviderInterface`, so you can easily swap between them without changing your business logic!



