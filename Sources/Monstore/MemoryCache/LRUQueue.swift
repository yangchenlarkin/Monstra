//
//  LRUQueue.swift
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

/// A queue backed by a doubly linked list implementing a fixed-capacity LRU (Least Recently Used) cache behavior.
/// Supports O(1) enqueue, dequeue, remove, and access by key operations.
///
/// - Note: This queue is designed for internal (unsafe) operations assuming node correctness,
///   so external callers should use the safe APIs on `LRUQueue` struct for correctness.
class LRUQueue<K: Hashable, Element> {
    /// A node in the doubly linked list storing the key-value pair and links to adjacent nodes.
    class Node: CustomStringConvertible {
        /// Key associated with the element. Immutable after creation.
        let key: K
        
        /// The stored element value. Mutable.
        fileprivate(set) var value: Element
        
        /// Next node in the list (closer to the front).
        fileprivate(set) var next: Node? = nil
        
        /// Previous node in the list (closer to the back).
        fileprivate(set) var previous: Node? = nil
        
        /// Node description useful for debugging.
        var description: String {
            """
            {key: \(key), value: \(value), previous: \(String(describing: previous?.key)), next: \(String(describing: next?.key))}
            """
        }
        
        /// Initializes a new node with key, value and optional links.
        init(key: K, value: Element, next: Node? = nil, previous: Node? = nil) {
            self.key = key
            self.value = value
            self.next = next
            self.previous = previous
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
    
    /// Indicates if the queue is empty.
    var isEmpty: Bool { count == 0 }
    
    /// Indicates if the queue is full.
    var isFull: Bool { count == capacity }
    
    /// Initializes a new empty queue with specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values treated as zero.
    init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
    }
    
    /// Inserts or updates an element for the given key.
    /// If the key already exists, the node is moved to the front (most recently used).
    /// If capacity is reached, the least recently used element is evicted.
    ///
    /// - Parameters:
    ///   - value: Element to store.
    ///   - key: Key associated with the element.
    func unsafeSetValue(_ value: Element, for key: K) -> Element? {
        if let existingNode = keyNodeMap[key] {
            // Remove old node, update value, re-insert at front
            removeNode(existingNode)
            existingNode.value = value
            return enqueueNode(existingNode)?.value
        } else {
            // Insert new node; evict if needed
            let (newNode, evictedNode) = enqueue(key: key, value: value)
            if let newNode = newNode {
                keyNodeMap[newNode.key] = newNode
            }
            if let evictedNode = evictedNode {
                keyNodeMap.removeValue(forKey: evictedNode.key)
            }
            return nil
        }
    }
    
    /// Returns the element associated with the key if present.
    /// Moves the node to the front as it is now most recently used.
    ///
    /// - Parameter key: Key to lookup.
    /// - Returns: The associated element or nil if not found.
    func unsafeGetValue(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        removeNode(node)
        _ = enqueueNode(node)
        return node.value
    }
    
    /// Removes the element associated with the key if present.
    /// Does not update usage order since the element is being removed.
    ///
    /// - Parameter key: Key to remove.
    /// - Returns: The removed element or nil if not found.
    func unsafeRemoveValue(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        removeNode(node)
        keyNodeMap.removeValue(forKey: node.key)
        return node.value
    }
}

private extension LRUQueue {
    
    /// Enqueues a new element at the front of the queue.
    ///
    /// If the queue is full, removes the least recently used (back) node.
    ///
    /// - Parameters:
    ///   - key: Key of the new element.
    ///   - value: Value of the new element.
    /// - Returns: Tuple of the new node and the evicted node (if any).
    func enqueue(key: K, value: Element) -> (newNode: Node?, evictedNode: Node?) {
        guard capacity > 0 else { return (nil, nil) }
        
        let evictedNode: Node?
        if count == capacity {
            evictedNode = dequeue()
        } else {
            evictedNode = nil
        }
        
        let newNode = Node(key: key, value: value)
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

// MARK: - Sequence conformance for easy iteration

extension LRUQueue: Sequence {
    struct Iterator: IteratorProtocol {
        private var currentNode: Node?
        
        init(startNode: Node?) {
            self.currentNode = startNode
        }
        
        mutating func next() -> Element? {
            defer { currentNode = currentNode?.next }
            return currentNode?.value
        }
    }
    
    func makeIterator() -> Iterator {
        Iterator(startNode: front)
    }
}

// MARK: - CustomStringConvertible conformance for debugging

extension LRUQueue: CustomStringConvertible {
    var description: String {
        var elements = [String]()
        var node = front
        while let currentNode = node {
            elements.append("\(currentNode.value)")
            node = currentNode.next
        }
        return "[\(elements.joined(separator: ", "))]"
    }
}
