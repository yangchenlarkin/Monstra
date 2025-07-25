//
//  PriorityLRUQueue.swift
//  Monstore
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

/// A priority-based LRU (Least Recently Used) queue that maintains separate LRU queues for each priority level.
///
/// - Elements with lower priority are evicted first.
/// - Within the same priority, least recently used elements are evicted first.
/// - Provides O(1) average case for access, update, and removal by key.
class PriorityLRUQueue<K: Hashable, Element> {
    /// The maximum number of elements the queue can hold.
    let capacity: Int
    /// The current number of elements in the queue.
    var count: Int { keyNodeMap.count }
    /// Indicates if the queue is empty.
    var isEmpty: Bool { count == 0 }
    /// Indicates if the queue is full.
    var isFull: Bool { count == capacity }
    /// Returns a string representation of the queue for debugging.
    var description: String {
        var elements = [String]()
        priorities.elements.forEach { priority in
            guard let link = links[priority] else { return }
            var node = link.front
            while let currentNode = node {
                elements.append("\(currentNode.value)")
                node = currentNode.next
            }
        }
        return "[\(elements.joined(separator: ", "))]"
    }
    
    private var links: [Double: Link] = .init()
    private var priorityIndex: [Double: Int] = .init()
    private var priorities: Heap<Double> = .minHeap(capacity: .max)
    /// Key-to-node map for O(1) access to nodes.
    private var keyNodeMap: [K: Node] = [:]
    
    /// Initializes a new empty queue with specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values treated as zero.
    init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
        self.priorities.onEvent = { [weak self] in
            guard let self else { return }
            switch $0 {
            case .insert(element: let element, at: let at):
                priorityIndex[element] = at
            case .remove(element: let element):
                priorityIndex.removeValue(forKey: element)
            case .move(element: let element, to: let to):
                priorityIndex[element] = to
            }
        }
    }
    
    /// Inserts or updates a value for the given key and priority.
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key to associate with the value.
    ///   - priority: The priority for eviction (higher is less likely to be evicted).
    /// - Returns: The evicted value, if any.
    @discardableResult
    func setValue(_ value: Element, for key: K, with priority: Double = 0) -> Element? {
        guard capacity > 0 else { return value }
        if let node = keyNodeMap[key] {
            // Key already exists: remove old node, update value, re-insert at front
            if let link = links[node.priority] {
                link.removeNode(node)
                self.removeLinkIfEmpty(of: node.priority)
            }
            node.value = value
            node.priority = priority
            let link = getOrCreateLink(for: priority)
            return link.enqueueNode(node)?.value
        }
        var evictedNode: Node? = nil
        if count == capacity {
            guard let minPriority = priorities.root, let link = links[minPriority] else { return value }
            if priority < minPriority {
                return value
            }
            evictedNode = link.dequeue()
            if let evictedKey = evictedNode?.key {
                keyNodeMap.removeValue(forKey: evictedKey)
            }
            removeLinkIfEmpty(of: minPriority)
        }
        let newNode = Node(key: key, value: value, priority: priority)
        keyNodeMap[key] = newNode
        _=getOrCreateLink(for: priority).enqueueNode(newNode)
        return evictedNode?.value
    }
    
    /// Retrieves the value for the given key, updating its recency.
    /// - Parameter key: The key to look up.
    /// - Returns: The value if present, or nil if not found.
    @discardableResult
    func getValue(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        guard let link = links[node.priority] else {
            keyNodeMap.removeValue(forKey: key)
            return nil
        }
        link.removeNode(node)
        _=link.enqueueNode(node)
        return node.value
    }
    
    /// Removes the value for the given key, if present.
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or nil if not found.
    @discardableResult
    func removeValue(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        keyNodeMap.removeValue(forKey: node.key)
        guard let link = links[node.priority] else { return node.value }
        link.removeNode(node)
        removeLinkIfEmpty(of: node.priority)
        return node.value
    }
    
    /// Removes and returns the least recently used value.
    /// - Returns: The removed value, or nil if cache is empty
    @discardableResult
    func removeValue() -> Element? {
        guard let key = getLeastRecentKey() else { return nil }
        return removeValue(for: key)
    }
    
    /// Gets the least recently used key for eviction.
    /// - Returns: The key of the least recently used entry, or nil if queue is empty
    func getLeastRecentKey() -> K? {
        // Find the lowest priority first
        guard let minPriority = priorities.root else { return nil }
        guard let link = links[minPriority] else { return nil }
        
        // Return the key of the least recently used node (back of the queue)
        return link.back?.key
    }
}

private extension PriorityLRUQueue {
    /// Returns the LRU queue (link) for the given priority, creating it if needed.
    func getOrCreateLink(for priority: Double) -> Link {
        if let res = links[priority] { return res }
        let link = Link(with: capacity)
        links[priority] = link
        priorities.insert(priority)
        return link
    }
    /// Removes the LRU queue (link) for the given priority if it is empty.
    func removeLinkIfEmpty(of priority: Double) {
        guard let link = links[priority] else { return }
        guard link.count == 0 else { return }
        if let index = priorityIndex[priority] {
            _=priorities.remove(at: index)
        }
        links.removeValue(forKey: priority)
    }
}

private extension PriorityLRUQueue {
    /// A node in the doubly linked list storing the key-value pair and links to adjacent nodes.
    class Node {
        /// Key associated with the element. Immutable after creation.
        let key: K
        /// The stored element value. Mutable.
        var value: Element
        /// The priority associated with this node.
        var priority: Double
        /// The index of this node in the priority heap, if present.
        var priorityHeapIndex: Int?
        /// Next node in the list (closer to the front).
        var next: Node? = nil
        /// Previous node in the list (closer to the back).
        var previous: Node? = nil
        /// Initializes a new node with key, value and optional links.
        init(key: K, value: Element, priority: Double, next: Node? = nil, previous: Node? = nil) {
            self.key = key
            self.value = value
            self.priority = priority
            self.next = next
            self.previous = previous
        }
        /// Resets the node for reuse in object pool.
        func reset() {
            // Note: key is immutable, so we can't reset it
            // This is used for internal node management
            next = nil
            previous = nil
        }
    }
    /// A doubly linked list for LRU management within a priority level.
    class Link {
        var front: Node?
        var back: Node?
        var count = 0
        let capacity: Int
        init(with capacity: Int) {
            self.capacity = capacity
        }
        /// Enqueues a new element at the front of the queue.
        /// If the queue is full, removes the least recently used (back) node.
        /// - Parameters:
        ///   - key: Key of the new element.
        ///   - value: Value of the new element.
        /// - Returns: Tuple of the new node and the evicted node (if any).
        func enqueue(key: K, value: Element, priority: Double) -> (newNode: Node?, evictedNode: Node?) {
            guard capacity > 0 else { return (nil, Node(key: key, value: value, priority: priority)) }
            let evictedNode: Node?
            if count == capacity {
                evictedNode = dequeue()
            } else {
                evictedNode = nil
            }
            let newNode = Node(key: key, value: value, priority: priority)
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
        /// Removes the least recently used node if at capacity.
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
}
