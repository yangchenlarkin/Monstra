#!/usr/bin/env swift

import Foundation
import Monstra
import Alamofire
import CryptoKit

/// Example implementation of a local data provider that simulates processing tasks
/// 
/// This provider demonstrates how to implement the KVHeavyTaskDataProvider protocol
/// for local computational tasks. It processes a string character by character
/// with artificial delays to simulate heavy processing operations.
/// 
/// ## Use Cases
/// - Text processing and analysis
/// - Data transformation pipelines
/// - Simulation of CPU-intensive operations
/// - Testing task lifecycle management
/// 
/// ## Key Features
/// - Async/await support for modern Swift concurrency
/// - Graceful cancellation handling
/// - Configurable processing delays
/// - Simple progress tracking
class LocalDataProvider: Monstra.KVHeavyTaskBaseDataProvider<String, String, Never>, Monstra.KVHeavyTaskDataProviderInterface {
    /// Flag to track pause state for task lifecycle management
    private enum State {
        case idle
        case running(value: String)
        case finished(value: String)
        case paused(value: String)
    }
    private var state: State = .idle
    
    /// Processes the input string character by character with artificial delays
    /// 
    /// This method simulates a heavy computational task by processing each character
    /// of the input string with a 1-second delay. It demonstrates how to implement
    /// the core task logic in an async context with proper cancellation handling.
    /// 
    /// ## Implementation Details
    /// - Uses `Task.sleep()` for non-blocking delays
    /// - Checks for cancellation using `Task.checkCancellation()`
    /// - Processes characters sequentially to simulate work
    /// - Returns the complete processed string
    /// 
    /// - Returns: The processed string result, or nil if cancelled
    /// - Throws: CancellationError if the task is cancelled during execution
    func start() {
        let resumeData: String
        switch self.state {
        case .idle:
            resumeData = ""
        case .running(let value):
            return
        case .finished(let value):
            return
        case .paused(let value):
            resumeData = value
        }
        
        var result = resumeData
        
        // Compute start index. If resumeData is not a prefix, restart from beginning
        let startIndex: String.Index
        if key.hasPrefix(resumeData) {
            startIndex = key.index(key.startIndex, offsetBy: resumeData.count)
        } else {
            result = ""
            startIndex = key.startIndex
        }
        
        state = .running(value: result)
        
        for character in key[startIndex...] {
            // Simulate processing delay (1 second per character)
            Thread.sleep(forTimeInterval: 1)
            
            // Process the current character
            result.append(character)
            
            if case .running = state {
                state = .running(value: result)
            } else {
                return
            }
        }
        state = .finished(value: result)
        resultPublisher(.success(result))
    }
    
    /// Stops the current processing task and provides resume capability
    ///
    /// This method implements the pause/resume functionality by setting the pause flag
    /// and returning a resume function. The resume function can be called later to
    /// continue processing from where it left off.
    ///
    /// ## Usage
    /// ```swift
    /// let resumeTask = await provider.stop()
    /// // ... do other work ...
    /// await resumeTask?()
    /// ```
    ///
    /// - Returns: An async closure that resumes the task, or nil if already stopped
    func stop() -> KVHeavyTaskDataProviderStopAction {
        guard case .running(let value) = state else { return .dealloc }
        self.state = .paused(value: value)
        return .reuse
    }
}

/// Example implementation of a network data provider using Alamofire for file downloads
/// 
/// This provider demonstrates how to implement the KVHeavyTaskDataProvider protocol
/// for network-based tasks like file downloads. It leverages Alamofire's built-in
/// resume capability and provides progress tracking through custom events.
/// 
/// ## Use Cases
/// - Large file downloads with progress tracking
/// - Resume downloads after network interruption
/// - File integrity validation
/// - Background download management
/// 
/// ## Key Features
/// - Automatic resume capability using Alamofire
/// - Progress tracking with detailed metrics
/// - File integrity validation
/// - Intelligent caching and deduplication
/// - Error handling and retry logic
class AlamofireDataProvider: Monstra.KVHeavyTaskBaseDataProvider<URL, Data, Progress>, Monstra.KVHeavyTaskDataProviderInterface {
    /// The current download request (if active)
    /// 
    /// This property holds the Alamofire DownloadRequest instance, allowing
    /// for cancellation, pausing, and resuming of the download operation.
    private var request: DownloadRequest? = nil
    private var resumeData: Data? = nil
    
