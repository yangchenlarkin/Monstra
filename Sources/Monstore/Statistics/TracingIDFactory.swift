//
//  TracingIDFactory.swift
//  Monstore
//
//  Created by Larkin on 2025/7/18.
//

import Foundation

/// Interfaces
public extension TracingIDFactory {
    mutating func safeNextStr() -> String {
        String(_safe_next())
    }
    
    mutating func unsafeNextStr() -> String {
        String(_unsafe_next())
    }
    
    mutating func safeNextUInt64() -> UInt64 {
        return UInt64(self._safe_next())
    }
    
    mutating func unsafeNextUInt64() -> UInt64 {
        return UInt64(self._unsafe_next())
    }
    
    mutating func safeNextInt64() -> Int64 {
        return self._safe_next()
    }
    
    mutating func unsafeNextInt64() -> Int64 {
        return self._unsafe_next()
    }
}

public struct TracingIDFactory {
    //Int64.max = 9,223,372,036,854,775,807
    //a leap year has a maximum of 31,622,400 seconds.
    private static let MAX_BASE_ID: Int64 = 100_000_000
    public static let MAX_LOOP_COUNT: Int64 = 10_000_000_000
    
    private let loopCount: Int64
    private let trackingIDBase: Int64
    private var requestTrackingID: Int64 = 0
    
    public init(loopCount: Int64 = Self.MAX_LOOP_COUNT) {
        let loopCount = max(0, min(loopCount, Self.MAX_LOOP_COUNT))
        self.loopCount = loopCount <= 0 ? loopCount + Self.MAX_LOOP_COUNT : loopCount
        
        self.trackingIDBase = {
            let timeIntervalSince1970 = Int64(Date().timeIntervalSince1970)
            
            let now = Date()
            let calendar = Calendar.current
            guard let utcTimeZone = TimeZone(identifier: "UTC") else {
                return timeIntervalSince1970 % Self.MAX_BASE_ID // no more than 8 digits
            }
            var calendarUTC = calendar
            calendarUTC.timeZone = utcTimeZone

            // 获取当前年份（UTC时区）
            let currentYear = calendarUTC.component(.year, from: now)

            // 创建当前年初时间点（UTC时区）
            let dateComponents = DateComponents(
                timeZone: utcTimeZone,
                year: currentYear,
                month: 1,
                day: 1,
                hour: 0,
                minute: 0,
                second: 0
            )
            guard let startOfYear = calendarUTC.date(from: dateComponents) else {
                return timeIntervalSince1970 % Self.MAX_BASE_ID // no more than 8 digits
            }

            // 计算时间间隔并转换为Int64（秒）
            let timeIntervalSinceStartOfYear = Int64(now.timeIntervalSince(startOfYear))
            return timeIntervalSinceStartOfYear % Self.MAX_BASE_ID // no more than 8 digits
        }()
    }
    
    // calculator
    private var lock = os_unfair_lock()
    private mutating func _unsafe_next() -> Int64 {
        defer {
            // less than self.loopCount
            self.requestTrackingID = (self.requestTrackingID + 1) % self.loopCount
        }
        return self.requestTrackingID + self.trackingIDBase * self.loopCount
    }
    private mutating func _safe_next() -> Int64 {
        os_unfair_lock_lock(&self.lock)
        defer {
            os_unfair_lock_unlock(&self.lock)
        }
        return _unsafe_next()
    }
}
