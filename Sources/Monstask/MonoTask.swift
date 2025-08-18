//
//  MonoTask.swift
//  Monstra
//
//  Created by Larkin on 2025/8/18.
//

import Foundation
import MonstraBase

public class MonoTask<TaskResult> {
    private let retry: RetryCount
    private let resultExpireDuration: TimeInterval
    private let executeBlock: (@escaping ResultCallback)->Void
    private let taskQueue: DispatchQueue
    private let callbackQueue: DispatchQueue
    
    private var result: TaskResult? = nil
    private var resultExpiresAt: CPUTimeStamp = .zero
    private var resultSemaphore = DispatchSemaphore(value: 1)
    private var executionIDFactory = TracingIDFactory()
    private var executionID: Int64
    
    private var _callbacks: [ResultCallback]? = nil
    private var callbackSemaphore = DispatchSemaphore(value: 1)
    
    private init(retry: RetryCount, resultExpireDuration: Double, taskQueue: DispatchQueue, callbackQueue: DispatchQueue, executeBlock: @escaping (@escaping ResultCallback)->Void) {
        self.retry = retry
        self.resultExpireDuration = resultExpireDuration
        self.taskQueue = taskQueue
        self.callbackQueue = callbackQueue
        self.executeBlock = executeBlock
        self.executionID = self.executionIDFactory.safeNextInt64()
    }
    
    private func _safe_execute(then callback: ResultCallback?) {
        callbackSemaphore.wait()
        defer { callbackSemaphore.signal() }
        
        let isRunning = _callbacks != nil
        
        if _callbacks == nil {
            _callbacks = [ResultCallback]()
        }
        
        if let callback {
            _callbacks!.append(callback)
        }
        
        
        if !isRunning {
            _unsafe_execute(retry: retry)
        }
    }

    private func _unsafe_execute(retry count: RetryCount) {
        taskQueue.async { [weak self] in
            guard let self else { return }
            
            resultSemaphore.wait()
            if self.result != nil && self.resultExpiresAt > .now() {
                resultSemaphore.signal()
                _safe_callback(result: .success(self.result!))
                return
            }
            self.result = nil
            self.resultExpiresAt = .zero
            self.executionID = executionIDFactory.safeNextInt64()
            let executionID = self.executionID
            resultSemaphore.signal()
            
            self.executeBlock() { [weak self] result in
                guard let self else { return }
                
                //if success
                if case .success(let data) = result {
                    resultSemaphore.wait()
                    self.result = data
                    self.resultExpiresAt = .now() + self.resultExpireDuration
                    resultSemaphore.signal()
                    _safe_callback(result: result)
                    return
                }
                
                //else
                
                resultSemaphore.wait()
                if executionID != self.executionID {
                    resultSemaphore.signal()
                    return
                }
                if count.shouldRetry {
                    resultSemaphore.signal()
                    taskQueue.asyncAfter(deadline: .now() + count.timeInterval) {
                        self._unsafe_execute(retry: count.next())
                    }
                    return
                }
                resultSemaphore.signal()
                _safe_callback(result: result)
            }
        }
    }
    
    private func _safe_callback(result: Result<TaskResult, Error>) {
        callbackQueue.async {
            self.callbackSemaphore.wait()
            let _callbacks = self._callbacks
            self._callbacks = nil
            self.callbackSemaphore.signal()
            
            guard let _callbacks else { return }
            for callback in _callbacks {
                callback(result)
            }
        }
    }
}

public extension MonoTask {
    typealias ResultCallback = (Result<TaskResult, Error>)->Void
    typealias CallbackExecution = (@escaping ResultCallback)->Void
    typealias AsyncExecution = () async -> Result<TaskResult, Error>
    
    convenience init(retry: RetryCount = .never, resultExpireDuration: Double, taskQueue: DispatchQueue = DispatchQueue.global(), callbackQueue: DispatchQueue = DispatchQueue.global(), task: @escaping CallbackExecution) {
        self.init(retry: retry, resultExpireDuration: resultExpireDuration, taskQueue: taskQueue, callbackQueue: callbackQueue, executeBlock: task)
    }
    
    convenience init(retry: RetryCount = .never, resultExpireDuration: Double, taskQueue: DispatchQueue = DispatchQueue.global(), callbackQueue: DispatchQueue = DispatchQueue.global(), task: @escaping AsyncExecution) {
        self.init(retry: retry, resultExpireDuration: resultExpireDuration, taskQueue: taskQueue, callbackQueue: callbackQueue) { callback in
            Task {
                await callback(task())
            }
        }
    }
    
    func justExecute() {
        _safe_execute(then: nil)
    }
    
    func execute(then callback: ResultCallback?) {
        _safe_execute(then: callback)
    }
    
    @discardableResult
    func asyncExecute() async -> Result<TaskResult, Error> {
        return await withCheckedContinuation { continuation in
            self._safe_execute() { res in
                continuation.resume(returning: res)
            }
        }
    }
    
    @discardableResult
    func executeThrows() async throws -> TaskResult {
        switch await withCheckedContinuation({ continuation in
            self._safe_execute() { res in
                continuation.resume(returning: res)
            }
        }) {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }
    
    var currentResult: TaskResult? {
        resultSemaphore.wait()
        defer { resultSemaphore.signal() }
        if self.resultExpiresAt <= .now() {
            self.result = nil
            self.resultExpiresAt = .zero
        }
        return self.result
    }
    
    /// Strategy for handling ongoing execution when clearing cached results
    enum OngoingExecutionStrategy {
        /// Cancel the current execution and clear the result immediately
        case cancel
        /// Allow current execution to complete, then restart execution with fresh result
        case restart
        /// Allow current execution to complete but don't restart - just clear cached result
        case allowCompletion
    }
    enum Errors: Error {
        case cancelDueToResultClearting
    }
    /// Manually clear the cached result with different behaviors based on current execution state
    /// 
    /// This method provides manual cache invalidation with fine-grained control:
    /// - **If task is currently executing**: Follows the `ongoingExecutionStrategy` 
    /// - **If task is idle**: Follows the `restartWhenIdle` parameter (start new execution or not)
    /// 
    /// - Parameters:
    ///   - ongoingExecutionStrategy: Strategy to apply when there IS a running execution
    ///   - restartWhenIdle: Whether to start a new execution when there is NO running execution
    func clearResult(ongoingExecutionStrategy: OngoingExecutionStrategy = .allowCompletion) {
        resultSemaphore.wait()
        defer { resultSemaphore.signal() }

        self.result = nil
        self.resultExpiresAt = .zero
        
        if let _callbacks {
            // isExecuting
            switch ongoingExecutionStrategy {
            case .cancel:
                _callbacks.forEach { $0(.failure(Errors.cancelDueToResultClearting)) }
                self._callbacks = nil
            case .restart:
                self._unsafe_execute(retry: self.retry)
            case .allowCompletion:
                break
            }
        }
    }
    
    var isExecuting: Bool {
        get {
            self.callbackSemaphore.wait()
            defer { self.callbackSemaphore.signal() }
            return self._callbacks != nil
        }
    }
}
