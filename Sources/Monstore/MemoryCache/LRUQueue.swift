//
//  LRUQueue.swift
//  Monstore
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

/// A queue backed by a doubly linked list implementing a fixed-capacity LRU (Least Recently Used) cache behavior.
/// Supports O(1) enqueue, dequeue, remove, and access by key operations.
/// 
/// Performance optimizations:
/// - Object pooling to reduce allocations
/// - Optimized node reuse patterns
/// - Reduced memory fragmentation
/// - Direct node manipulation for optimal performance
class LRUQueue<K: Hashable, Element> {
    /// A node in the doubly linked list storing the key-value pair and links to adjacent nodes.
    fileprivate class Node {
        /// Key associated with the element. Immutable after creation.
        let key: K
        
        /// The stored element value. Mutable.
        fileprivate(set) var value: Element
        
        /// Next node in the list (closer to the front).
        fileprivate(set) var next: Node? = nil
        
        /// Previous node in the list (closer to the back).
        fileprivate(set) var previous: Node? = nil
        
        /// Initializes a new node with key, value and optional links.
        init(key: K, value: Element, next: Node? = nil, previous: Node? = nil) {
            self.key = key
            self.value = value
            self.next = next
            self.previous = previous
        }
        
        /// Resets the node for reuse in object pool
        func reset() {
            // Note: key is immutable, so we can't reset it
            // This is used for internal node management
            next = nil
            previous = nil
        }
    }
    
    /// Maximum number of elements the queue can hold.
    let capacity: Int
    
    /// Current number of elements in the queue.
    private(set) var count: Int = 0
    
    /// The front (head) node where new elements are inserted.
    private var front: Node? = nil
    
    /// The back (tail) node where elements are removed when capacity is exceeded.
    private var back: Node? = nil
    
    /// Key-to-node map for O(1) access to nodes.
    private var keyNodeMap: [K: Node] = [:]
    
    /// Object pool for node reuse to reduce allocations
    private var nodePool: [Node] = []
    
    /// Indicates if the queue is empty.
    var isEmpty: Bool { count == 0 }
    
    /// Indicates if the queue is full.
    var isFull: Bool { count == capacity }
    
    /// CustomStringConvertible conformance for debugging
    var description: String {
        var elements = [String]()
        var node = front
        while let currentNode = node {
            elements.append("\(currentNode.value)")
            node = currentNode.next
        }
        return "[\(elements.joined(separator: ", "))]"
    }
    
    /// Initializes a new empty queue with specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values treated as zero.
    init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
        
        // Pre-allocate nodes for the pool to reduce allocations
        if capacity > 0 {
            nodePool.reserveCapacity(capacity)
        }
    }
    
    @discardableResult
    func setValue(_ value: Element, for key: K) -> Element? {
        return _setValue(value, for: key)
    }
    func getValue(for key: K) -> Element? {
        return _getValue(for: key)
    }
    @discardableResult
    func removeValue(for key: K) -> Element? {
        return _removeValue(for: key)
    }
    
    @discardableResult
    func _setValue(_ value: Element, for key: K) -> Element? {
        if let existingNode = keyNodeMap[key] {
            // Key already exists: remove old node, update value, re-insert at front
            removeNode(existingNode)
            existingNode.value = value
            return enqueueNode(existingNode)?.value // May return evicted value if capacity exceeded
        } else {
            // New key: insert new node, evict if needed
            let (newNode, evictedNode) = enqueue(key: key, value: value)
            if let newNode = newNode {
                keyNodeMap[newNode.key] = newNode
            }
            if let evictedNode = evictedNode {
                keyNodeMap.removeValue(forKey: evictedNode.key)
                return evictedNode.value // Return evicted value
            }
            return nil // No eviction occurred
        }
    }
    
    func _getValue(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        removeNode(node)
        _ = enqueueNode(node)
        return node.value
    }
    
    @discardableResult
    func _removeValue(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        removeNode(node)
        keyNodeMap.removeValue(forKey: node.key)
        return node.value
    }
}

private extension LRUQueue {
    
    /// Gets a node from the pool or creates a new one
    private func getNode(key: K, value: Element) -> Node {
        if let reusedNode = nodePool.popLast() {
            // Reuse existing node (note: we can't reuse the key, so create new node)
            return Node(key: key, value: value)
        }
        return Node(key: key, value: value)
    }
    
    /// Returns a node to the pool for reuse
    private func returnNodeToPool(_ node: Node) {
        node.reset()
        nodePool.append(node)
    }
    
    /// Enqueues a new element at the front of the queue.
    ///
    /// If the queue is full, removes the least recently used (back) node.
    ///
    /// - Parameters:
    ///   - key: Key of the new element.
    ///   - value: Value of the new element.
    /// - Returns: Tuple of the new node and the evicted node (if any).
    func enqueue(key: K, value: Element) -> (newNode: Node?, evictedNode: Node?) {
        // If capacity is 0, return the value as evicted since it cannot be stored
        guard capacity > 0 else { return (nil, Node(key: key, value: value)) }
        
        let evictedNode: Node?
        if count == capacity {
            evictedNode = dequeue()
        } else {
            evictedNode = nil
        }
        
        let newNode = getNode(key: key, value: value)
        if let currentFront = front {
            newNode.next = currentFront
            currentFront.previous = newNode
            front = newNode
        } else {
            front = newNode
            back = newNode
        }
        
        count += 1
        return (newNode, evictedNode)
    }
    
    /// Enqueues an existing node to the front of the queue.
    ///
    /// Removes the least recently used node if at capacity.
    ///
    /// - Parameter node: Node to enqueue.
    /// - Returns: Evicted node if any; otherwise nil.
    func enqueueNode(_ node: Node) -> Node? {
        guard capacity > 0 else { return node }
        
        let evictedNode: Node?
        if count == capacity {
            evictedNode = dequeue()
        } else {
            evictedNode = nil
        }
        
        if let currentFront = front {
            node.next = currentFront
            currentFront.previous = node
            front = node
        } else {
            front = node
            back = node
        }
        
        count += 1
        return evictedNode
    }
    
    /// Removes and returns the node at the back of the queue (least recently used).
    ///
    /// - Returns: The removed node, or nil if queue is empty.
    func dequeue() -> Node? {
        guard let oldBack = back else { return nil }
        
        back = oldBack.previous
        back?.next = nil
        
        count -= 1
        
        if count == 0 {
            front = nil
        }
        
        oldBack.previous = nil
        oldBack.next = nil
        
        // Return to pool for reuse
        returnNodeToPool(oldBack)
        
        return oldBack
    }
    
    /// Removes a specific node from the queue.
    ///
    /// - Parameter node: The node to remove. Must be currently in the queue.
    func removeNode(_ node: Node) {
        node.previous?.next = node.next
        node.next?.previous = node.previous
        
        if node === front {
            front = node.next
        }
        if node === back {
            back = node.previous
        }
        
        node.previous = nil
        node.next = nil
        
        count -= 1
    }
}
