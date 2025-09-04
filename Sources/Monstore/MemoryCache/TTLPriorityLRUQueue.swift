import Foundation

/// TTLPriorityLRUQueue: Hybrid TTL + Priority + LRU cache.
///
/// This structure stores items with a time-to-live (TTL), an eviction priority, and tracks
/// recency for LRU ordering. Eviction proceeds in the following order:
/// 1) Expired entries
/// 2) Lowest priority
/// 3) Least-recently-used within the same priority
///
/// - Complexity: O(1) average for set/get/remove by key; O(k) to purge k expired entries.
/// - Thread-safety: Not thread-safe by itself; use external synchronization if needed.
public class TTLPriorityLRUQueue<Key: Hashable, Element> {
    /// The maximum number of elements the cache can hold.
    public let capacity: Int
    /// Heap for managing TTL expiration order.
    fileprivate var ttlQueue: Heap<Node>
    /// Priority-based LRU queue for managing eviction order.
    fileprivate var lruQueue: PriorityLRUQueue<Key, Node>

    /// Returns true if the cache is empty.
    public var isEmpty: Bool { lruQueue.isEmpty }
    /// Returns true if the cache is full.
    public var isFull: Bool { lruQueue.isFull }
    /// The current number of elements in the cache.
    public var count: Int { lruQueue.count }

    /// Initializes a new empty cache with the specified capacity.
    /// - Parameter capacity: Maximum elements allowed; negative values are treated as zero.
    public init(capacity: Int) {
        self.capacity = Swift.max(0, capacity)
        ttlQueue = .init(capacity: capacity, compare: { n1, n2 in
            switch true {
            case n1.expirationTimeStamp < n2.expirationTimeStamp:
                return .moreTop
            case n1.expirationTimeStamp > n2.expirationTimeStamp:
                return .moreBottom
            default:
                return .equal
            }
        })
        lruQueue = PriorityLRUQueue(capacity: capacity)

        ttlQueue.onEvent = {
            switch $0 {
            case let .insert(element, at):
                element.ttlIndex = at
            case let .remove(element):
                element.ttlIndex = nil
            case let .move(element, to):
                element.ttlIndex = to
            }
        }
    }
}

public extension TTLPriorityLRUQueue {
    /// Inserts or updates an element for the given key, with optional priority and TTL.
    ///
    /// - Behavior:
    ///   - Overwrites existing keys and refreshes both TTL and LRU position
    ///   - Chooses insertion path based on whether the earliest TTL has already expired
    ///   - Returns an evicted element when capacity is exceeded following policy (expired → priority → LRU)
    ///
    /// - Parameters:
    ///   - element: The element to store
    ///   - key: The key to associate with the element
    ///   - priority: Eviction priority (higher values retained longer)
    ///   - duration: TTL in seconds (default: .infinity)
    /// - Returns: The evicted element, if any
    @discardableResult
    func set(
        element: Element,
        for key: Key,
        priority: Double = .zero,
        expiredIn duration: TimeInterval = .infinity
    ) -> Element? {
        let now = CPUTimeStamp.now()
        // Check if the key already exists in the LRU queue
        if removeElement(for: key) != nil {
            return setToLRUQueue(now: now, element: element, for: key, priority: priority, expiredIn: duration)
        } else {
            // If the key does not exist, check if the TTL heap root has expired
            if let ttlRoot = ttlQueue.root?.expirationTimeStamp, ttlRoot < now {
                // If the root of TTL heap is expired, insert into the TTL heap
                return setToTTLQueue(now: now, element: element, for: key, priority: priority, expiredIn: duration)
            }
            // Otherwise, insert into the LRU queue
            return setToLRUQueue(now: now, element: element, for: key, priority: priority, expiredIn: duration)
        }
    }

    /// Retrieves the element for the given key if present and not expired.
    /// - Parameter key: The key to look up
    /// - Returns: The element if present and valid; otherwise nil (expired or missing)
    @discardableResult
    func getElement(for key: Key) -> Element? {
        guard let node = lruQueue.getElement(for: key) else { return nil }
        if node.expirationTimeStamp < .now() {
            _ = removeElement(for: key)
            return nil
        }
        return node.element
    }

    /// Removes the element for the given key, if present.
    /// - Parameter key: The key to remove
    /// - Returns: The removed element, or nil if not found
    @discardableResult
    func removeElement(for key: Key) -> Element? {
        if let node = lruQueue.removeElement(for: key) {
            if let nodeIndex = node.ttlIndex {
                _ = ttlQueue.remove(at: nodeIndex)
                return node.element
            }
            return node.element
        }
        return nil
    }

    /// Removes and returns one element following expiration/priority/LRU rules.
    /// - Returns: The removed element, or nil if the cache is empty
    @discardableResult
    func removeElement() -> Element? {
        guard let root = ttlQueue.root else { return nil }

        if root.expirationTimeStamp < .now() {
            return removeElement(for: root.key)
        }

        // Get the least recently used key from the LRU queue
        guard let leastRecentKey = lruQueue.getLeastRecentKey() else { return nil }
        return removeElement(for: leastRecentKey)
    }

    /**
     Removes all expired elements from the cache.

     Iteratively checks the TTL heap root (earliest expiration) and removes expired entries
     until the root is not expired. This ensures efficient cleanup without scanning all keys.

     - Note: O(k) where k is the number of expired entries removed.
     */
    func removeExpiredElements() {
        while let root = ttlQueue.root {
            if root.expirationTimeStamp >= .now() {
                return
            }
            removeElement(for: root.key)
        }
    }
}

private extension TTLPriorityLRUQueue {
    /// Internal: Insert into TTL heap and update LRU queue.
    func setToTTLQueue(
        now: CPUTimeStamp,
        element: Element,
        for key: Key,
        priority: Double,
        expiredIn duration: TimeInterval
    ) -> Element? {
        var res: Element? = nil
        let node = Node(key: key, element: element, expirationTimeStamp: now + duration)
        if let pop = ttlQueue.insert(node, force: true) {
            _ = lruQueue.removeElement(for: pop.key)
            res = pop.element
        }
        _ = lruQueue.setElement(node, for: key, with: priority)
        return res
    }

    /// Internal: Insert into LRU queue and update TTL heap.
    func setToLRUQueue(
        now: CPUTimeStamp,
        element: Element,
        for key: Key,
        priority: Double,
        expiredIn duration: TimeInterval
    ) -> Element? {
        var res: Element? = nil
        let node = Node(key: key, element: element, expirationTimeStamp: now + duration)
        if let pop = lruQueue.setElement(node, for: key, with: priority), let ttlIndex = pop.ttlIndex {
            _ = ttlQueue.remove(at: ttlIndex)
            res = pop.element
        }
        _ = ttlQueue.insert(node, force: true)
        return res
    }
}

private extension TTLPriorityLRUQueue {
    /// Internal node type for tracking key, element, expiration, and heap index.
    class Node {
        /// The key for this entry.
        let key: Key
        /// The element for this entry.
        let element: Element
        /// The expiration timestamp for this entry.
        let expirationTimeStamp: CPUTimeStamp
        /// The index of this node in the TTL heap, if present.
        var ttlIndex: Int?

        init(key: Key, element: Element, expirationTimeStamp: CPUTimeStamp) {
            self.key = key
            self.element = element
            self.expirationTimeStamp = expirationTimeStamp
            ttlIndex = nil
        }
    }
}
