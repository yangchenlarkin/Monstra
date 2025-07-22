//
//  KVLightTasks.swift
//  Monstask
//
//  Created by Larkin on 2025/7/20.
//

import Foundation
import Monstore
import MonstraBase

public extension KVLightTasks {
    enum DataPovider {
        case monofetch((K) async throws -> Element?)
        case multifetch(maxmumBatchCount: UInt, ([K]) async throws -> [K: Element])
    }
    
    struct Config {
        public let dataProvider: DataPovider
        
        public let maxmumTaskNumberInQueue: Int = 1024
        public let maxmumConcurrentRunningTaskNumber: Int = 4
        public let retryCount: RetryCount = 1
    }
}

public class KVLightTasks<K: Hashable, Element> {
    private let cache = Monstore.MemoryCache<K, Element>()
    private let keyQueue: KeyQueue<K>
    private let config: Config
    
    private var fetchingKeys = Set<K>()
    private var lock = NSLock()
    
    public init(config: Config) {
        self.config = config
        self.keyQueue = .init(capacity: config.maxmumTaskNumberInQueue)
    }
}
