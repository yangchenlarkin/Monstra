import Foundation

public extension DoublyLink {
    /// A node in the doubly linked list storing the element and links to adjacent nodes.
    class Node {
        /// The stored element value. Mutable.
        public var element: Element
        /// Next node in the list (closer to the front).
        public var next: Node?
        /// Previous node in the list (closer to the back).
        public var previous: Node?
        /// Initializes a new node with key, value and optional links.
        public init(element: Element, next: Node? = nil, previous: Node? = nil) {
            self.element = element
            self.next = next
            self.previous = previous
        }
    }
}

/// A doubly linked list for LRU management within a priority level.
public class DoublyLink<Element> {
    public private(set) var front: Node?
    public private(set) var back: Node?
    public private(set) var count = 0
    public let capacity: Int
    public init(with capacity: Int) {
        self.capacity = max(0, capacity)
    }

    /// Enqueues a new element at the front of the queue.
    /// If the queue is full, removes the least recently used (back) node.
    /// - Parameters:
    ///   - key: Key of the new element.
    ///   - element: Value of the new element.
    /// - Returns: Tuple of the new node and the evicted node (if any).
    @discardableResult
    public func enqueueFront(element: Element) -> (newNode: Node?, evictedNode: Node?) {
        guard capacity > 0 else { return (nil, Node(element: element)) }
        let evictedNode: Node?
        if count == capacity {
            evictedNode = dequeueBack()
        } else {
            evictedNode = nil
        }
        let newNode = Node(element: element)
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

    public enum EvictedStrategy {
        case FIFO
        case LIFO
    }

    /// Enqueues an existing node to the front of the queue.
    /// Removes the least recently used node if at capacity.
    /// - Parameter node: Node to enqueue.
    /// - Returns: Evicted node if any; otherwise nil.
    @discardableResult
    public func enqueueFront(node: Node, evictedStrategy: EvictedStrategy = .FIFO) -> Node? {
        guard capacity > 0 else { return node }
        let evictedNode: Node?
        if count == capacity {
            switch evictedStrategy {
            case .FIFO:
                evictedNode = dequeueBack()
            case .LIFO:
                return node
            }
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
    @discardableResult
    public func dequeueBack() -> Node? {
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

    /// Removes and returns the node at the front of the queue (most recently used).
    /// - Returns: The removed node, or nil if queue is empty.
    @discardableResult
    public func dequeueFront() -> Node? {
        guard let oldFront = front else { return nil }
        front = oldFront.next
        front?.previous = nil
        count -= 1
        if count == 0 {
            back = nil
        }
        oldFront.next = nil
        oldFront.previous = nil
        return oldFront
    }

    /// Removes a specific node from the queue.
    /// - Parameter node: The node to remove. Must be currently in the queue.
    public func removeNode(_ node: Node) {
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
