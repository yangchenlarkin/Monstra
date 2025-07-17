//
//  TTLPriorityLRUQueue.swift
//  Monstore
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

/// A cache that combines TTL (time-to-live), priority, and LRU (least recently used) eviction policies.
///
/// - Each entry has an expiration time (TTL), a priority, and is tracked for recency of use.
/// - When the cache is full, expired entries are evicted first, then lower-priority entries, then least recently used.
/// - Provides O(1) access and update for keys, and efficient expiration and eviction.
class TTLPriorityLRUQueue<Key: Hashable, Value> {
    /// The maximum number of elements the cache can hold.
    let capacity: Int
    /// Heap for managing TTL expiration order.
    fileprivate var ttlQueue: Heap<Node>
    /// Priority-based LRU queue for managing eviction order.
    fileprivate var lruQueue: PriorityLRUQueue<Key, Node>
    
    /// Returns true if the cache is empty.
    var isEmpty: Bool { lruQueue.isEmpty }
    /// Returns true if the cache is full.
    var isFull: Bool { lruQueue.isFull }
    /// The current number of elements in the cache.
    var count: Int { lruQueue.count}
    
    /// Initializes a new empty cache with the specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values are treated as zero.
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
    /// Inserts or updates a value for the given key, with optional priority and TTL.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key to associate with the value.
    ///   - priority: The priority for eviction (higher is less likely to be evicted).
    ///   - duration: The TTL (in seconds) for the entry. Defaults to infinity (never expires).
    /// - Returns: The evicted value, if any.
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
    
    /// Retrieves the value for the given key if present and not expired.
    /// - Parameter key: The key to look up.
    /// - Returns: The value if present and valid, or nil if expired or missing.
    func getValue(for key: Key) -> Value? {
        guard let node = lruQueue.getValue(for:key) else { return nil }
        if node.expirationTimeStamp < .now() {
            _=removeValue(for: key)
            return nil
        }
        return node.value
    }
    
    /// Removes the value for the given key, if present.
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or nil if not found.
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
    /// Internal: Insert into TTL heap and update LRU queue.
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
    /// Internal: Insert into LRU queue and update TTL heap.
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
    /// Internal node type for tracking key, value, expiration, and heap index.
    class Node {
        /// The key for this entry.
        let key: Key
        /// The value for this entry.
        let value: Value
        /// The expiration timestamp for this entry.
        let expirationTimeStamp: CPUTimeStamp
        /// The index of this node in the TTL heap, if present.
        var ttlIndex: Int?
        
        init(key: Key, value: Value, expirationTimeStamp: CPUTimeStamp) {
            self.key = key
            self.value = value
            self.expirationTimeStamp = expirationTimeStamp
            self.ttlIndex = nil
        }
    }
}
