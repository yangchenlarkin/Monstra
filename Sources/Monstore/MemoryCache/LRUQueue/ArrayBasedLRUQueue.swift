//
//  ArrayBasedLRUQueue.swift
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

/// A queue backed by a doubly linked list implementing a fixed-capacity LRU (Least Recently Used) cache behavior.
/// Supports O(1) enqueue, dequeue, remove, and access by key operations.
class ArrayBasedLRUQueue<K: Hashable, Element>: LRUQueueProtocol {
    /// A node in the doubly linked list storing the key-value pair and links to adjacent nodes.
    fileprivate struct Node {
        /// Key associated with the element. Mutable.
        fileprivate(set) var key: K?
        
        /// The stored element value. Mutable.
        fileprivate(set) var value: Element?
        
        /// Next node in the list (closer to the front).
        fileprivate(set) var next: Int? = nil
        
        /// Previous node in the list (closer to the back).
        fileprivate(set) var previous: Int? = nil
        
        /// Initializes a new node with key, value and optional links.
        init(key: K?, value: Element?, next: Int? = nil, previous: Int? = nil) {
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
    private var front: Int? = nil
    private var back: Int? = nil
    private var nilHead: Int? = nil
    
    /// Key-to-node map for O(1) access to nodes.
    private var keyNodeMap: [K: Int] = [:]
    private var storage: [Node]
    
    /// Indicates if the queue is empty.
    var isEmpty: Bool { count == 0 }
    
    /// Indicates if the queue is full.
    var isFull: Bool { count == capacity }
    
    /// CustomStringConvertible conformance for debugging
    var description: String {
        var elements = [String]()
        var node = front
        while let currentNode = node {
            elements.append("\(String(describing: storage[currentNode].value))")
            node = storage[currentNode].next
        }
        return "[\(elements.joined(separator: ", "))]"
    }
    
    /// Initializes a new empty queue with specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values treated as zero.
    init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
        self.storage = .init(repeating: .init(key: nil, value: nil), count: self.capacity)
        
        guard self.capacity > 0 else { return }
        
        for i in 1..<self.capacity {
            self.storage[i-1].next = i
        }
        nilHead = 0
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
        // If capacity is 0, return the value as it cannot be stored
        guard capacity > 0 else { return value }
        
        if let existingIndex = keyNodeMap[key] {
            // Key already exists: remove old node, update value, re-insert at front
            _ = removeNode(at: existingIndex)
            let res = enqueue(key: key, value: value)
            keyNodeMap[key] = res.index
            return nil // No eviction occurred, just overwrite
        } else {
            // New key: insert new node, evict if needed
            let (index, evictedNode) = enqueue(key: key, value: value)
            keyNodeMap[key] = index
            if let evictedNode {
                keyNodeMap.removeValue(forKey: evictedNode.key!)
                return evictedNode.value // Return evicted value
            }
            return nil // No eviction occurred
        }
    }
    
    func _getValue(for key: K) -> Element? {
        guard capacity > 0 else { return nil }
        
        guard
            let existingIndex = keyNodeMap[key],
            let node = removeNode(at: existingIndex)
        else {
            return nil
        }
        
        let res = enqueue(key: node.key!, value: node.value!)
        keyNodeMap[key] = res.index
        return node.value
    }
    
    @discardableResult
    func _removeValue(for key: K) -> Element? {
        guard capacity > 0 else { return nil }
        
        guard
            let existingIndex = keyNodeMap[key],
            let node = removeNode(at: existingIndex)
        else {
            return nil
        }
        
        return node.value
    }
}

private extension ArrayBasedLRUQueue {
    /// Enqueues a new element at the front of the queue.
    ///
    /// If the queue is full, evicts the least recently used (back) node.
    ///
    /// - Parameters:
    ///   - key: Key of the new element.
    ///   - value: Value of the new element.
    /// - Returns: Tuple of the new node index and the evicted node (if any).
    func enqueue(key: K, value: Element) -> (index: Int?, evictedNode: Node?) {
        // If capacity is 0, return the value as evicted since it cannot be stored
        guard capacity > 0 else { return (nil, Node(key: key, value: value)) }
        
        if let emptyIndex = popNil() {
            storage[emptyIndex].key = key
            storage[emptyIndex].value = value
            
            guard let front else {
                self.front = emptyIndex
                self.back = emptyIndex
                count = 1
                return (emptyIndex, nil)
            }
            
            storage[emptyIndex].next = front
            storage[front].previous = emptyIndex
            self.front = emptyIndex
            
            count += 1
            return (emptyIndex, nil)
        }
        
        guard let front, let back else { return (nil, nil) }
        let evictedNode = Node(key: storage[back].key, value: storage[back].value)
        storage[back].key = key
        storage[back].value = value
        
        if front != back {
            self.front = back
            self.back = storage[back].previous
            
            guard let currentBack = self.back else { return (nil, nil) }
            
            storage[back].previous = nil
            storage[back].next = front
            
            storage[front].previous = back
            storage[currentBack].next = nil
        }
        
        return (back, evictedNode)
    }
    
    /// Removes and returns the node at the back of the queue (least recently used).
    ///
    /// - Returns: The removed node, or nil if queue is empty.
    func dequeue() -> Int? {
        guard capacity > 0 else { return nil }
        guard let _ = front, let back else { return nil }
        
        if let previous = storage[back].previous {
            storage[previous].next = nil
            self.back = previous
        } else {
            self.front = nil
            self.back = nil
        }
        
        insertNil(index: back)
        count -= 1
        return back
    }
    
    /// Removes a specific node from the queue.
    ///
    /// - Parameter index: The index of the node to remove. Must be currently in the queue.
    /// - Returns: The removed node, or nil if the node doesn't exist.
    func removeNode(at index: Int) -> Node? {
        guard index >= 0, index < self.capacity else { return nil }
        guard storage[index].key != nil else { return nil }
        
        let node = Node(key: storage[index].key!, value: storage[index].value)
        storage[index].key = nil
        storage[index].value = nil
        
        if front == back {
            guard front == index else { return nil }
            
            front = nil
            back = nil
        } else if index == front {
            guard
                let next = storage[index].next
            else { return nil }
            
            front = next
            storage[next].previous = nil
        } else if index == back {
            guard
                let previous = storage[index].previous
            else { return nil }
            
            back = previous
            storage[previous].next = nil
        } else {
            guard
                let previous = storage[index].previous,
                let next = storage[index].next
            else { return nil }
            
            storage[previous].next = next
            storage[next].previous = previous
        }
        
        insertNil(index: index)
        count -= 1
        return node
    }
    
    func popNil() -> Int? {
        guard let nilHead else { return nil }
        
        self.nilHead = storage[nilHead].next
        storage[nilHead].next = nil
        return nilHead
    }
    
    func insertNil(index: Int) {
        storage[index].previous = nil
        storage[index].next = nilHead
        nilHead = index
    }
}

