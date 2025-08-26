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
public class PriorityLRUQueue<K: Hashable, Element> {
    fileprivate struct LRUElement {
        fileprivate var key: K
        fileprivate var element: Element
        fileprivate var priority: Double
        fileprivate var priorityIndex: Int? = nil /// Index of the priority in the heap for efficient removal
    }
    private typealias LRULink = DoublyLink<LRUElement>
    private typealias LRUNode = LRULink.Node
    
    /// The maximum number of elements the queue can hold.
    public let capacity: Int
    /// The current number of elements in the queue.
    public var count: Int { keyNodeMap.count }
    /// Indicates if the queue is empty.
    public var isEmpty: Bool { count == 0 }
    /// Indicates if the queue is full.
    public var isFull: Bool { count == capacity }
    /// Returns a string representation of the queue for debugging.
    var description: String {
        var elements = [String]()
        priorities.elements.forEach { priority in
            guard let link = links[priority] else { return }
            var node = link.front
            while let currentNode = node {
                elements.append("\(currentNode.element.element)")
                node = currentNode.next
            }
        }
        return "[\(elements.joined(separator: ", "))]"
    }
    
    private var links: [Double: LRULink] = .init()
    private var priorityIndex: [Double: Int] = .init()
    private var priorities: Heap<Double> = .minHeap(capacity: .max)
    /// Key-to-node map for O(1) access to nodes.
    private var keyNodeMap: [K: LRUNode] = [:]
    
    /// Initializes a new empty queue with specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values treated as zero.
    public init(capacity: Int) {
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
    
    /// Inserts or updates a element for the given key and priority.
    /// - Parameters:
    ///   - element: The element to store.
    ///   - key: The key to associate with the element.
    ///   - priority: The priority for eviction (lower priority elements are evicted first).
    /// - Returns: The evicted element, if any.
    @discardableResult
    public func setElement(_ element: Element, for key: K, with priority: Double = 0) -> Element? {
        guard capacity > 0 else { return element }
        if let node = keyNodeMap[key] {
            // Key already exists: remove old node, update element, re-insert at front
            if let link = links[node.element.priority] {
                link.removeNode(node)
                self.removeLinkIfEmpty(of: node.element.priority)
            }
            node.element.element = element
            node.element.priority = priority
            let link = getOrCreateLink(for: priority)
            return link.enqueueFront(node: node, evictedStrategy: .FIFO)?.element.element
        }
        var evictedNode: LRUNode? = nil
        if count == capacity {
            guard let minPriority = priorities.root, let link = links[minPriority] else { return element }
            if priority < minPriority {
                return element
            }
            evictedNode = link.dequeueBack()
            if let evictedKey = evictedNode?.element.key {
                keyNodeMap.removeValue(forKey: evictedKey)
            }
            removeLinkIfEmpty(of: minPriority)
        }
        let newNode = LRUNode(element: .init(key: key, element: element, priority: priority))
        keyNodeMap[key] = newNode
        _=getOrCreateLink(for: priority).enqueueFront(node: newNode, evictedStrategy: .FIFO)
        return evictedNode?.element.element
    }
    
    /// Retrieves the element for the given key, updating its recency.
    /// - Parameter key: The key to look up.
    /// - Returns: The element if present, or nil if not found.
    @discardableResult
    public func getElement(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        guard let link = links[node.element.priority] else {
            keyNodeMap.removeValue(forKey: key)
            return nil
        }
        link.removeNode(node)
        _=link.enqueueFront(node: node, evictedStrategy: .FIFO)
        return node.element.element
    }
    
    /// Removes the element for the given key, if present.
    /// - Parameter key: The key to remove.
    /// - Returns: The removed element, or nil if not found.
    @discardableResult
    public func removeElement(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        keyNodeMap.removeValue(forKey: node.element.key)
        guard let link = links[node.element.priority] else { return node.element.element }
        link.removeNode(node)
        removeLinkIfEmpty(of: node.element.priority)
        return node.element.element
    }
    
    /// Removes and returns the least recently used element.
    /// - Returns: The removed element, or nil if cache is empty
    @discardableResult
    public func removeElement() -> Element? {
        guard let key = getLeastRecentKey() else { return nil }
        return removeElement(for: key)
    }
    
    /// Gets the least recently used key for eviction.
    /// - Returns: The key of the least recently used entry, or nil if queue is empty
    public func getLeastRecentKey() -> K? {
        // Find the lowest priority first
        guard let minPriority = priorities.root else { return nil }
        guard let link = links[minPriority] else { return nil }
        
        // Return the key of the least recently used node (back of the queue)
        return link.back?.element.key
    }
}

private extension PriorityLRUQueue {
    /// Returns the LRU queue (link) for the given priority, creating it if needed.
    private func getOrCreateLink(for priority: Double) -> LRULink {
        if let res = links[priority] { return res }
        let link = LRULink(with: capacity)
        links[priority] = link
        priorities.insert(priority)
        return link
    }
    /// Removes the LRU queue (link) for the given priority if it is empty.
    private func removeLinkIfEmpty(of priority: Double) {
        guard let link = links[priority] else { return }
        guard link.count == 0 else { return }
        if let index = priorityIndex[priority] {
            _=priorities.remove(at: index)
        }
        links.removeValue(forKey: priority)
    }
}
