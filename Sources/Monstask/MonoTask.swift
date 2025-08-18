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
    private let taskQueue: DispatchQueue?
    private let callbackQueue: DispatchQueue?
    
    private var result: TaskResult? = nil
    private var resultExpiresAt: CPUTimeStamp = .zero
    private var resultSemaphore = DispatchSemaphore(value: 1)
    
    private var _callbacks: [ResultCallback]? = nil
    private var callbackSemaphore = DispatchSemaphore(value: 1)
    
    private func _safe_callback(result: Result<TaskResult, Error>) {
        let callback = {
            self.callbackSemaphore.wait()
            let _callbacks = self._callbacks
            self._callbacks = nil
            self.callbackSemaphore.signal()
            
            guard let _callbacks else { return }
            for callback in _callbacks {
                callback(result)
            }
        }
        
        guard let callbackQueue else {
            callback()
            return
        }
        callbackQueue.async(execute: callback)
    }

    private func _unsafe_execute(retry count: RetryCount) {
        let block = { [weak self] in
            guard let self else { return }
            
            resultSemaphore.wait()
            if self.result != nil && self.resultExpiresAt > .now() {
                resultSemaphore.signal()
                _safe_callback(result: .success(self.result!))
                return
            }
            self.result = nil
            self.resultExpiresAt = .zero
            resultSemaphore.signal()
            
            self.executeBlock() { [weak self] result in
                guard let self else { return }
                
                //if success
                if case .success(let data) = result {
                    self.result = data
                    self.resultExpiresAt = .now() + self.resultExpireDuration
                    _safe_callback(result: result)
                    return
                }
                
                //else
                if count.shouldRetry {
                    let queue: DispatchQueue
                    if let taskQueue {
                        queue = taskQueue
                    } else {
                        if Thread.current.isMainThread {
                            queue = DispatchQueue.main
                        } else {
                            queue = DispatchQueue.global()
                        }
                    }
                    
                    queue.asyncAfter(deadline: .now() + count.timeInterval) {
                        self._unsafe_execute(retry: count.next())
                    }
                } else {
                    _safe_callback(result: result)
                }
            }
        }
        
        guard let taskQueue else {
            block()
            return
        }
        taskQueue.async(execute: block)
    }
    
    private init(retry: RetryCount, resultExpireDuration: Double, taskQueue: DispatchQueue?, callbackQueue: DispatchQueue?, executeBlock: @escaping (@escaping ResultCallback)->Void) {
        self.retry = retry
        self.resultExpireDuration = resultExpireDuration
        self.taskQueue = taskQueue
        self.callbackQueue = callbackQueue
        self.executeBlock = executeBlock
    }
    
    private func _safe_execute(then callback: ResultCallback?) {
        callbackSemaphore.wait()
        
        let isRunning = _callbacks != nil
        
        if _callbacks == nil {
            _callbacks = [ResultCallback]()
        }
        
        if let callback {
            _callbacks!.append(callback)
        }
        
        callbackSemaphore.signal()
        
        if !isRunning {
            _unsafe_execute(retry: retry)
        }
    }
}

public extension MonoTask {
    typealias ResultCallback = (Result<TaskResult, Error>)->Void
    typealias CallbackExecution = (@escaping ResultCallback)->Void
    typealias AsyncExecution = () async -> Result<TaskResult, Error>
    
    convenience init(retry: RetryCount = .never, resultExpireDuration: Double, taskQueue: DispatchQueue? = DispatchQueue.global(), callbackQueue: DispatchQueue? = DispatchQueue.global(), task: @escaping CallbackExecution) {
        self.init(retry: retry, resultExpireDuration: resultExpireDuration, taskQueue: taskQueue, callbackQueue: callbackQueue, executeBlock: task)
    }
    
    convenience init(retry: RetryCount = .never, resultExpireDuration: Double, taskQueue: DispatchQueue? = DispatchQueue.global(), callbackQueue: DispatchQueue? = DispatchQueue.global(), task: @escaping AsyncExecution) {
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
    
    var isExecuting: Bool {
        get {
            self.callbackSemaphore.wait()
            defer { self.callbackSemaphore.signal() }
            return self._callbacks != nil
        }
    }
}