    /// Downloads the file from the specified URL with intelligent resume capability
    /// 
    /// This method implements sophisticated download logic that provides:
    /// 
    /// ## Download Strategy
    /// 1. **Cache Check**: Examines existing downloads for potential resume
    /// 2. **Integrity Validation**: Compares local and remote file sizes
    /// 3. **Resume Logic**: Automatically resumes from partial downloads
    /// 4. **Progress Tracking**: Real-time progress updates via custom events
    /// 5. **Error Handling**: Comprehensive error management and reporting
    /// 
    /// ## Implementation Flow
    /// - First checks if a partial download exists at the destination
    /// - Validates file integrity by comparing local vs remote file sizes
    /// - If sizes match, returns cached data immediately
    /// - If sizes differ, resumes download from existing data
    /// - If no existing data, starts fresh download
    /// - Publishes progress events throughout the download
    /// 
    /// - Returns: The downloaded file data as Data object, or nil if cancelled
    /// - Throws: Network errors (AFError), file system errors, or validation errors
    func start() {
        let destinationURL = Self.destinationURL(key)
        
        // Step 1: Check for existing download and validate integrity
        if let resumeData {
            request = AF.download(resumingWith: resumeData) { _, _ in
                return (destinationURL, [.createIntermediateDirectories, .removePreviousFile])
            }
        } else {
            // Step 4: Start fresh download
            print("🚀 Starting new download")
            request = AF.download(key, to: { _, _ in
                return (destinationURL, [.createIntermediateDirectories, .removePreviousFile])
            })
        }
        
        // Step 5: Set up progress tracking with custom event publishing
        
        request?.downloadProgress(queue: .global(), closure: customEventPublisher)
        
        // Step 6: Wait for download completion using async/await
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
    
    /// Stops the current download and saves resume data for later resumption
    /// 
    /// This method leverages Alamofire's built-in resume capability to gracefully
    /// cancel the current download while preserving the download state. The resume
    /// data is automatically saved to disk for later use.
    /// 
    /// ## How It Works
    /// - Cancels the active download request
    /// - Alamofire automatically generates resume data
    /// - Resume data is saved to the destination URL
    /// - Future downloads can resume from this point
    /// 
    /// ## Usage
    /// ```swift
    /// let resumeTask = await provider.stop()
    /// // ... do other work ...
    /// await resumeTask?() // Resume download
    /// ```
    /// 
    /// - Returns: An async closure that can resume the download, or nil if already finished
    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        guard let request = request, !request.isFinished else {
            print("📋 No active download to stop")
            self.resumeData = nil
            return .dealloc
        }
        
        print("⏸️ Stopping download and saving resume data...")
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
    
    /// Gets the caches directory for storing downloaded files
    /// 
    /// This method returns the appropriate directory for storing downloaded files.
    /// It first tries to use the system caches directory, falling back to the
    /// temporary directory if the caches directory is not available.
    /// 
    /// ## Directory Priority
    /// 1. System caches directory (preferred for persistence)
    /// 2. Temporary directory (fallback for limited environments)
    /// 
    /// - Returns: The URL of the directory to use for file storage
    private static func getCachesDirectory() -> URL {
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
           return cachesDirectory
        }
        return FileManager.default.temporaryDirectory
    }
    
    /// Generates the destination URL for a given download key
    /// 
    /// This method creates a unique file path based on the URL's MD5 hash,
    /// ensuring that each download has a consistent location regardless of
    /// when or how many times it's downloaded.
    /// 
    /// ## File Naming Strategy
    /// - Uses MD5 hash of the URL for uniqueness
    /// - Avoids conflicts between different URLs
    /// - Provides consistent caching behavior
    /// 
    /// - Parameter key: The URL of the file to download
    /// - Returns: The destination URL where the file will be saved
    private static func destinationURL(_ key: URL) -> URL {
        let cacheDirectory = getCachesDirectory()
        let downloadFolder = cacheDirectory.appendingPathComponent("AlamofireDataProvider", isDirectory: true)
        let destinationURL = downloadFolder.appendingPathComponent(key.absoluteString.md5())
        return destinationURL
    }
}

