//
//  ArrayBasedLRUQueueTests.swift
//  MonstoreTests
//
//  Created by Larkin on 2025/7/12.
//

import XCTest
@testable import Monstore

final class ArrayBasedLRUQueueTests: LRUQueueProtocolTests<ArrayBasedLRUQueue<String, Int>> {
    override func createQueue(capacity: Int) -> ArrayBasedLRUQueue<String, Int> {
        ArrayBasedLRUQueue(capacity: capacity)
    }
}
