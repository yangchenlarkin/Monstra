import Foundation

protocol LRUQueueProtocol {
    associatedtype K: Hashable
    associatedtype Element
    var capacity: Int { get }
    var count: Int { get }
    var isEmpty: Bool { get }
    var isFull: Bool { get }
    
    @discardableResult
    func setValue(_ value: Element, for key: K) -> Element?
    func getValue(for key: K) -> Element?
    @discardableResult
    func removeValue(for key: K) -> Element?
} 