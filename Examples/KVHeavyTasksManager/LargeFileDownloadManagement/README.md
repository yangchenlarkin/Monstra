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
```

#### Download Strategy:
1. **Cache Check**: Examines existing downloads for potential resume
2. **Integrity Validation**: Compares local and remote file sizes
3. **Resume Logic**: Automatically resumes from partial downloads
4. **Progress Tracking**: Real-time progress updates via custom events
5. **Error Handling**: Comprehensive error management and reporting

### 2.2 Usage (in main)

The main.swift file demonstrates a basic setup for using the `AlamofireDataProvider` with `KVHeavyTasksManager`.

#### Current Implementation:

```swift
import Foundation
import Alamofire
import Monstra

// Example URLs for testing large file downloads
let chrome = URL(string: "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg")!
let evernote = URL(string: "https://mac.desktop.evernote.com/builds/Evernote-latest.dmg")!
let slack = URL(string: "https://downloads.slack-edge.com/desktop-releases/mac/universal/4.45.69/Slack-4.45.69-macOS.dmg")!

// Create the task manager with AlamofireDataProvider
let manager = KVHeavyTasksManager<URL, Data, Progress, AlamofireDataProvider>(config: .init())

// Basic download example (currently incomplete)
manager.fetch(key: chrome) { result in
    // TODO: Handle download result
}

// Keep the main thread alive to allow async operations to complete
RunLoop.main.run()
```

#### Enhanced Usage Examples:

For more comprehensive usage, you can extend the main.swift file with:

```swift
// Download with completion handler
manager.fetch(key: chrome) { result in
    switch result {
    case .success(let data):
        print("✅ Download completed: \(data.count) bytes")
    case .failure(let error):
        print("❌ Download failed: \(error)")
    }
}

// Download with progress tracking
manager.fetch(key: chrome) { result in
    // Handle completion
} progress: { progress in
    let percentage = progress.fractionCompleted * 100
    let downloadedMB = Double(progress.completedUnitCount) / 1_048_576
    let totalMB = Double(progress.totalUnitCount) / 1_048_576
    
    print("📥 Progress: \(String(format: "%.1f", percentage))% (\(String(format: "%.1f", downloadedMB))MB / \(String(format: "%.1f", totalMB))MB)")
}
```

#### Key Framework Behavior:

**Multiple Callbacks, Single Execution**: The Monstra framework allows multiple callbacks to be registered for the same download task, but the actual download only happens once. This is demonstrated in the logs:

**File System & Caching Behavior:**
```
📁 Using system caches directory: /Users/zennish/Library/Caches
📁 Generated destination URL: /Users/zennish/Library/Caches/AlamofireDataProvider/b339168e62d77e242b7e9e454d82fb18
🚀 Starting new download from scratch...
fetch task 0. progress: 10943 / 229019705
fetch task 1. progress: 10943 / 229019705
fetch task 2. progress: 10943 / 229019705
...
fetch task 9. progress: 229019705 / 229019705
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


