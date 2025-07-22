//
//  KeyQueue.swift
//  Monstask
//
//  Created by Larkin on 2025/7/21.
//

import Foundation
import MonstraBase

/**
 A high-performance key-based queue that maintains insertion order with O(1) access and removal operations.
 
 ## Core Features
 
 - **Key-Based Operations**: All operations are performed using keys, providing intuitive access patterns
 - **LRU (Least Recently Used) Management**: Recently accessed keys are moved to the front of the queue
 - **O(1) Performance**: Constant time complexity for enqueue, dequeue, and removal operations
 - **Capacity Management**: Configurable capacity with automatic eviction of least recently used keys
 - **Duplicate Key Handling**: Re-inserting an existing key moves it to the front (LRU behavior)
 
 ## Data Structure
 
 The queue uses a combination of:
 - **Doubly Linked List**: Maintains insertion order and provides O(1) front/back operations
 - **Hash Map**: Provides O(1) key-to-node lookup for efficient access and removal
 
 ## Performance Characteristics
 
 - **Time Complexity**: O(1) average case for all operations
 - **Space Complexity**: O(n) where n is the number of keys
 - **Memory Efficiency**: Automatic eviction when capacity is exceeded
 - **Thread Safety**: Not thread-safe; caller must ensure thread safety if needed
 
 ## Example Usage
 
 ```swift
 // Create a key queue with capacity of 100
 let queue = KeyQueue<String>(capacity: 100)
 
 // Enqueue keys (moves to front if already exists)
 queue.enqueueFront(key: "task1")
 queue.enqueueFront(key: "task2")
 queue.enqueueFront(key: "task1") // Moves "task1" to front
 
 // Dequeue from front (most recently used)
 let mostRecent = queue.dequeueFront() // Returns "task1"
 
 // Dequeue from back (least recently used)
 let leastRecent = queue.dequeueBack() // Returns "task2"
 
 // Remove specific key
 queue.remove(key: "task3")
 ```
 */

/// A key-based queue that maintains insertion order with LRU (Least Recently Used) behavior.
/// Provides O(1) operations for enqueue, dequeue, and removal by key.
public class KeyQueue<K: Hashable> {
    /// The underlying doubly linked list that maintains the queue order.
    private let link: DoublyLink<K>
    /// Hash map for O(1) key-to-node lookup.
    private var map: [K: DoublyLink<K>.Node]
    
    /// Initializes a new empty key queue with specified capacity.
    /// - Parameter capacity: Maximum number of keys allowed in the queue.
    ///   Negative values are treated as zero.
    public init(capacity: Int) {
        self.link = .init(with: capacity)
        self.map = .init()
    }
    
    /// Enqueues a key at the front of the queue (most recently used position).
    /// If the key already exists, it is moved to the front (LRU behavior).
    /// - Parameter key: The key to enqueue.
    public func enqueueFront(key: K) {
        let node: DoublyLink<K>.Node
        if let _node = map[key] {
            // Key already exists: remove from current position and re-insert at front
            node = _node
            link.removeNode(node)
        } else {
            // New key: create new node and add to map
            node = DoublyLink<K>.Node(element: key)
            map[key] = node
        }
        link.enqueueFront(node: node)
    }
    
    /// Removes and returns the key at the front of the queue (most recently used).
    /// - Returns: The most recently used key, or nil if the queue is empty.
    public func dequeueFront() -> K? {
        guard let node = link.dequeueFront() else { return nil }
        map.removeValue(forKey: node.element)
        return node.element
    }
    
    /// Removes and returns the key at the back of the queue (least recently used).
    /// - Returns: The least recently used key, or nil if the queue is empty.
    public func dequeueBack() -> K? {
        guard let node = link.dequeueBack() else { return nil }
        map.removeValue(forKey: node.element)
        return node.element
    }
    
    /// Removes a specific key from the queue.
    /// If the key doesn't exist, this operation has no effect.
    /// - Parameter key: The key to remove from the queue.
    public func remove(key: K) {
        guard let node = map[key] else { return }
        map.removeValue(forKey: key)
        link.removeNode(node)
    }
}

public extension KeyQueue {
    /// The maximum number of keys the queue can hold.
    var capacity: Int { link.capacity }
    /// The current number of keys in the queue.
    var count: Int { link.count }
    /// Indicates if the queue is at maximum capacity.
    var isFull: Bool { count == capacity }
    /// Indicates if the queue is empty.
    var isEmpty: Bool { count == 0 }
}
