//
//  LRUQueueWithTTLVsNSCachePerformanceTests.swift
//  MonstoreTests
//
//  Created on 2024-12-19.
//

import XCTest
@testable import Monstore

final class LRUQueueWithTTLVsNSCachePerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var lruQueueWithTTL: LRUQueueWithTTL<Int, String>!
    private var nsCache: NSCache<NSNumber, NSString>!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        lruQueueWithTTL = LRUQueueWithTTL<Int, String>(capacity: 1000)
        nsCache = NSCache<NSNumber, NSString>()
        nsCache.countLimit = 1000
    }
    
    override func tearDown() {
        lruQueueWithTTL = nil
        nsCache = nil
        super.tearDown()
    }
    
    // MARK: - Insert Performance Tests
    
    func testInsertPerformance_LRUQueueWithTTL() {
        measure {
            for i in 0..<1000 {
                lruQueueWithTTL.unsafeSet(value: "value\(i)", for: i, expiredIn: 60.0)
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
    
    func testAccessPerformance_LRUQueueWithTTL() {
        // Pre-populate
        for i in 0..<1000 {
            lruQueueWithTTL.unsafeSet(value: "value\(i)", for: i, expiredIn: 60.0)
        }
        
        measure {
            for i in 0..<1000 {
                _ = lruQueueWithTTL.getValue(for: i)
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
    
    // MARK: - TTL Expiration Tests
    
    func testTTLExpirationPerformance_LRUQueueWithTTL() {
        // Insert items with short TTL
        for i in 0..<1000 {
            lruQueueWithTTL.unsafeSet(value: "value\(i)", for: i, expiredIn: 0.001) // 1ms TTL
        }
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: 0.002)
        
        measure {
            for i in 0..<1000 {
                _ = lruQueueWithTTL.getValue(for: i)
            }
        }
    }
    
    func testTTLExpirationPerformance_NSCache() {
        // NSCache doesn't have built-in TTL, so we'll simulate with manual cleanup
        measure {
            for i in 0..<1000 {
                nsCache.setObject("value\(i)" as NSString, forKey: NSNumber(value: i))
            }
            nsCache.removeAllObjects()
        }
    }
    
    // MARK: - Mixed Operations Performance Tests
    
    func testMixedOperationsPerformance_LRUQueueWithTTL() {
        measure {
            for i in 0..<1000 {
                lruQueueWithTTL.unsafeSet(value: "value\(i)", for: i, expiredIn: 60.0)
                if i % 3 == 0 {
                    _ = lruQueueWithTTL.getValue(for: i - 1)
                }
                if i % 5 == 0 {
                    lruQueueWithTTL.unsafeRemoveValue(for: i - 2)
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
    
    // MARK: - Cleanup Performance Tests
    
    func testCleanupPerformance_LRUQueueWithTTL() {
        // Insert items with varying TTLs
        for i in 0..<1000 {
            let ttl = Double(i % 10) * 0.001 // 0-9ms TTL
            lruQueueWithTTL.unsafeSet(value: "value\(i)", for: i, expiredIn: ttl)
        }
        
        // Wait for some items to expire
        Thread.sleep(forTimeInterval: 0.005)
        
        measure {
            // Manual cleanup by checking each item
            for i in 0..<1000 {
                _ = lruQueueWithTTL.getValue(for: i)
            }
        }
    }
    
    func testCleanupPerformance_NSCache() {
        // Pre-populate
        for i in 0..<1000 {
            nsCache.setObject("value\(i)" as NSString, forKey: NSNumber(value: i))
        }
        
        measure {
            nsCache.removeAllObjects()
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsage_LRUQueueWithTTL() {
        let initialMemory = getMemoryUsage()
        
        for i in 0..<10000 {
            lruQueueWithTTL.unsafeSet(value: "value\(i)", for: i, expiredIn: 60.0)
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        print("LRUQueueWithTTL memory increase: \(memoryIncrease) bytes")
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
    
    // MARK: - TTL Management Tests
    
    func testTTLManagement_LRUQueueWithTTL() {
        let iterations = 1000
        var totalTime: TimeInterval = 0
        
        measure {
            for i in 0..<iterations {
                let start = Date()
                lruQueueWithTTL.unsafeSet(value: "value\(i)", for: i, expiredIn: Double(i % 100) / 1000.0)
                let end = Date()
                totalTime += end.timeIntervalSince(start)
            }
        }
        
        print("Average TTL setting time: \(totalTime / Double(iterations)) seconds")
    }
    
    func testTTLExpirationAccuracy_LRUQueueWithTTL() {
        let testKey = 999
        let ttl = 0.1 // 100ms
        
        lruQueueWithTTL.unsafeSet(value: "test", for: testKey, expiredIn: ttl)
        
        // Should be available immediately
        XCTAssertNotNil(lruQueueWithTTL.getValue(for: testKey))
        
        // Wait for expiration
        Thread.sleep(forTimeInterval: ttl + 0.01)
        
        // Should be expired
        XCTAssertNil(lruQueueWithTTL.getValue(for: testKey))
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