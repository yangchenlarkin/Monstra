/// A generic heap (priority queue) supporting custom ordering and capacity limits.
public class Heap<Element> {
    /// Maximum number of elements the heap can store.
    private let capacity: Int

    /// Current number of valid elements.
    private(set) var count: Int

    /// Comparison function to determine heap order.
    private let compare: (Element, Element) -> ComparisonResult

    /// Internal backing storage (using Swift Array's automatic expansion).
    private var storage: [Element]

    /// Callback triggered on insert, remove, and index changes.
    public var onEvent: ((Event) -> Void)?

    /// The root element (highest priority), or nil if heap is empty.
    public var root: Element? { storage.first }

    /// All elements currently in the heap.
    public var elements: [Element] { storage }

    /// Initializes a heap with given capacity and comparison strategy.
    public required init(capacity: Int, compare: @escaping (Element, Element) -> ComparisonResult) {
        self.capacity = max(0, capacity)
        count = 0
        self.compare = compare
        // Let Swift Array handle automatic expansion
        storage = []
    }
}

// MARK: - Static Min/Max Heaps for Comparable

public extension Heap where Element: Comparable {
    /// Returns a max heap (largest elements at root).
    static func maxHeap(capacity: Int) -> Self {
        .init(capacity: capacity) {
            if $0 > $1 { return .moreTop }
            if $0 < $1 { return .moreBottom }
            return .equal
        }
    }

    /// Returns a min heap (smallest elements at root).
    static func minHeap(capacity: Int) -> Self {
        .init(capacity: capacity) {
            if $0 < $1 { return .moreTop }
            if $0 > $1 { return .moreBottom }
            return .equal
        }
    }
}

// MARK: - Public Heap Operations

public extension Heap {
    /// Inserts an element into the heap.
    /// - Parameters:
    ///   - element: Element to insert.
    ///   - force: If true, replaces root if heap is full and element has lower priority.
    /// - Returns: Displaced root if force-inserted, otherwise nil.
    @discardableResult
    func insert(_ element: Element, force: Bool = false) -> Element? {
        guard capacity > 0 else { return element }

        if count == capacity {
            guard let root = storage.first else {
                storage.append(element)
                count += 1
                onEvent?(.insert(element: element, at: 0))
                return nil
            }
            let cmp = compare(element, root)

            if force {
                // Force insertion: reject if element has higher priority than root
                guard cmp != .moreTop else { return element }
            } else {
                // Normal insertion: only allow if element has lower priority than root
                guard cmp == .moreBottom else { return element }
            }
            let removed = root
            storage[0] = element
            onEvent?(.insert(element: element, at: 0))
            onEvent?(.remove(element: removed))
            heapify(from: 0)
            return removed
        }

        // Let Swift Array handle automatic expansion
        storage.append(element)
        count += 1
        onEvent?(.insert(element: element, at: count - 1))
        siftUp(from: count - 1)
        return nil
    }

    /// Removes and returns an element at the specified index (default: root).
    /// - Parameter index: Index of element to remove (defaults to root at index 0).
    /// - Returns: Removed element, or nil if index is invalid or heap is empty.
    @discardableResult
    func remove(at index: Int = 0) -> Element? {
        guard capacity > 0, count > 0, isValid(index) else { return nil }

        let removed = storage[index]
        count -= 1

        if index != count {
            storage[index] = storage[count]
            onEvent?(.move(element: storage[index], to: index))
            heapify(from: index)
        }

        storage.removeLast()
        onEvent?(.remove(element: removed))
        return removed
    }
}

// MARK: - Event & Comparison Enums

public extension Heap {
    /// Heap event used for notifications.
    enum Event {
        case insert(element: Element, at: Int)
        case remove(element: Element)
        case move(element: Element, to: Int)
    }

    /// Relative priority between two elements.
    enum ComparisonResult {
        case moreTop
        case moreBottom
        case equal
    }
}

// MARK: - Internal Helpers

private extension Heap {
    /// Swaps two elements at the specified indices and triggers move events.
    /// - Parameters:
    ///   - i: First element index.
    ///   - j: Second element index.
    func swapElements(at i: Int, and j: Int) {
        storage.swapAt(i, j)
        onEvent?(.move(element: storage[i], to: i))
        onEvent?(.move(element: storage[j], to: j))
    }

    /// Restores heap property starting from the given index.
    /// - Parameter index: Starting index for heapification.
    func heapify(from index: Int) {
        guard isValid(index) else { return }

        switch (isRoot(index), isLeaf(index)) {
        case (true, true), (false, true):
            return
        case (true, false):
            siftDown(from: index)
        case (false, false):
            if compareAt(index, with: parentIndex(of: index)) == .moreTop {
                siftUp(from: index)
            } else {
                siftDown(from: index)
            }
        }
    }

    /// Moves an element up the heap to restore heap property.
    /// - Parameter index: Starting index for sift-up operation.
    func siftUp(from index: Int) {
        var currentIndex = index
        while isValid(currentIndex) {
            let parent = parentIndex(of: currentIndex)
            guard compareAt(currentIndex, with: parent) == .moreTop else { return }
            swapElements(at: currentIndex, and: parent)
            currentIndex = parent
        }
    }

    /// Moves an element down the heap to restore heap property.
    /// - Parameter index: Starting index for sift-down operation.
    func siftDown(from index: Int) {
        var currentIndex = index
        while isValid(currentIndex) {
            let left = leftChildIndex(of: currentIndex)
            let right = rightChildIndex(of: currentIndex)
            let target: Int

            switch (isValid(left), isValid(right)) {
            case (true, true):
                if compareAt(left, with: right) == .moreTop {
                    target = left
                } else {
                    target = right
                }
            case (true, false):
                target = left
            case (false, true):
                target = right
            case (false, false):
                return
            }

            guard compareAt(currentIndex, with: target) == .moreBottom else { return }
            swapElements(at: currentIndex, and: target)
            currentIndex = target
        }
    }
}

// MARK: - Index Calculations

private extension Heap {
    /// Returns the parent index of the given index.
    func parentIndex(of index: Int) -> Int { (index - 1) / 2 }

    /// Returns the left child index of the given index.
    func leftChildIndex(of index: Int) -> Int { 2 * index + 1 }

    /// Returns the right child index of the given index.
    func rightChildIndex(of index: Int) -> Int { 2 * index + 2 }

    /// Returns true if the index is the root (index 0).
    func isRoot(_ index: Int) -> Bool { index == 0 }

    /// Returns true if the index is a leaf node (no children).
    func isLeaf(_ index: Int) -> Bool { leftChildIndex(of: index) >= count }

    /// Returns true if the index is within valid bounds.
    func isValid(_ index: Int) -> Bool { index >= 0 && index < count }

    /// Compares elements at the specified indices.
    /// - Parameters:
    ///   - i: First element index.
    ///   - j: Second element index.
    /// - Returns: Comparison result between the elements.
    func compareAt(_ i: Int, with j: Int) -> ComparisonResult {
        guard isValid(i), isValid(j) else {
            return .equal
        }
        return compare(storage[i], storage[j])
    }
}
