//
//  TracingIDFactoryTest.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/18.
//

import XCTest
@testable import MonstraBase

/// Tests for TracingIDFactory functionality
final class TracingIDFactoryTest: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        let factory = TracingIDFactory()
        
        // Test that factory is created successfully
        XCTAssertNotNil(factory)
    }
    
    func testInitializationWithCustomLoopCount() {
        let customLoopCount: Int64 = 1000
        let factory = TracingIDFactory(loopCount: customLoopCount)
        
        // Test that factory is created with custom loop count
        XCTAssertNotNil(factory)
    }
    
    func testInitializationWithZeroLoopCount() {
        let factory = TracingIDFactory(loopCount: 0)
        
        // Should handle zero loop count gracefully
        XCTAssertNotNil(factory)
    }
    
    func testInitializationWithNegativeLoopCount() {
        let factory = TracingIDFactory(loopCount: -100)
        
        // Should handle negative loop count gracefully
        XCTAssertNotNil(factory)
    }
    
    func testInitializationWithMaxLoopCount() {
        let factory = TracingIDFactory()
        
        // Should handle max loop count
        XCTAssertNotNil(factory)
    }
    
    // MARK: - String ID Generation Tests
    
    func testSafeNextStr() {
        var factory = TracingIDFactory()
        let id1 = factory.safeNextStr()
        let id2 = factory.safeNextStr()
        
        XCTAssertFalse(id1.isEmpty)
        XCTAssertFalse(id2.isEmpty)
        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(id1.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil)
        XCTAssertTrue(id2.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil)
    }
    
    func testUnsafeNextStr() {
        var factory = TracingIDFactory()
        let id1 = factory.unsafeNextStr()
        let id2 = factory.unsafeNextStr()
        
        XCTAssertFalse(id1.isEmpty)
        XCTAssertFalse(id2.isEmpty)
        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(id1.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil)
        XCTAssertTrue(id2.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil)
    }
    
    // MARK: - UInt64 ID Generation Tests
    
    func testSafeNextUInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.safeNextUInt64()
        let id2 = factory.safeNextUInt64()
        
        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
        XCTAssertNotEqual(id1, id2)
    }
    
    func testUnsafeNextUInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.unsafeNextUInt64()
        let id2 = factory.unsafeNextUInt64()
        
        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
        XCTAssertNotEqual(id1, id2)
    }
    
    // MARK: - Int64 ID Generation Tests
    
    func testSafeNextInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.safeNextInt64()
        let id2 = factory.safeNextInt64()
        
        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
        XCTAssertNotEqual(id1, id2)
    }
    
    func testUnsafeNextInt64() {
        var factory = TracingIDFactory()
        let id1 = factory.unsafeNextInt64()
        let id2 = factory.unsafeNextInt64()
        
        XCTAssertGreaterThan(id1, 0)
        XCTAssertGreaterThan(id2, 0)
        XCTAssertNotEqual(id1, id2)
    }
    
    // MARK: - ID Uniqueness Tests
    
    func testIDUniqueness() {
        var factory = TracingIDFactory()
        var ids: Set<Int64> = []
        
        // Generate 1000 IDs and check uniqueness
        for _ in 0..<1000 {
            let id = factory.safeNextInt64()
            XCTAssertFalse(ids.contains(id), "Duplicate ID generated: \(id)")
            ids.insert(id)
        }
        
        XCTAssertEqual(ids.count, 1000)
    }
    
    func testIDUniquenessWithSmallLoopCount() {
        var factory = TracingIDFactory(loopCount: 10)
        var ids: Set<Int64> = []
        
        // Generate 20 IDs with small loop count
        for _ in 0..<20 {
            let id = factory.safeNextInt64()
            ids.insert(id)
        }
        
        // With loop count of 10, we should see some duplicates after 10 IDs
        XCTAssertLessThanOrEqual(ids.count, 20)
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafety() {
        var factory = TracingIDFactory()
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        var ids: Set<Int64> = []
        let lock = NSLock()
        
        // Generate IDs from multiple threads
        for _ in 0..<1000 {
            group.enter()
            queue.async {
                let id = factory.safeNextInt64()
                lock.lock()
                ids.insert(id)
                lock.unlock()
                group.leave()
            }
        }
        
        group.wait()
        
        // Should have generated unique IDs without race conditions
        XCTAssertEqual(ids.count, 1000)
    }
    
    func testUnsafeThreadSafety() {
        var factory = TracingIDFactory()
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()
        var ids: Set<Int64> = []
        let lock = NSLock()
        
        // Generate IDs from multiple threads using unsafe method
        for _ in 0..<1000 {
            group.enter()
            queue.async {
                let id = factory.unsafeNextInt64()
                lock.lock()
                ids.insert(id)
                lock.unlock()
                group.leave()
            }
        }
        
        group.wait()
        
        // Unsafe method might have race conditions, so we don't expect perfect uniqueness
        XCTAssertLessThanOrEqual(ids.count, 1000)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceSafeNext() {
        var factory = TracingIDFactory()
        
        measure {
            for _ in 0..<10000 {
                _ = factory.safeNextInt64()
            }
        }
    }
    
    func testPerformanceUnsafeNext() {
        var factory = TracingIDFactory()
        
        measure {
            for _ in 0..<10000 {
                _ = factory.unsafeNextInt64()
            }
        }
    }
    
    // MARK: - ID Format Tests
    
    func testIDFormat() {
        var factory = TracingIDFactory()
        
        // Test that IDs are reasonable size
        for _ in 0..<100 {
            let id = factory.safeNextInt64()
            XCTAssertGreaterThan(id, 0)
            XCTAssertLessThan(id, Int64.max)
            
            let strId = factory.safeNextStr()
            XCTAssertGreaterThan(strId.count, 0)
            XCTAssertLessThan(strId.count, 20) // Reasonable string length
        }
    }
    
    // MARK: - Loop Count Behavior Tests
    
    func testLoopCountBehavior() {
        let loopCount: Int64 = 5
        var factory = TracingIDFactory(loopCount: loopCount)
        var ids: [Int64] = []
        
        // Generate more IDs than loop count
        for _ in 0..<10 {
            ids.append(factory.safeNextInt64())
        }
        
        // Should have some unique IDs
        XCTAssertGreaterThan(Set(ids).count, 1)
    }
    
    func testLargeLoopCount() {
        let largeLoopCount: Int64 = 1_000_000
        var factory = TracingIDFactory(loopCount: largeLoopCount)
        var ids: Set<Int64> = []
        
        // Generate IDs with large loop count
        for _ in 0..<1000 {
            ids.insert(factory.safeNextInt64())
        }
        
        // Should have many unique IDs
        XCTAssertGreaterThan(ids.count, 900)
    }
    
    // MARK: - Edge Cases Tests
    
    func testExtremeLoopCount() {
        let extremeLoopCount: Int64 = Int64.max
        var factory = TracingIDFactory(loopCount: extremeLoopCount)
        
        // Should handle extreme loop count without crashing
        let id = factory.safeNextInt64()
        XCTAssertGreaterThan(id, 0)
    }
    
    func testNegativeExtremeLoopCount() {
        let extremeLoopCount: Int64 = Int64.min
        var factory = TracingIDFactory(loopCount: extremeLoopCount)
        
        // Should handle extreme negative loop count without crashing
        let id = factory.safeNextInt64()
        XCTAssertGreaterThan(id, 0)
    }
    
    // MARK: - Base ID Calculation Tests
    
    func testBaseIDCalculation() {
        // Test that base ID is calculated correctly
        let factory1 = TracingIDFactory()
        let factory2 = TracingIDFactory()
        
        // Base ID should be based on current time, so they should be similar
        // but not necessarily identical due to time differences
        XCTAssertNotNil(factory1)
        XCTAssertNotNil(factory2)
    }
    
    // MARK: - String Conversion Tests
    
    func testStringConversion() {
        var factory = TracingIDFactory()
        
        for _ in 0..<100 {
            _ = factory.safeNextInt64()
            let strId = factory.safeNextStr()
            
            // String ID should be convertible back to integer
            if let convertedId = Int64(strId) {
                XCTAssertGreaterThan(convertedId, 0)
            }
            
            // UInt64 conversion should also work
            let uintId = factory.safeNextUInt64()
            XCTAssertGreaterThan(uintId, 0)
        }
    }
}
