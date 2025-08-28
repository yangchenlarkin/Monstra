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
        // Step 1: Determine the destination URL for this download
        // This ensures consistent file storage and enables resume functionality
        let destinationURL = Self.destinationURL(key)
        
        // Step 2: Check for existing resume data and implement resume logic
        if let resumeData {
            // Resume Logic: Use Alamofire's resume capability with existing data
            // This allows downloads to continue from where they left off
            print("🔄 Resuming download from existing state...")
            request = AF.download(resumingWith: resumeData) { _, _ in
                // Destination configuration for resumed downloads
                // - createIntermediateDirectories: Ensures the full path exists
                // - removePreviousFile: Prevents conflicts with partial downloads
                return (destinationURL, [.createIntermediateDirectories, .removePreviousFile])
            }
        } else {
            // Fresh Download Logic: Start a new download from the beginning
            // This path is taken for first-time downloads or when resume data is unavailable
            print("🚀 Starting new download from scratch...")
            request = AF.download(key, to: { _, _ in
                // Destination configuration for new downloads
                // Same options as resume to ensure consistency
                return (destinationURL, [.createIntermediateDirectories, .removePreviousFile])
            })
        }
        
        // Step 3: Configure progress tracking and event publishing
        // This enables real-time progress updates through the Monstra event system
        request?.downloadProgress(queue: .global(), closure: customEventPublisher)
        
        // Step 4: Set up completion handling with comprehensive error management
        // This ensures proper state management and result publishing
        request?.responseData { [weak self] response in
            // Use weak self to prevent retain cycles in the closure
            guard let self = self else { return }
            
            switch response.result {
            case .success(let data):
                // Download Success: Clear resume data and publish success result
                print("✅ Download completed successfully: \(data.count) bytes")
                self.resumeData = nil  // Clear resume data as it's no longer needed
                self.resultPublisher(.success(data))  // Publish success through Monstra
                
            case .failure(let error):
                // Download Failure: Handle different types of failures appropriately
                print("❌ Download failed with error: \(error)")
                
                // Only publish failure if this wasn't a resume attempt
                // Resume failures should not propagate to avoid breaking the resume cycle
                if self.resumeData == nil {
                    self.resultPublisher(.failure(error))
                } else {
                    // Resume failed, but we can try a fresh download next time
                    print("🔄 Resume failed, will attempt fresh download on next start")
                }
            }
        }
    }
    
    /// Stops the current download and generates resume data for future resumption.
    /// Returns whether the provider can be reused or should be deallocated.
    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        // Step 1: Validate that there's an active download to stop
        // This prevents unnecessary operations and provides clear feedback
        guard let request = request, !request.isFinished else {
            print("📋 No active download to stop - request is nil or already finished")
            self.resumeData = nil  // Clear any stale resume data
            return .dealloc  // Indicate that this provider should be deallocated
        }
        
        // Step 2: Initiate graceful cancellation with resume data generation
        print("⏸️ Stopping download and generating resume data...")
        
        // Use a semaphore to synchronously wait for resume data generation
        // This ensures the method doesn't return until the cancellation is complete
        let semaphore = DispatchSemaphore(value: 0)
        var resumeDataResult: Data? = nil
        
        // Cancel the download and capture resume data
        // The completion handler will be called when resume data is ready
        request.cancel(byProducingResumeData: { resumeData in
            print("⏸️ Download cancelled, resume data generated: \(resumeData?.count ?? 0) bytes")
            resumeDataResult = resumeData
            semaphore.signal()  // Signal that resume data generation is complete
        })
        
        // Step 3: Wait for resume data generation with timeout protection
        // This prevents the method from hanging indefinitely if something goes wrong
        let waitResult = semaphore.wait(timeout: .now() + 1)  // 1 second timeout
        
        switch waitResult {
        case .success:
            // Resume data generated successfully
            print("⏸️ Download stopped successfully with resume data")
            self.resumeData = resumeDataResult  // Store resume data for future use
            return .reuse  // Indicate that this provider can be reused
            
        case .timedOut:
            // Resume data generation timed out
            print("⏸️ Download stop timed out - resume data generation failed")
            self.resumeData = nil  // Clear any partial resume data
            return .dealloc  // Force deallocation to prevent hanging state
        }
    }
    
    // MARK: - File Management & Caching
    
    /// Returns the optimal directory for file storage (caches directory preferred, temp directory as fallback).
    private static func getCachesDirectory() -> URL {
        // Step 1: Attempt to access the system caches directory
        // This is the preferred location for persistent file storage
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            print("📁 Using system caches directory: \(cachesDirectory.path)")
            return cachesDirectory
        }
        
        // Step 2: Fallback to temporary directory if caches directory is unavailable
        // This ensures the provider can function even in restricted environments
        let tempDirectory = FileManager.default.temporaryDirectory
        print("📁 Falling back to temporary directory: \(tempDirectory.path)")
        return tempDirectory
    }
    
    /// Generates a unique destination URL for downloads using MD5 hash of the source URL.
    /// Ensures consistent file paths and enables resume functionality.
    private static func destinationURL(_ key: URL) -> URL {
        // Step 1: Get the base cache directory (caches or temporary)
        let cacheDirectory = getCachesDirectory()
        
        // Step 2: Create a dedicated subdirectory for this provider
        // This organizes downloads and prevents conflicts with other components
        let downloadFolder = cacheDirectory.appendingPathComponent("AlamofireDataProvider", isDirectory: true)
        
        // Step 3: Generate the final destination URL using MD5 hash of the source URL
        // This ensures unique, deterministic file naming for each download
        let destinationURL = downloadFolder.appendingPathComponent(key.absoluteString.md5())
        
        print("📁 Generated destination URL: \(destinationURL.path)")
        return destinationURL
    }
}

// MARK: - String Extension for MD5 Hashing

/// Extension to add MD5 hashing capability to String objects for file naming and cache keys.
fileprivate extension String {
    
    /// Generates an MD5 hash of the string using CryptoKit for file naming and integrity checking.
    /// Returns a 32-character hexadecimal string.
    func md5() -> String {
        // Step 1: Convert string to UTF-8 encoded Data
        // UTF-8 is the most efficient encoding for hash computation
        let data = Data(self.utf8)
        
        // Step 2: Compute MD5 hash using CryptoKit
        // CryptoKit provides optimized, secure hash implementations
        let hash = Insecure.MD5.hash(data: data)
        
        // Step 3: Convert hash bytes to hexadecimal string
        // Each byte becomes two hexadecimal characters
        let hexString = hash.map { byte in
            String(format: "%02x", byte)  // %02x ensures 2-digit hex with leading zeros
        }.joined()  // Join all hex digits into single string
        
        return hexString
    }
}
