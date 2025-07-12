//
//  DoublyLinkedLRUQueueTests.swift
//
//  Created by Larkin on 2025/5/9.
//

import XCTest
@testable import Monstore

final class DoublyLinkedLRUQueueTests: LRUQueueProtocolTests<DoublyLinkedLRUQueue<String, Int>> {
    override func createQueue(capacity: Int) -> DoublyLinkedLRUQueue<String, Int> {
        DoublyLinkedLRUQueue(capacity: capacity)
    }
    // 如有 DoublyLinkedLRUQueue 特有测试可在此添加
}
