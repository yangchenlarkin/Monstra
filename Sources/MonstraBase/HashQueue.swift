import Foundation

/**
 A high-performance hash-based queue that maintains insertion order with O(1) access and removal operations.

 ## Core Features

 - **Hash-Based Operations**: All operations are performed using hashable keys, providing intuitive access patterns
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
 // Create a hash queue with capacity of 100
 let queue = HashQueue<String>(capacity: 100)

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

/// A hash-based queue that maintains insertion order with LRU (Least Recently Used) behavior.
/// Provides O(1) operations for enqueue, dequeue, and removal by key.
public class HashQueue<K: Hashable> {
    /// The underlying doubly linked list that maintains the queue order.
    private let link: DoublyLink<K>
    /// Hash map for O(1) key-to-node lookup.
    private var map: [K: DoublyLink<K>.Node]

    /// Initializes a new empty hash queue with specified capacity.
    /// - Parameter capacity: Maximum number of keys allowed in the queue.
    ///   Negative values are treated as zero.
    public init(capacity: Int) {
        link = .init(with: capacity)
        map = .init()
    }

    /// Enqueues a key at the front of the queue (most recently used position).
    /// If the key already exists, it is moved to the front (LRU behavior).
    /// - Parameter key: The key to enqueue.
    @discardableResult
    public func enqueueFront(key: K, evictedStrategy: DoublyLink<K>.EvictedStrategy) -> K? {
        guard capacity > 0 else { return key }

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
        guard let evictedKey = link.enqueueFront(node: node, evictedStrategy: evictedStrategy)?.element else {
            return nil
        }
        map.removeValue(forKey: evictedKey)
        return evictedKey
    }

    /// Removes and returns the key at the front of the queue (most recently used).
    /// - Returns: The most recently used key, or nil if the queue is empty.
    public func dequeueFront() -> K? {
        guard let node = link.dequeueFront() else { return nil }
        map.removeValue(forKey: node.element)
        return node.element
    }

    /// Removes and returns multiple keys from the front of the queue (most recently used).
    /// - Parameter count: The number of keys to dequeue. If count exceeds available keys, returns all available keys.
    /// - Returns: Array of the most recently used keys, in order from most to least recent.
    ///   Returns empty array if queue is empty or count is 0.
    public func dequeueFront(count: UInt) -> [K] {
        var res = [K]()
        for _ in 0 ..< count {
            guard let key = dequeueFront() else { break }
            res.append(key)
        }
        return res
    }

    /// Removes and returns the key at the back of the queue (least recently used).
    /// - Returns: The least recently used key, or nil if the queue is empty.
    public func dequeueBack() -> K? {
        guard let node = link.dequeueBack() else { return nil }
        map.removeValue(forKey: node.element)
        return node.element
    }

    /// Removes and returns multiple keys from the back of the queue (least recently used).
    /// - Parameter count: The number of keys to dequeue. If count exceeds available keys, returns all available keys.
    /// - Returns: Array of the least recently used keys, in order from least to most recent.
    ///   Returns empty array if queue is empty or count is 0.
    public func dequeueBack(count: UInt) -> [K] {
        var res = [K]()
        for _ in 0 ..< count {
            guard let key = dequeueBack() else { break }
            res.append(key)
        }
        return res
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

public extension HashQueue {
    /// The maximum number of keys the queue can hold.
    var capacity: Int { link.capacity }
    /// The current number of keys in the queue.
    var count: Int { link.count }
    /// Indicates if the queue is at maximum capacity.
    var isFull: Bool { count == capacity }
    /// Indicates if the queue is empty.
    var isEmpty: Bool { count == 0 }

    func contains(key: K) -> Bool {
        map.keys.contains(key)
    }
}
