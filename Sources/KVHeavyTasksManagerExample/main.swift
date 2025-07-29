#!/usr/bin/env swift

import Foundation
import Monstask
import MonstraBase

@propertyWrapper
struct SemaphoreProtected<Value> {
    private let semaphore = DispatchSemaphore(value: 1)
    private var value: Value
    
    init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    var wrappedValue: Value {
        get {
            semaphore.wait()
            defer { semaphore.signal() }
            return value
        }
        set {
            semaphore.wait()
            defer { semaphore.signal() }
            value = newValue
        }
    }
}

class DataProvider: Monstask.KVHeavyTaskDataProvider {
    typealias T = UInt
    typealias K = String
    typealias Element = String
    
    let progressCallback: ProgressCallback?
    let resultCallback: ResultCallback
    
    required init(progressCallback: ProgressCallback?, resultCallback: @escaping ResultCallback) {
        self.progressCallback = progressCallback
        self.resultCallback = resultCallback
    }
    
    @SemaphoreProtected
    private var isCancelled = false
    
    @SemaphoreProtected
    private var isPasued = false
    
    func start(key: String) {
        isCancelled = false
        
        var res = ""
        for c in key {
            if isCancelled {
                resultCallback(key, .cancel)
                return
            }
            Thread.sleep(forTimeInterval: 1)
            res.append(c)
            progressCallback?(key, .init(totalUnitCount: UInt(key.count), completedUnitCount: UInt(res.count)))
        }
        resultCallback(key, .success(res))
    }
    
    func cancel() {
        isCancelled = true
    }
    
    func pause() {
        isPasued = true
    }
    
    func resume() {
        isPasued = false
    }
}

func main() {
    let taskHandler = DataProvider { key, progress in
        print(progress)
    } resultCallback: { key, res in
        print(res)
    }

    taskHandler.start(key: "12345")
}

main()

RunLoop.main.run()
