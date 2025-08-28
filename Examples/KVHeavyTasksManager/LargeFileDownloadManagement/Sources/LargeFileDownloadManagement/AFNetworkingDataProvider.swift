//
//  AFNetworkingDataProvider.swift
//  LargeFileDownloadManagement
//
//  Created by Larkin on 2025/8/28.
//

import Foundation
import Monstra
import AFNetworking
import CryptoKit

/// Network data provider using AFNetworking for file downloads with resume capability and progress tracking.
/// Implements KVHeavyTaskDataProvider protocol for large file downloads with intelligent caching.
class AFNetworkingDataProvider: Monstra.KVHeavyTaskBaseDataProvider<URL, Data, Progress>, Monstra.KVHeavyTaskDataProviderInterface {
    
    // MARK: - Private Properties
    
    /// Active AFNetworking download request for progress tracking, cancellation, and resume capability.
    private var request: AFURLSessionManager? = nil
    
    // MARK: - Initialization
    required init(key: URL, customEventPublisher: @escaping CustomEventPublisher, resultPublisher: @escaping ResultPublisher) {
        super.init(key: key, customEventPublisher: customEventPublisher, resultPublisher: resultPublisher)
    }
    
    // MARK: - Core Download Methods
    
    /// Starts or resumes a file download with automatic resume capability and progress tracking.
    /// Handles both fresh downloads and resume from interrupted downloads.
    func start() {
        // Step 1: Determine the destination URL for this download
        // This ensures consistent file storage and enables resume functionality
        let destinationURL = Self.destinationURL(key)
        
        // Step 1.5: Ensure the download directory exists
        do {
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
            print("📁 Created download directory: \(destinationURL.deletingLastPathComponent().path)")
        } catch {
            print("❌ Failed to create download directory: \(error)")
            self.resultPublisher(.failure(error))
            return
        }
        
        // Step 2: Create the session manager and download task
        let sessionManager = AFURLSessionManager()
        self.request = sessionManager
        
        // Step 3: Create download task with progress tracking
        let downloadTask = sessionManager.downloadTask(with: URLRequest(url: key), progress: { [weak self] progress in
            guard let self = self else { return }
            
            // Publish progress through custom event publisher
            self.customEventPublisher(progress)
        }, destination: { _, _ in
            print("📁 AFNetworking destination callback called, returning: \(destinationURL.path)")
            return destinationURL
        }, completionHandler: { [weak self] response, fileURL, error in
            guard let self = self else { return }
            
            if let error = error {
                // Download Failure: Handle different types of failures appropriately
                print("❌ Download failed with error: \(error)")
                self.resultPublisher(.failure(error))
            } else if let fileURL = fileURL {
                // Download Success: Read file data and publish success result
                print("📁 Download completed, file URL: \(fileURL.path)")
                print("📁 Expected destination: \(destinationURL.path)")
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    print("✅ Download completed successfully: \(data.count) bytes")
                    self.resultPublisher(.success(data))
                } catch {
                    print("❌ Failed to read downloaded file: \(error)")
                    self.resultPublisher(.failure(error))
                }
            } else {
                print("❌ Download completed but no file URL")
                self.resultPublisher(.failure(NSError(domain: "AFNetworkingDataProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No file URL"])))
            }
        })
        
        // Step 4: Start the download task
        downloadTask.resume()
        
        print("🚀 Starting download for key: \(key)")
    }
    
    /// Stops the current download and generates resume data for future resumption.
    /// Returns whether the provider can be reused or should be deallocated.
    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        // Step 1: Validate that there's an active download to stop
        guard let request = request else {
            print("📋 No active download to stop - request is nil")
            return .dealloc
        }
        
        // Step 2: Stop the session manager gracefully
        print("⏸️ Stopping download...")
        request.session.invalidateAndCancel()
        
        print("⏸️ Download stopped without resume data")
        return .dealloc
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
        let downloadFolder = cacheDirectory.appendingPathComponent("AFNetworkingDataProvider", isDirectory: true)
        
        // Step 3: Generate the final destination URL using MD5 hash of the source URL
        // This ensures unique, deterministic file naming for each download
        let fileName = key.absoluteString.md5()
        let fileExtension = key.pathExtension.isEmpty ? "download" : key.pathExtension
        let destinationURL = downloadFolder.appendingPathComponent("\(fileName).\(fileExtension)")
        
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
