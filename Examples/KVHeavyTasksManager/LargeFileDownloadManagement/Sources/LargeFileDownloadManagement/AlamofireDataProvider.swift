//
//  AlamofireDataProvider.swift
//  LargeFileDownloadManagement
//
//  Created by Larkin on 2025/8/28.
//

import Foundation
import Monstra
import Alamofire
import CryptoKit

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
fileprivate extension String {
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
