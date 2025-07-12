//
//  Heap.swift
//  Monstore
//
//  Created by Larkin on 2025/5/6.
//

/// A generic heap (priority queue) supporting custom ordering and capacity limits.
class Heap<Element> {
    /// Maximum number of elements the heap can store.
    private let capacity: Int

    /// Current number of valid elements.
    private(set) var count: Int

    /// Comparison function to determine heap order.
    private let compare: (Element, Element) -> ComparisonResult

    /// Internal backing storage (fixed-size array with optionals).
    private var storage: [Element?]

    /// Callback triggered on insert, remove, and index changes.
    var onEvent: ((Event) -> Void)? = nil

    /// The root element (highest priority), or nil if heap is empty.
    var root: Element? { storage.first ?? nil }

    /// All non-nil elements currently in the heap.
    var elements: [Element] { storage.compactMap { $0 } }

    /// Initializes a heap with given capacity and comparison strategy.
    required init(capacity: Int, compare: @escaping (Element, Element) -> ComparisonResult) {
        self.capacity = max(0, capacity)
        self.count = 0
        self.compare = compare
        self.storage = Array(repeating: nil, count: self.capacity)
    }
}

// MARK: - Static Min/Max Heaps for Comparable

extension Heap where Element: Comparable {
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

extension Heap {
    /// Inserts an element into the heap.
    /// - Parameters:
    ///   - element: Element to insert.
    ///   - force: If true, replaces root if heap is full.
    /// - Returns: Displaced root if force-inserted, otherwise nil.
    func insert(_ element: Element, force: Bool = false) -> Element? {
        guard capacity > 0 else { return element }

        if count == capacity {
            guard let root = storage[0] else {
                assign(element, at: 0)
                heapify(from: 0)
                return nil
            }
            let cmp = compare(element, root)
            
            if force {
                // rule 1: force == true, but element is moreTop → reject
                guard cmp != .moreTop else { return element }
            } else {
                // rule 2: force == false, only allow if element is moreBottom
                guard cmp == .moreBottom else { return element }
            }
            let removed = root
            assign(element, at: 0)
            heapify(from: 0)
            return removed
        }

        assign(element, at: count)
        count += 1
        siftUp(from: count - 1)
        return nil
    }

    /// Removes and returns an element at the specified index (default: root).
    func remove(at index: Int = 0) -> Element? {
        guard capacity > 0, count > 0, isValid(index) else { return nil }

        count -= 1
        if index != count {
            swapElements(at: index, and: count)
        }

        defer {
            removeElement(at: count)
            if index != count {
                heapify(from: index)
            }
        }

        return storage[count]
    }
}

// MARK: - Event & Comparison Enums

extension Heap {
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
    func assign(_ element: Element, at index: Int) {
        let previous = storage[index]
        storage[index] = element
        onEvent?(.insert(element: element, at: index))
        if let previous {
            onEvent?(.remove(element: previous))
        }
    }

    func swapElements(at i: Int, and j: Int) {
        storage.swapAt(i, j)
        if let e1 = storage[i] { onEvent?(.move(element: e1, to: i)) }
        if let e2 = storage[j] { onEvent?(.move(element: e2, to: j)) }
    }

    func removeElement(at index: Int) {
        if let removed = storage[index] {
            storage[index] = nil
            onEvent?(.remove(element: removed))
        }
    }

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

    func siftUp(from index: Int) {
        var idx = index
        while isValid(idx) {
            let parent = parentIndex(of: idx)
            guard compareAt(idx, with: parent) == .moreTop else { return }
            swapElements(at: idx, and: parent)
            idx = parent
        }
    }

    func siftDown(from index: Int) {
        var idx = index
        while isValid(idx) {
            let left = leftChildIndex(of: idx)
            let right = rightChildIndex(of: idx)
            let target: Int

            if compareAt(left, with: right) == .moreTop {
                target = left
            } else {
                target = right
            }

            guard compareAt(idx, with: target) == .moreBottom else { return }
            swapElements(at: idx, and: target)
            idx = target
        }
    }
}

// MARK: - Index Calculations

private extension Heap {
    func parentIndex(of index: Int) -> Int { (index - 1) / 2 }
    func leftChildIndex(of index: Int) -> Int { 2 * index + 1 }
    func rightChildIndex(of index: Int) -> Int { 2 * index + 2 }

    func isRoot(_ index: Int) -> Bool { index == 0 }
    func isLeaf(_ index: Int) -> Bool { leftChildIndex(of: index) >= count }
    func isValid(_ index: Int) -> Bool { index >= 0 && index < count }

    func compareAt(_ i: Int, with j: Int) -> ComparisonResult {
        guard isValid(i), isValid(j),
              let e1 = storage[i], let e2 = storage[j] else {
            return .equal
        }
        return compare(e1, e2)
    }
}
