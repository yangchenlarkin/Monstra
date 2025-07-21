//
//  KVTasks.swift
//  Monstask
//
//  Created by Larkin on 2025/7/20.
//

import Foundation
import Monstore

extension KVTasks {
    enum DataPovider {
        case monofetch((K) async throws -> Element?)
        case multifetch(([K]) async throws -> [K: Element])
    }
}

public class KVTasks<K: Hashable, Element> {
    private let cache = Monstore.MemoryCache<K, Element>()
    private let dataProvider: DataPovider
    
    init(dataProvider: DataPovider) {
        self.dataProvider = dataProvider
    }
    
    public func fetchValue(for key: K) -> Element? {
        let result = cache.getValue(for: key)
        switch result {
        case .hitNonNullValue(let value):
            return value
        default:
            return nil
        }
    }
    
    public func fetchValues(for keys: [K]) -> [K: Element] {
        [:]
    }
}
