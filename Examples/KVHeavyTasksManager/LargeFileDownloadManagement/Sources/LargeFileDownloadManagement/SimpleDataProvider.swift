//
//  SimpleDataProvider.swift
//  LargeFileDownloadManagement
//
//  Created by Larkin on 2025/8/28.
//

import Foundation
import Monstra
import Alamofire
import CryptoKit

enum SimpleDataProviderEvent {
    case didStart
    case didFinish
}

/// A minimal, synchronous data provider demonstrating the
/// `KVHeavyTaskDataProviderInterface` contract with URL→Data.
///
/// Characteristics:
/// - Emits simple lifecycle events: `.didStart` and `.didFinish`
/// - Performs a blocking file/network read via `Data(contentsOf:)`
/// - Executes work on a background queue to avoid blocking the caller
/// - Thread-safety via a small `DispatchSemaphore`
///
/// Notes:
/// - This is intentionally simple for educational purposes. Real providers usually
///   use streaming APIs (such as URLSession/Alamofire) to support progress, resume,
///   cancellation, and better memory behavior.
class SimpleDataProvider: Monstra.KVHeavyTaskBaseDataProvider<URL, Data, SimpleDataProviderEvent>, Monstra.KVHeavyTaskDataProviderInterface {
    /// Lightweight lock protecting `isRunning` state transitions and result publication.
    let semaphore = DispatchSemaphore(value: 1)
    
    /// Tracks whether a job is currently executing. Toggling this value publishes
    /// simple lifecycle events so observers can react to start/finish.
    var isRunning = false {
        didSet {
            if isRunning {
                self.customEventPublisher(.didStart)
            } else {
                self.customEventPublisher(.didFinish)
            }
        }
    }
    
    /// Starts the provider work.
    ///
    /// Behavior:
    /// - Ensures only a single execution runs at a time
    /// - Dispatches the blocking read to a global background queue
    /// - Uses `.mappedIfSafe` to prefer memory-mapped I/O when possible
    /// - Publishes a single `Result` on completion
    ///
    /// Warning:
    /// - `Data(contentsOf:)` is blocking and may load the entire payload into memory.
    ///   Keep this as a teaching example; prefer streaming in production.
    func start() {
        // Protect against concurrent starts
        semaphore.wait()
        defer { semaphore.signal() }
        guard !isRunning else { return }
        isRunning = true
        
        DispatchQueue.global().async {
            // Perform the blocking read off the caller's thread
            let result: Result<Data?, Error>
            do {
                let res = try Data(contentsOf: self.key, options: .mappedIfSafe)
                result = .success(res)
            } catch(let error) {
                result = .failure(error)
            }
            
            // Publish exactly once if we haven't been stopped meanwhile
            self.semaphore.wait()
            defer { self.semaphore.signal() }
            guard self.isRunning else { return }
            self.isRunning = false
            self.resultPublisher(result)
        }
    }
    
    /// Attempts to stop the current work.
    ///
    /// Since this example uses a simple synchronous read dispatched to a background
    /// queue, we cannot truly cancel the in-flight `Data(contentsOf:)` call. We mark
    /// `isRunning = false` and return `.dealloc` to indicate the provider should be
    /// released. Real providers should implement true cancellation (such as
    /// `URLSessionTask.cancel()` or `DownloadRequest.cancel(byProducingResumeData:)`).
    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        self.semaphore.wait()
        defer { self.semaphore.signal() }
        guard self.isRunning else { return .dealloc }
        
        self.isRunning = false
        
        return .dealloc
    }
}
