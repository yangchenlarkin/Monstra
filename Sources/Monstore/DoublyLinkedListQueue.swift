//
//  DoublyLinkedListQueue.swift
//
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

extension DoublyLinkedListQueue {
    var isEmpty: Bool { count == 0 }
    var isFull: Bool { count == capacity }
}

/// A queue implementation backed by a doubly linked list with fixed capacity.
/// This implementation follows FIFO (First In, First Out) principle with O(1) complexity
/// for both enqueue and dequeue operations.
struct DoublyLinkedListQueue<Element> {
    /// The maximum number of elements this queue can store.
    /// This value cannot be changed after initialization.
    let capacity: Int
    
    /// The number of elements currently in the queue.
    /// This value is maintained automatically and cannot be modified directly.
    private(set) var count: Int = 0
    
    /// Reference to the front node of the queue where new elements are added.
    /// New elements are inserted at this end (enqueue operation).
    private(set) var front: ListNode<Element>? = nil
    
    /// Reference to the back node of the queue from where elements are removed.
    /// Elements are removed from this end (dequeue operation).
    private(set) var back: ListNode<Element>? = nil
    
    /// Creates a new empty queue with the specified capacity.
    /// - Parameter capacity: The maximum number of elements the queue can hold
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    
    /// Adds a new element to the front of the queue and returns both the new node and any displaced node.
    /// - Note: If the queue is at capacity, the oldest element (at back) will be removed and its node returned.
    /// - Parameters:
    ///   - value: The element to add to the queue
    /// - Returns: A tuple containing:
    ///   - First: The newly created node that was added to the front
    ///   - Second: The displaced node from the back if queue was at capacity, nil otherwise
    /// - Warning: If capacity is 0, returns (nil, nil) without performing any operation
    /// - Complexity: O(1)
    mutating func unsafeEnqueue(_ value: Element) -> (ListNode<Element>?, ListNode<Element>?) {
        guard capacity > 0 else { return (nil, nil) }
        
        // Handle capacity limit
        let displaced: ListNode<Element>?
        if count == capacity {
            displaced = unsafeDequeue()
        } else {
            displaced = nil
        }
        
        // Create new node
        let newNode = ListNode(value: value)
        
        // Update links
        if let existingHead = front {
            newNode.next = existingHead
            existingHead.previous = newNode
            front = newNode
        } else {
            front = newNode
            back = newNode
        }
        
        count += 1
        return (newNode, displaced)
    }
    
    /// Removes and returns the element at the back of the queue.
    /// - Returns: The removed node, or nil if the queue is empty
    /// - Complexity: O(1)
    mutating func unsafeDequeue() -> ListNode<Element>? {
        guard let oldTail = back else { return nil }
        
        // Update tail reference
        back = oldTail.previous
        back?.next = nil
        
        // Update count
        count -= 1
        
        // Update head if list is now empty
        if count == 0 {
            front = nil
        }
        
        oldTail.previous = nil
        oldTail.next = nil
        return oldTail
    }
    
    /// Removes a specific node from the queue.
    /// - Parameter node: The node to remove
    /// - Note: The node must be part of this queue. Passing a node from another
    ///         queue or a node that has already been removed leads to undefined behavior.
    /// - Complexity: O(1)
    mutating func unsafeRemove(_ node: ListNode<Element>) {
        // Update adjacent nodes
        node.previous?.next = node.next
        node.next?.previous = node.previous
        
        // Update head/tail if necessary
        if node === front {
            front = node.next
        }
        if node === back {
            back = node.previous
        }
        
        // Update count
        count -= 1
    }
}

/// A node in a doubly linked list that stores a single element and maintains
/// references to the next and previous nodes in the sequence.
class ListNode<Element>: CustomStringConvertible {
    var description: String {
"""
{value: \(self.value), p: \(String(describing: self.previous?.value)), n: \(String(describing: self.next?.value))}
"""
    }
    
    /// The element stored in this node.
    /// This value cannot be changed after node creation.
    let value: Element
    
    /// Reference to the next node in the sequence.
    /// nil indicates this is the last node.
    fileprivate(set) var next: ListNode<Element>? = nil
    
    /// Reference to the previous node in the sequence.
    /// nil indicates this is the first node.
    fileprivate(set) var previous: ListNode<Element>? = nil
    
    /// Creates a new node with the specified value and optional connections.
    /// - Parameters:
    ///   - value: The element to store in this node
    ///   - next: Optional reference to the next node in sequence
    ///   - previous: Optional reference to the previous node in sequence
    init(value: Element, next: ListNode<Element>? = nil, previous: ListNode<Element>? = nil) {
        self.value = value
        self.next = next
        self.previous = previous
    }
}

// MARK: - Sequence Conformance

extension DoublyLinkedListQueue: Sequence {
    /// An iterator that traverses the queue from front to back.
    /// Enables for-in loop support and functional programming operations.
    struct Iterator: IteratorProtocol {
        /// The current node being traversed.
        /// Updated as iteration progresses.
        private var current: ListNode<Element>?
        
        /// Creates an iterator starting at the specified node.
        /// - Parameter first: The node to begin iteration from
        init(first: ListNode<Element>?) {
            self.current = first
        }
        
        /// Advances to and returns the next element in the sequence.
        /// - Returns: The next element in the sequence, or nil if at the end
        /// - Complexity: O(1)
        mutating func next() -> Element? {
            defer { current = current?.next }
            return current?.value
        }
    }
    
    /// Creates an iterator that traverses the queue from front to back.
    /// - Returns: An iterator starting at the front of the queue
    func makeIterator() -> Iterator {
        Iterator(first: front)
    }
}

// MARK: - CustomStringConvertible

extension DoublyLinkedListQueue: CustomStringConvertible {
    /// A string representation of the queue's contents.
    /// Format: [element1, element2, ..., elementN]
    var description: String {
        var result = "["
        var current = front
        while let node = current {
            result += "$node.value)"
            if node.next != nil {
                result += ", "
            }
            current = node.next
        }
        result += "]"
        return result
    }
}