/// Extension to add MD5 hashing capability to String
/// 
/// This extension provides a simple way to generate MD5 hashes from strings,
/// which is useful for creating unique file names and cache keys.
/// 
/// ## Use Cases
/// - Creating unique file names for downloads
/// - Generating cache keys for data storage
/// - Ensuring consistent file paths across sessions
/// - Avoiding filename conflicts in shared directories
extension String {
    /// Generates an MD5 hash of the string
    /// 
    /// This method converts the string to UTF-8 data and computes its MD5 hash.
    /// The result is returned as a hexadecimal string.
    /// 
    /// ## Hash Properties
    /// - Deterministic: Same input always produces same output
    /// - Fixed length: Always returns 32 hexadecimal characters
    /// - Collision resistant: Different inputs produce different hashes
    /// 
    /// - Returns: A 32-character hexadecimal string representing the MD5 hash
    func md5() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Main Execution
// 
// ⚠️  IMPORTANT: This section is for demonstration purposes only!
// 
// ## For Users Implementing KVHeavyTaskDataProvider:
// 
// 1. **Implement your DataProvider**: Follow the patterns shown in the code above this section
//    - Create a class that conforms to `KVHeavyTaskDataProvider`
//    - Implement the required methods: `run()`, `stop()`
//    - Define your associated types: `K`, `Element`, `CustomEvent`
// 
// 2. **Use as Generic Type**: In your actual project, use your DataProvider as the generic type
//    ```swift
//    let taskManager = KVHeavyTasksManager<YourDataProvider>(config: config)
//    ```
// 
// 3. **Do NOT copy the code below**: The following code is only for demonstration and testing.
//    You should NOT create DataProvider instances like this in your real project.
// 
// ## Example Usage in Your Project:
// ```swift
// // ✅ Correct: Use your DataProvider as generic type
// class MyDataProvider: KVHeavyTaskDataProvider { ... }
// let manager = KVHeavyTasksManager<MyDataProvider>(config: config)
// 
// // ❌ Wrong: Don't create instances like the code below
// let provider = MyDataProvider(...) // Don't do this
// ```

/// Demonstrates local data processing with the LocalDataProvider
/// 
/// This function shows how to use the LocalDataProvider to process a string
/// character by character with artificial delays to simulate heavy processing.
/// 
/// ## Example Usage
/// ```swift
/// loadLocalData() // Processes "12345" with 1-second delays
/// ```
func localDataProviderTest() {
    LocalDataProvider(key: "12345") {_ in} resultPublisher: { result in
        switch result {
        case .success(let result):
            print("✅ Local processing completed: \(result ?? "nil")")
        case .failure(let error):
            print("❌ Local processing failed: \(error)")
        }
    }.start()
}

/// Main execution: Demonstrates file download with comprehensive progress tracking
/// 
/// This section shows how to:
/// - Create a download task handler with progress callbacks
/// - Monitor download progress with detailed metrics
/// - Handle download completion and errors
/// - Test stop/resume functionality
func alamofireDataProviderTest() {
    let largeFileURL = "https://updatecdn.meeting.qq.com/cos/197eaf6e0ea4bcafff72e5bb623555e6/TencentMeeting_0300000000_3.35.1.437.publish.arm64.officialwebsite.dmg"
    let smallFileURL = "https://www.google.com"
    
    /// Currently selected test URL for demonstration
    let __TEST_URL__ = largeFileURL
    
    guard let url = URL(string: __TEST_URL__) else { return }
    // Create the download task handler with detailed progress callback
    let taskHandler = AlamofireDataProvider(key: url) { progress in
        let percentage = progress.fractionCompleted * 100
        let downloadedMB = Double(progress.completedUnitCount) / 1_048_576 // Convert to MB
        let totalMB = Double(progress.totalUnitCount) / 1_048_576
        let downloadSpeed = progress.completedUnitCount > 0 ? "\(String(format: "%.1f", downloadedMB))MB" : "Calculating..."
        
        print("📥 Download Progress: \(String(format: "%.1f", percentage))% (\(downloadSpeed) / \(String(format: "%.1f", totalMB))MB)")
    } resultPublisher: { result in
        switch result {
        case .success(let data):
            print("✅ Download completed successfully!")
            if let data {
                print("📊 Downloaded data size: \(data.count) bytes")
                
                let sizeInMB = Double(data.count) / 1_048_576
                print("📁 File size: \(String(format: "%.2f", sizeInMB)) MB")
            } else {
                print("📊 Downloaded data size: 0 bytes")
            }
        case .failure(let error):
            print("❌ Download failed: \(error)")
            
            // Provide specific error handling based on error type
            if let afError = error as? AFError {
                switch afError {
                case .sessionTaskFailed(let underlyingError):
                    print("🔗 Network error: \(underlyingError)")
                case .responseValidationFailed(let reason):
                    print("🔍 Validation error: \(reason)")
                default:
                    print("🌐 Alamofire error: \(afError)")
                }
            }
        }
    }
    
    // Execute the download task with comprehensive error handling
    taskHandler.start()
    Thread.sleep(forTimeInterval: 3)
    taskHandler.stop()
    Thread.sleep(forTimeInterval: 3)
    taskHandler.start()
    Thread.sleep(forTimeInterval: 3)
    taskHandler.stop()
}

alamofireDataProviderTest()
localDataProviderTest()

/// Keep the main thread alive to allow async operations to complete
/// 
/// This is necessary for command-line applications to prevent the program
/// from terminating before async tasks have a chance to complete.
RunLoop.main.run()
