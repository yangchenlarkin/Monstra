//
//  TTLPriorityLRUQueue.swift
//  Monstore
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

class TTLPriorityLRUQueue<Key: Hashable, Value> {
    let capacity: Int
    fileprivate var ttlQueue: Heap<Node>
    fileprivate var lruQueue: PriorityLRUQueue<Key, Node>
    
    /// Indicates if the queue is empty.
    var isEmpty: Bool { lruQueue.isEmpty }
    /// Indicates if the queue is full.
    var isFull: Bool { lruQueue.isFull }
    var count: Int { lruQueue.count}
    
    /// Initializes a new empty queue with specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values treated as zero.
    init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
        ttlQueue = .init(capacity: capacity, compare: { n1, n2 in
            switch true {
            case n1.expirationTimeStamp < n2.expirationTimeStamp:
                return .moreTop
            case n1.expirationTimeStamp > n2.expirationTimeStamp:
                return .moreBottom
            default:
                return .equal
            }
        })
        lruQueue = PriorityLRUQueue(capacity: capacity)
        
        ttlQueue.onEvent = {
            switch $0 {
            case .insert(let element, let at):
                element.ttlIndex = at
            case .remove(let element):
                element.ttlIndex = nil
            case .move(let element, let to):
                element.ttlIndex = to
            }
        }
    }
}

extension TTLPriorityLRUQueue {
    @discardableResult
    func set(value: Value, for key: Key, priority: Double = .zero, expiredIn duration: TimeInterval = .infinity) -> Value? {
        let now = CPUTimeStamp.now()
        // Check if the key already exists in the LRU queue
        if removeValue(for: key) != nil {
            return setToLRUQueue(now: now, value: value, for: key, priority: priority, expiredIn: duration)
        } else {
            // If the key does not exist, check if the TTL heap root has expired
            if let ttlRoot = ttlQueue.root?.expirationTimeStamp, ttlRoot < now {
                // If the root of TTL heap is expired, insert into the TTL heap
                return setToTTLQueue(now: now, value: value, for: key, priority: priority, expiredIn: duration)
            }
            // Otherwise, insert into the LRU queue
            return setToLRUQueue(now: now, value: value, for: key, priority: priority, expiredIn: duration)
        }
    }
    
    func getValue(for key: Key) -> Value? {
        guard let node = lruQueue.getValue(for:key) else { return nil }
        if node.expirationTimeStamp < .now() {
            _=removeValue(for: key)
            return nil
        }
        return node.value
    }
    
    func removeValue(for key: Key) -> Value? {
        if let node = lruQueue.removeValue(for: key) {
            if let nodeIndex = node.ttlIndex {
                _=ttlQueue.remove(at: nodeIndex)
                return node.value
            }
            return node.value
        }
        return nil
    }
}

private extension TTLPriorityLRUQueue {
    func setToTTLQueue(now: CPUTimeStamp, value: Value, for key: Key, priority: Double, expiredIn duration: TimeInterval) -> Value? {
        var res: Value? = nil
        let node = Node(key: key, value: value, expirationTimeStamp: now + duration)
        if let pop = ttlQueue.insert(node, force: true) {
            _=lruQueue.removeValue(for: pop.key)
            res = pop.value
        }
        _=lruQueue.setValue(node, for: key, with: priority)
        return res
    }
    
    func setToLRUQueue(now: CPUTimeStamp, value: Value, for key: Key, priority: Double, expiredIn duration: TimeInterval) -> Value? {
        var res: Value? = nil
        let node = Node(key: key, value: value, expirationTimeStamp: now + duration)
        if let pop = lruQueue.setValue(node, for: key, with: priority), let ttlIndex = pop.ttlIndex {
            _=ttlQueue.remove(at: ttlIndex)
            res = pop.value
        }
        _=ttlQueue.insert(node, force: true)
        return res
    }
}

private extension TTLPriorityLRUQueue {
    class Node {
        let key: Key
        let value: Value
        let expirationTimeStamp: CPUTimeStamp
        
        var ttlIndex: Int?
        
        init(key: Key, value: Value, expirationTimeStamp: CPUTimeStamp) {
            self.key = key
            self.value = value
            self.expirationTimeStamp = expirationTimeStamp
            self.ttlIndex = nil
        }
    }
}
