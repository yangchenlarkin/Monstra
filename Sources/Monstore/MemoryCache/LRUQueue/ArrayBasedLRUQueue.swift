//
//  ArrayBasedLRUQueue.swift
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

/// A queue backed by a doubly linked list implementing a fixed-capacity LRU (Least Recently Used) cache behavior.
/// Supports O(1) enqueue, dequeue, remove, and access by key operations.
///
/// - Note: This queue is designed for internal (unsafe) operations assuming node correctness,
///   so external callers should use the safe APIs on `DoublyLinkedLRUQueue` struct for correctness.
class ArrayBasedLRUQueue<K: Hashable, Element>: LRUQueueProtocol {
    /// A node in the doubly linked list storing the key-value pair and links to adjacent nodes.
    fileprivate struct Node {
        typealias KV = (key: K, value: Element)
        /// The stored element value. Mutable.
        fileprivate(set) var kv: KV?
        
        /// Next node in the list (closer to the front).
        fileprivate(set) var next: Int? = nil
        
        /// Previous node in the list (closer to the back).
        fileprivate(set) var previous: Int? = nil
        
        /// Initializes a new node with key, value and optional links.
        init(kv: KV? = nil, next: Int? = nil, previous: Int? = nil) {
            self.kv = kv
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
    
    /// Initializes a new empty queue with specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values treated as zero.
    init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
        self.storage = .init(repeating: .init(), count: self.capacity)
        
        guard self.capacity > 0 else { return }
        
        for i in 1..<self.capacity {
            self.storage[i-1].next = i
        }
        nilHead = 0
    }
    
    @discardableResult
    func setValue(_ value: Element, for key: K) -> Element? {
        return unsafeSetValue(value, for: key)
    }
    func getValue(for key: K) -> Element? {
        return unsafeGetValue(for: key)
    }
    @discardableResult
    func removeValue(for key: K) -> Element? {
        return unsafeRemoveValue(for: key)
    }
    
    @discardableResult
    func unsafeSetValue(_ value: Element, for key: K) -> Element? {
        guard capacity > 0 else { return value }
        
        if let existingIndex = keyNodeMap[key] {
            // Remove old node, update value, re-insert at front
            _=removeNode(at: existingIndex)
            let res = enqueue(key: key, value: value)
            keyNodeMap[key] = res.index
            return nil
        } else {
            // Insert new node; evict if needed
            let (index, evictedKV) = enqueue(key: key, value: value)
            keyNodeMap[key] = index
            if let evictedKV  {
                keyNodeMap.removeValue(forKey: evictedKV.key)
                return evictedKV.value
            }
            return nil
        }
    }
    
    func unsafeGetValue(for key: K) -> Element? {
        guard capacity > 0 else { return nil }
        
        guard
            let existingIndex = keyNodeMap[key],
            let kv = removeNode(at: existingIndex)
        else {
            return nil
        }
        
        let res = enqueue(key: kv.key, value: kv.value)
        keyNodeMap[key] = res.index
        return kv.value
    }
    
    @discardableResult
    func unsafeRemoveValue(for key: K) -> Element? {
        guard capacity > 0 else { return nil }
        
        guard
            let existingIndex = keyNodeMap[key],
            let kv = removeNode(at: existingIndex)
        else {
            return nil
        }
        
        return kv.value
    }
}

private extension ArrayBasedLRUQueue {
    /// Enqueues a new element at the front of the queue.
    ///
    /// If the queue is full, removes the least recently used (back) node.
    ///
    /// - Parameters:
    ///   - key: Key of the new element.
    ///   - value: Value of the new element.
    /// - Returns: Tuple of the new node and the evicted node (if any).
    func enqueue(key: K, value: Element) -> (index: Int?, evictedKV: Node.KV?) {
        guard capacity > 0 else { return (nil, (key, value))}
        
        if let emptyIndex = popNil() {
            storage[emptyIndex].kv = (key, value)
            
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
        let evictedKV = storage[back].kv
        storage[back].kv = (key, value)
        
        if front != back {
            self.front = back
            self.back = storage[back].previous
            
            guard let currentBack = self.back else { return (nil, nil) }
            
            storage[back].previous = nil
            storage[back].next = front
            
            storage[front].previous = back
            storage[currentBack].next = nil
        }
        
        return (back, evictedKV)
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
    /// - Parameter node: The node to remove. Must be currently in the queue.
    func removeNode(at index: Int) -> Node.KV? {
        guard index >= 0, index < self.capacity else { return nil }
        guard let kv = storage[index].kv else { return nil }
        storage[index].kv = nil
        
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
        return kv
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

// MARK: - CustomStringConvertible conformance for debugging

extension ArrayBasedLRUQueue: CustomStringConvertible {
    var description: String {
        var elements = [String]()
        var node = front
        while let currentNode = node {
            elements.append("\(String(describing: storage[currentNode].kv?.value))")
            node = storage[currentNode].next
        }
        return "[\(elements.joined(separator: ", "))]"
    }
}

