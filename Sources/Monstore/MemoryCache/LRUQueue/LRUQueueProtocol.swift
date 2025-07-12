//
//  LRUQueueProtocol.swift
//  Monstore
//
//  Created by Larkin on 2025/5/8.
//

import Foundation

/// Protocol defining the interface for LRU (Least Recently Used) queue implementations.
/// 
/// An LRU queue maintains a fixed-capacity cache where the least recently used items
/// are evicted when capacity is exceeded. All operations are O(1) time complexity.
/// 
/// ## Key Concepts:
/// - **Capacity**: Maximum number of elements the queue can hold
/// - **LRU Strategy**: When capacity is exceeded, the least recently accessed item is removed
/// - **Access Pattern**: Any access (get/set) moves the item to the front (most recently used)
/// 
/// ## Implementation Notes:
/// - Both implementations use a doubly-linked list with O(1) operations
/// - ArrayBasedLRUQueue uses array indices for node references (memory efficient)
/// - DoublyLinkedLRUQueue uses actual node objects (more straightforward)
protocol LRUQueueProtocol: CustomStringConvertible {
    /// The key type, must be hashable for O(1) lookups
    associatedtype K: Hashable
    
    /// The value type stored in the queue
    associatedtype Element
    
    /// Maximum number of elements the queue can hold.
    /// When capacity is 0, no elements can be stored.
    var capacity: Int { get }
    
    /// Current number of elements in the queue.
    /// Always 0 <= count <= capacity
    var count: Int { get }
    
    /// Returns true if the queue contains no elements.
    var isEmpty: Bool { get }
    
    /// Returns true if the queue has reached its capacity limit.
    var isFull: Bool { get }
    
    /// Sets a value for the given key in the queue.
    /// 
    /// ## Behavior:
    /// - If the key already exists, updates the value and moves it to the front
    /// - If the key is new and queue is full, evicts the least recently used item
    /// - If capacity is 0, the value cannot be stored
    /// 
    /// ## Return Value:
    /// - Returns the value if capacity is 0 (value cannot be stored)
    /// - Returns the evicted value if an item was evicted due to capacity
    /// - Returns nil if no previous value existed and no eviction occurred
    @discardableResult
    func setValue(_ value: Element, for key: K) -> Element?
    
    /// Retrieves the value for the given key.
    /// 
    /// ## Behavior:
    /// - If the key exists, returns the value and moves the item to the front
    /// - If the key doesn't exist, returns nil
    /// - If capacity is 0, always returns nil
    /// 
    /// ## Return Value:
    /// - Returns the value if the key exists
    /// - Returns nil if the key doesn't exist or capacity is 0
    func getValue(for key: K) -> Element?
    
    /// Removes the value for the given key from the queue.
    /// 
    /// ## Behavior:
    /// - If the key exists, removes it from the queue and returns its value
    /// - If the key doesn't exist, returns nil
    /// - If capacity is 0, always returns nil
    /// 
    /// ## Return Value:
    /// - Returns the removed value if the key existed
    /// - Returns nil if the key doesn't exist or capacity is 0
    @discardableResult
    func removeValue(for key: K) -> Element?
    
    /// Returns a string representation of the queue contents.
    /// 
    /// ## Format:
    /// - Shows elements in order from most recently used to least recently used
    /// - Format: "[front, ..., back]" where front is most recently used
    /// - Example: "[3, 1, 2]" means 3 was accessed most recently, 2 least recently
    var description: String { get }
} 