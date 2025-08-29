import Foundation
import Monstra

/// Repository encapsulating fetching posts via KVLightTasksManager with execution merging and caching.
/// This represents a Data-layer implementation in a Clean Architecture setup.
final class PostRepository {
    private typealias PostsManager = KVLightTasksManager<String, Post>

    private let manager: PostsManager

    init() {
        // Detailed cache configuration for demo
        let cacheConfig: MemoryCache<String, Post>.Configuration = .init(
            enableThreadSynchronization: true,
            memoryUsageLimitation: .init(capacity: 1000, memory: 10), // capacity items, memory in MB
            defaultTTL: 300.0,                   // 5 minutes for successful posts
            defaultTTLForNullElement: 60.0,      // 1 minute for not-found/invalid IDs
            ttlRandomizationRange: 3.0,          // jitter to avoid stampede
            keyValidator: { id in                // accept only [A-Za-z0-9_-]
                return !id.isEmpty && id.range(of: "[^a-zA-Z0-9_-]", options: .regularExpression) == nil
            },
            costProvider: { post in              // approximate memory cost in bytes
                post.id.utf8.count
                + post.title.utf8.count
                + post.body.utf8.count
                + post.author.utf8.count
                + MemoryLayout<Date>.size
            }
        )

        // Manager configuration with batching, concurrency, priority and retry
        let config = PostsManager.Config(
            dataProvider: .asyncMultiprovide(maximumBatchCount: 2, MockAPI.fetchPosts),
            maxNumberOfQueueingTasks: 256,
            maxNumberOfRunningTasks: 4,
            retryCount: 1,                      // retry once on failure
            PriorityStrategy: .FIFO,             // fair processing order
            cacheConfig: cacheConfig,
            cacheStatisticsReport: nil
        )
        manager = PostsManager(config: config)
    }

    /// Fetch a single post by id with execution merging and caching
    func getPost(id: String, completion: @escaping (Result<Post?, Error>) -> Void) {
        manager.fetch(key: id) { _, result in
            completion(result)
        }
    }

    /// Fetch multiple posts by ids with batch API and caching
    func getPosts(ids: [String], completion: @escaping (_ id: String, _ result: Result<Post?, Error>) -> Void) {
        manager.fetch(keys: ids) { id, result in
            completion(id, result)
        }
    }

    /// Fetch multiple posts and receive a single aggregated callback
    func getPostsBatch(ids: [String], completion: @escaping (_ results: [String: Result<Post?, Error>]) -> Void) {
        manager.fetch(keys: ids, multiCallback: { aggregated in
            var mapped: [String: Result<Post?, Error>] = [:]
            for (id, result) in aggregated {
                mapped[id] = result
            }
            completion(mapped)
        })
    }
}
