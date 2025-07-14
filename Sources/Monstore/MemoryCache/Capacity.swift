//
//  Capacity.swift
//  Monstore
//
//  Created by Larkin on 2025/7/14.
//

import Foundation

struct Capacity {
    let maxMemoryUsage: Int // in MB
    let maxCount: Int

    static let zero: Self = .init(maxMemoryUsage: 0, maxCount: 0)
    static let max: Self = .init(maxMemoryUsage: .max, maxCount: .max)
    static func memoryUsage(_ value: Int) -> Self {
        .init(maxMemoryUsage: value, maxCount: .max)
    }
    static func count(_ value: Int) -> Self {
        .init(maxMemoryUsage: .max, maxCount: value)
    }
}

