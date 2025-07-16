//
//  LRUQueueVsNSCachePerformanceTests.swift
//  MonstoreTests
//
//  Created on 2024-12-19.
//

import XCTest
@testable import Monstore

final class LRUQueueVsNSCachePerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var lruQueue: PriorityLRUQueue<Int, String>!
    private var nsCache: NSCache<NSNumber, NSString>!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        lruQueue = PriorityLRUQueue<Int, String>(capacity: 1000)
        nsCache = NSCache<NSNumber, NSString>()
        nsCache.countLimit = 1000
    }
    
    override func tearDown() {
        lruQueue = nil
        nsCache = nil
        super.tearDown()
    }
    
    // MARK: - Insert Performance Tests
    
    func testInsertPerformance_LRUQueue() {
        measure {
            for i in 0..<1000 {
                lruQueue.setValue("value\(i)", for: i)
            }
        }
    }
    
    func testInsertPerformance_NSCache() {
        measure {
            for i in 0..<1000 {
                nsCache.setObject("value\(i)" as NSString, forKey: NSNumber(value: i))
            }
        }
    }
    
    // MARK: - Access Performance Tests
    
    func testAccessPerformance_LRUQueue() {
        // Pre-populate
        for i in 0..<1000 {
            lruQueue.setValue("value\(i)", for: i)
        }
        
        measure {
            for i in 0..<1000 {
                _ = lruQueue.getValue(for: i)
            }
        }
    }
    
    func testAccessPerformance_NSCache() {
        // Pre-populate
        for i in 0..<1000 {
            nsCache.setObject("value\(i)" as NSString, forKey: NSNumber(value: i))
        }
        
        measure {
            for i in 0..<1000 {
                _ = nsCache.object(forKey: NSNumber(value: i))
            }
        }
    }
    
    // MARK: - Mixed Operations Performance Tests
    
    func testMixedOperationsPerformance_LRUQueue() {
        measure {
            for i in 0..<1000 {
                lruQueue.setValue("value\(i)", for: i)
                if i % 3 == 0 {
                    _ = lruQueue.getValue(for: i - 1)
                }
                if i % 5 == 0 {
                    lruQueue.removeValue(for: i - 2)
                }
            }
        }
    }
    
    func testMixedOperationsPerformance_NSCache() {
        measure {
            for i in 0..<1000 {
                nsCache.setObject("value\(i)" as NSString, forKey: NSNumber(value: i))
                if i % 3 == 0 {
                    _ = nsCache.object(forKey: NSNumber(value: i - 1))
                }
                if i % 5 == 0 {
                    nsCache.removeObject(forKey: NSNumber(value: i - 2))
                }
            }
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsage_LRUQueue() {
        let initialMemory = getMemoryUsage()
        
        for i in 0..<10000 {
            lruQueue.setValue("value\(i)", for: i)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("LRUQueue memory increase: \(memoryIncrease) bytes")
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024) // Less than 10MB
    }
    
    func testMemoryUsage_NSCache() {
        let initialMemory = getMemoryUsage()
        
        for i in 0..<10000 {
            nsCache.setObject("value\(i)" as NSString, forKey: NSNumber(value: i))
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("NSCache memory increase: \(memoryIncrease) bytes")
        XCTAssertLessThan(memoryIncrease, 10 * 1024 * 1024) // Less than 10MB
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
} 
