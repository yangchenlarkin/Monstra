import Foundation

/// PriorityLRUQueue: Priority-aware LRU queue with O(1) average access and updates.
///
/// This data structure maintains separate LRU queues per priority level and evicts
/// elements according to a two-tier policy:
/// - By priority: lower priority values are evicted first
/// - Within a priority: least-recently-used (LRU) elements are evicted first
///
/// - Complexity:
///   - get/set/remove by key: O(1) average
///   - eviction and priority promotion: O(1) average
///
/// - Thread-safety: This type is not thread-safe on its own. Wrap usage with external
///   synchronization (such as a semaphore) when accessed from multiple threads.
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
    /// - Note: Negative capacities are normalized to 0 in `init(capacity:)`.
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
        for priority in priorities.elements {
            guard let link = links[priority] else { continue }
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
        priorities.onEvent = { [weak self] in
            guard let self else { return }
            switch $0 {
            case let .insert(element: element, at: at):
                priorityIndex[element] = at
            case let .remove(element: element):
                priorityIndex.removeValue(forKey: element)
            case let .move(element: element, to: to):
                priorityIndex[element] = to
            }
        }
    }

    /// Inserts or updates an element for the given key and priority.
    ///
    /// - Behavior:
    ///   - If the key exists: updates its element and priority, and moves it to the front of its priority LRU.
    ///   - If the queue is full: evicts from the lowest priority; within that level, evicts the LRU element.
    ///   - If `capacity == 0`: returns the provided element (cannot be stored).
    ///
    /// - Parameters:
    ///   - element: The element to store.
    ///   - key: The key to associate with the element.
    ///   - priority: Eviction priority (lower priority evicted first). Default is 0.
    /// - Returns: The evicted element, if any; or the input element if it could not be stored (for capacity 0 or lower priority than current minimum).
    @discardableResult
    public func setElement(_ element: Element, for key: K, with priority: Double = 0) -> Element? {
        guard capacity > 0 else { return element }
        if let node = keyNodeMap[key] {
            // Key already exists: remove old node, update element, re-insert at front
            if let link = links[node.element.priority] {
                link.removeNode(node)
                removeLinkIfEmpty(of: node.element.priority)
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
        _ = getOrCreateLink(for: priority).enqueueFront(node: newNode, evictedStrategy: .FIFO)
        return evictedNode?.element.element
    }

    /// Retrieves the element for the given key and refreshes its LRU position.
    /// - Parameter key: The key to look up.
    /// - Returns: The element if present; otherwise nil.
    @discardableResult
    public func getElement(for key: K) -> Element? {
        guard let node = keyNodeMap[key] else { return nil }
        guard let link = links[node.element.priority] else {
            keyNodeMap.removeValue(forKey: key)
            return nil
        }
        link.removeNode(node)
        _ = link.enqueueFront(node: node, evictedStrategy: .FIFO)
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

    /// Removes and returns the least recently used element across all priorities.
    /// - Returns: The removed element, or nil if the queue is empty.
    @discardableResult
    public func removeElement() -> Element? {
        guard let key = getLeastRecentKey() else { return nil }
        return removeElement(for: key)
    }

    /// Returns the key of the least recently used entry across all priorities.
    /// - Returns: The LRU key, or nil if the queue is empty.
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
            _ = priorities.remove(at: index)
        }
        links.removeValue(forKey: priority)
    }
}
