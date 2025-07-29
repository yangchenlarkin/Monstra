//
//  KVHeavyTasksManagerTests.swift
//
//
//  Created by Larkin on 2025/7/29.
//

import XCTest
@testable import Monstask
@testable import MonstraBase
@testable import Monstore

extension KVHeavyTasksManagerTests {
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
}

final class KVHeavyTasksManagerTests: XCTestCase {
    func testSelf() {
        let expectation = XCTestExpectation(description: "5 steps and 1 result should callback")
        expectation.expectedFulfillmentCount = 6
        
        let taskHandler = DataProvider { key, progress in
            print(progress)
            expectation.fulfill()
        } resultCallback: { key, res in
            print(res)
            expectation.fulfill()
        }

        taskHandler.start(key: "12345")
        
        wait(for: [expectation])
    }
}
