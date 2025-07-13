//
//  LRUQueueWithTTL.swift
//  Monstore
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

class LRUQueueWithTTL<Key: Hashable, Value> {
    let capacity: Int
    fileprivate var ttlQueue: Heap<Node>
    fileprivate var lruQueue: LRUQueue<Key, Node>
    
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
        lruQueue = LRUQueue(capacity: capacity)
        
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

extension LRUQueueWithTTL {
    func unsafeSet(value: Value, for key: Key, expiredIn duration: TimeInterval) -> Value? {
        let now = CPUTimeStamp.now()

        // Check if the key already exists in the LRU queue
        if let existing = lruQueue._getValue(for: key) {
            // If the existing entry has expired, remove it and insert the new value into the TTL heap
            if existing.expirationTimeStamp < now {
                _ = unsafeRemoveValue(for: key)
                return unsafeSetToTTLQueue(now: now, value: value, for: key, expiredIn: duration)
            } else {
                // If the existing entry is still valid, update its position in the LRU queue
                return unsafeSetToLRUQueue(now: now, value: value, for: key, expiredIn: duration)
            }
        } else {
            // If the key does not exist, check if the TTL heap root has expired
            if let ttlRoot = ttlQueue.root?.expirationTimeStamp, ttlRoot < now {
                // If the root of TTL heap is expired, insert into the TTL heap
                return unsafeSetToTTLQueue(now: now, value: value, for: key, expiredIn: duration)
            }
            // Otherwise, insert into the LRU queue
            return unsafeSetToLRUQueue(now: now, value: value, for: key, expiredIn: duration)
        }
    }
    
    func getValue(for key: Key) -> Value? {
        guard let node = lruQueue._getValue(for:key) else { return nil }
        if node.expirationTimeStamp < .now() {
            _=unsafeRemoveValue(for: key)
            return nil
        }
        return node.value
    }
    
    func unsafeRemoveValue(for key: Key) -> Value? {
        if let node = lruQueue._removeValue(for: key) {
            if let nodeIndex = node.ttlIndex {
                _=ttlQueue.remove(at: nodeIndex)
                return node.value
            }
            return node.value
        }
        return nil
    }
}

private extension LRUQueueWithTTL {
    func unsafeSetToTTLQueue(now: CPUTimeStamp, value: Value, for key: Key, expiredIn duration: TimeInterval) -> Value? {
        var res: Value? = nil
        let node = Node(key: key, value: value, expirationTimeStamp: now + duration)
        if let pop = ttlQueue.insert(node, force: true) {
            _=lruQueue._removeValue(for: pop.key)
            res = pop.value
        }
        _=lruQueue._setValue(node, for: key)
        return res
    }
    
    func unsafeSetToLRUQueue(now: CPUTimeStamp, value: Value, for key: Key, expiredIn duration: TimeInterval) -> Value? {
        var res: Value? = nil
        let node = Node(key: key, value: value, expirationTimeStamp: now + duration)
        if let pop = lruQueue._setValue(node, for: key), let ttlIndex = pop.ttlIndex {
            _=ttlQueue.remove(at: ttlIndex)
            res = pop.value
        }
        _=ttlQueue.insert(node, force: true)
        return res
    }
}

private extension LRUQueueWithTTL {
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
