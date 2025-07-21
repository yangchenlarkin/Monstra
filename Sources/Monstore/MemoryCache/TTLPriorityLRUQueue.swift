//
//  TTLPriorityLRUQueue.swift
//  Monstore
//
//  Created by Larkin on 2025/5/8.
//

import Foundation
import MonstraBase

/// A cache that combines TTL (time-to-live), priority, and LRU (least recently used) eviction policies.
///
/// - Each entry has an expiration time (TTL), a priority, and is tracked for recency of use.
/// - When the cache is full, expired entries are evicted first, then lower-priority entries, then least recently used.
/// - Provides O(1) average case for access and update by key, with efficient expiration and eviction.
public class TTLPriorityLRUQueue<Key: Hashable, Element> {
    /// The maximum number of elements the cache can hold.
    public let capacity: Int
    /// Heap for managing TTL expiration order.
    fileprivate var ttlQueue: Heap<Node>
    /// Priority-based LRU queue for managing eviction order.
    fileprivate var lruQueue: PriorityLRUQueue<Key, Node>
    
    /// Returns true if the cache is empty.
    public var isEmpty: Bool { lruQueue.isEmpty }
    /// Returns true if the cache is full.
    public var isFull: Bool { lruQueue.isFull }
    /// The current number of elements in the cache.
    public var count: Int { lruQueue.count}
    
    /// Initializes a new empty cache with the specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values are treated as zero.
    public init(capacity: Int) {
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

public extension TTLPriorityLRUQueue {
    /// Inserts or updates a element for the given key, with optional priority and TTL.
    /// - Parameters:
    ///   - element: The element to store.
    ///   - key: The key to associate with the element.
    ///   - priority: The priority for eviction (higher is less likely to be evicted).
    ///   - duration: The TTL (in seconds) for the entry. Defaults to infinity (never expires).
    /// - Returns: The evicted element, if any.
    @discardableResult
    func set(element: Element, for key: Key, priority: Double = .zero, expiredIn duration: TimeInterval = .infinity) -> Element? {
        let now = CPUTimeStamp.now()
        // Check if the key already exists in the LRU queue
        if removeElement(for: key) != nil {
            return setToLRUQueue(now: now, element: element, for: key, priority: priority, expiredIn: duration)
        } else {
            // If the key does not exist, check if the TTL heap root has expired
            if let ttlRoot = ttlQueue.root?.expirationTimeStamp, ttlRoot < now {
                // If the root of TTL heap is expired, insert into the TTL heap
                return setToTTLQueue(now: now, element: element, for: key, priority: priority, expiredIn: duration)
            }
            // Otherwise, insert into the LRU queue
            return setToLRUQueue(now: now, element: element, for: key, priority: priority, expiredIn: duration)
        }
    }
    
    /// Retrieves the element for the given key if present and not expired.
    /// - Parameter key: The key to look up.
    /// - Returns: The element if present and valid, or nil if expired or missing.
    @discardableResult
    func getElement(for key: Key) -> Element? {
        guard let node = lruQueue.getElement(for:key) else { return nil }
        if node.expirationTimeStamp < .now() {
            _=removeElement(for: key)
            return nil
        }
        return node.element
    }
    
    /// Removes the element for the given key, if present.
    /// - Parameter key: The key to remove.
    /// - Returns: The removed element, or nil if not found.
    @discardableResult
    func removeElement(for key: Key) -> Element? {
        if let node = lruQueue.removeElement(for: key) {
            if let nodeIndex = node.ttlIndex {
                _=ttlQueue.remove(at: nodeIndex)
                return node.element
            }
            return node.element
        }
        return nil
    }
    
    /// Removes and returns the least recently used element.
    /// - Returns: The removed element, or nil if cache is empty
    @discardableResult
    func removeElement() -> Element? {
        guard let root = ttlQueue.root else { return nil }
        
        if root.expirationTimeStamp < .now() {
            return removeElement(for: root.key)
        }
        
        // Get the least recently used key from the LRU queue
        guard let leastRecentKey = lruQueue.getLeastRecentKey() else { return nil }
        return removeElement(for: leastRecentKey)
    }
    
    /**
     Removes all expired elements from the cache.
     
     This method iterates through the TTL queue and removes all entries that have expired
     based on their expiration timestamps. The removal is done efficiently by checking
     the root of the TTL heap, which contains the earliest expiring entry.
     
     - Note: This operation has O(n) time complexity where n is the number of expired entries
     */
    func removeExpiredElements() {
        while let root = ttlQueue.root {
            if root.expirationTimeStamp >= .now() {
                return
            }
            removeElement(for: root.key)
        }
    }
}

private extension TTLPriorityLRUQueue {
    /// Internal: Insert into TTL heap and update LRU queue.
    func setToTTLQueue(now: CPUTimeStamp, element: Element, for key: Key, priority: Double, expiredIn duration: TimeInterval) -> Element? {
        var res: Element? = nil
        let node = Node(key: key, element: element, expirationTimeStamp: now + duration)
        if let pop = ttlQueue.insert(node, force: true) {
            _=lruQueue.removeElement(for: pop.key)
            res = pop.element
        }
        _=lruQueue.setElement(node, for: key, with: priority)
        return res
    }
    /// Internal: Insert into LRU queue and update TTL heap.
    func setToLRUQueue(now: CPUTimeStamp, element: Element, for key: Key, priority: Double, expiredIn duration: TimeInterval) -> Element? {
        var res: Element? = nil
        let node = Node(key: key, element: element, expirationTimeStamp: now + duration)
        if let pop = lruQueue.setElement(node, for: key, with: priority), let ttlIndex = pop.ttlIndex {
            _=ttlQueue.remove(at: ttlIndex)
            res = pop.element
        }
        _=ttlQueue.insert(node, force: true)
        return res
    }
}

private extension TTLPriorityLRUQueue {
    /// Internal node type for tracking key, element, expiration, and heap index.
    class Node {
        /// The key for this entry.
        let key: Key
        /// The element for this entry.
        let element: Element
        /// The expiration timestamp for this entry.
        let expirationTimeStamp: CPUTimeStamp
        /// The index of this node in the TTL heap, if present.
        var ttlIndex: Int?
        
        init(key: Key, element: Element, expirationTimeStamp: CPUTimeStamp) {
            self.key = key
            self.element = element
            self.expirationTimeStamp = expirationTimeStamp
            self.ttlIndex = nil
        }
    }
}
