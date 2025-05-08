//
//  Heap.swift
//
//
//  Created by Larkin on 2025/5/6.
//

/// A generic heap data structure implementation that can be configured as either a min-heap or max-heap.
/// The heap maintains elements in a complete binary tree, satisfying the heap property.
struct Heap<Element> {/// Represents the relative positioning of elements in the heap structure
    enum ComparisonResult {
        /// First element should be closer to the root than the second element
        case upper
        
        /// First element should be closer to leaves than the second element
        case lower
        
        /// Elements have equal positioning priority
        case equal
    }

    
    /// Maximum number of elements the heap can store
    private let capacity: Int
    
    /// Current number of elements in the heap
    private(set) var count: Int
    
    /// Comparison function that defines the heap property
    private let compareElements: (Element, Element) -> ComparisonResult
    
    /// Internal storage for heap elements
    private var storage: [Element?]
    
    /// Returns all non-nil values in the heap
    var elements: [Element] { storage.compactMap { $0 } }
    
    /// Initializes a new heap with specified capacity and comparison function
    /// - Parameters:
    ///   - capacity: Maximum number of elements the heap can store
    ///   - compare: Function that defines the ordering of elements
    init(capacity: Int, compare: @escaping (Element, Element) -> ComparisonResult) {
        self.capacity = capacity
        self.count = 0
        self.compareElements = compare
        self.storage = [Element?](repeating: nil, count: capacity)
    }
}

// MARK: - Comparable Conformance
extension Heap where Element: Comparable {
    /// Creates a max heap with the specified capacity
    /// - Parameter capacity: Maximum number of elements the heap can store
    /// - Returns: A new max heap instance
    static func maxHeap(capacity: Int) -> Self {
        .init(capacity: capacity) {
            if $0 > $1 { return .upper }
            if $0 < $1 { return .lower }
            return .equal
        }
    }
    
    /// Creates a min heap with the specified capacity
    /// - Parameter capacity: Maximum number of elements the heap can store
    /// - Returns: A new min heap instance
    static func minHeap(capacity: Int) -> Self {
        .init(capacity: capacity) {
            if $0 < $1 { return .upper }
            if $0 > $1 { return .lower }
            return .equal
        }
    }
}

// MARK: - Core Operations
extension Heap {
    /// Inserts a value into the heap
    /// - Parameters:
    ///   - element: The element to insert
    ///   - forceInsert: If true, replaces root when heap is full
    /// - Returns: Displaced root element if force insert occurs on full heap
    mutating func insert(_ element: Element, forceInsert: Bool = false) -> Element? {
        guard capacity > 0 else { return element }
        
        if count == capacity {
            guard forceInsert else { return element }
            let root = storage[0]
            storage[0] = element
            heapify(at: 0)
            return root
        }
        
        storage[count] = element
        count += 1
        siftUp(from: count - 1)
        return nil
    }
    
    /// Removes and returns an element at the specified index
    /// - Parameter index: Index of element to remove (defaults to root)
    /// - Returns: The removed element, if it exists
    mutating func remove(at index: Int = 0) -> Element? {
        guard capacity > 0,
              count > 0,
              validIndex(index) else { return nil }
        
        count -= 1
        if index != count {
            storage.swapAt(index, count)
        }
        
        defer {
            storage[count] = nil
            if index != count {
                heapify(at: index)
            }
        }
        return storage[count]
    }
}

// MARK: - Heap Operations
private extension Heap {
    /// Restores heap property starting from specified index
    mutating func heapify(at index: Int) {
        guard validIndex(index) else { return }
        
        switch (isRoot(index), isLeaf(index)) {
        case (true, true): return
        case (false, true): return siftUp(from: index)
        case (true, false): return siftDown(from: index)
        case (false, false):
            if compare(at: index, with: parentIndex(of: index)) == .upper {
                siftUp(from: index)
            } else {
                siftDown(from: index)
            }
        }
    }
    
    /// Moves element up the heap until heap property is restored
    mutating func siftUp(from index: Int) {
        var currentIndex = index
        while validIndex(currentIndex) {
            let parent = parentIndex(of: currentIndex)
            guard compare(at: currentIndex, with: parent) == .upper else { return }
            
            storage.swapAt(currentIndex, parent)
            currentIndex = parent
        }
    }
    
    /// Moves element down the heap until heap property is restored
    mutating func siftDown(from index: Int) {
        var currentIndex = index
        while validIndex(currentIndex) {
            let left = leftChildIndex(of: currentIndex)
            let right = rightChildIndex(of: currentIndex)
            let target: Int
            
            if compare(at: left, with: right) == .upper {
                target = left
            } else {
                target = right
            }
            
            guard compare(at: currentIndex, with: target) == .lower else { return }
            
            storage.swapAt(currentIndex, target)
            currentIndex = target
        }
    }
}

// MARK: - Helper Methods
private extension Heap {
    /// Range of valid indices in the heap
    var validIndices: Range<Int> { 0..<count }
    
    /// Checks if index is within valid range
    func validIndex(_ index: Int) -> Bool {
        validIndices.contains(index)
    }
    
    /// Returns parent index for given node index
    func parentIndex(of index: Int) -> Int {
        (index - 1) / 2
    }
    
    /// Returns left child index for given node index
    func leftChildIndex(of index: Int) -> Int {
        2 * index + 1
    }
    
    /// Returns right child index for given node index
    func rightChildIndex(of index: Int) -> Int {
        2 * index + 2
    }
    
    /// Checks if node is a leaf node
    func isLeaf(_ index: Int) -> Bool {
        leftChildIndex(of: index) >= count
    }
    
    /// Checks if node is the root
    func isRoot(_ index: Int) -> Bool {
        index == 0
    }
    
    /// Compares elements at two indices
    func compare(at targetIndex: Int, with referenceIndex: Int) -> ComparisonResult? {
        guard validIndex(targetIndex),
              validIndex(referenceIndex),
              let target = storage[targetIndex],
              let reference = storage[referenceIndex] else { return nil }
        
        return compareElements(target, reference)
    }
}
