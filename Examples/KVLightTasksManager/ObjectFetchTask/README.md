<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

# Object Fetch Task Example

An example demonstrating how to batch-fetch domain objects using the Monstra framework's `KVLightTasksManager` with execution merging and caching. It simulates three ViewModels running concurrently and fetching overlapping post IDs via a repository that wraps the tasks manager and a mocked API.

## 1. How to Run This Example

### 1.1 Requirements

- **Platforms**:
  - iOS 13.0+
  - macOS 10.15+
  - tvOS 13.0+
  - watchOS 6.0+
- **Swift**: 5.5+
- **Dependencies**:
  - Monstra framework (local development version)

### 1.2 Download the Repo

```bash
git clone https://github.com/yangchenlarkin/Monstra.git
cd Monstra/Examples/KVLightTasksManager/ObjectFetchTask
```

### 1.3 Open ObjectFetchTask Using Xcode

```bash
# From the ObjectFetchTask directory
xed Package.swift
```

Or manually in Xcode:
1. Open Xcode
2. Go to `File → Open...`
3. Navigate to the `ObjectFetchTask` folder
4. Select `Package.swift` (not the root Monstra project)
5. Click Open

This opens the example as a standalone Swift package.

## 2. Code Explanation

### 2.1 Post (Domain Model)

Minimal model used for demonstration:

```swift
struct Post: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let body: String
    let author: String
    let publishedAt: Date
}
```

### 2.2 MockAPI (Data Source)

Simulates network latency and returns deterministic `Post` objects for valid alphanumeric IDs; invalid IDs return `nil`.

```swift
enum MockAPI {
    static func fetchPosts(ids: [String]) async throws -> [String: Post?] { /* ... */ }
}
```

### 2.3 PostRepository (Data Layer)

Wraps `KVLightTasksManager<String, Post>` with `.asyncMultiprovide` to batch-fetch posts and exposes:

- `getPost(id:)` for single fetch with execution merging and cache
- `getPosts(ids:)` for per-key callbacks over a list
- `getPostsBatch(ids:)` for a single aggregated callback

Simple init (quick start):

```swift
final class PostRepository {
    private typealias PostsManager = KVLightTasksManager<String, Post>
    private let manager: PostsManager
    init() {
        // Minimal setup with batching only (use detailed config below for full control)
        manager = PostsManager(maximumBatchCount: 2, MockAPI.fetchPosts)
    }

    // ... other methods
}
```

Notes:
- `maximumBatchCount` is set to 2 for demonstration and easier log inspection. Increase it in real apps.

Detailed configuration (production-oriented):

```swift
final class PostRepository {
    private typealias PostsManager = KVLightTasksManager<String, Post>
    private let manager: PostsManager
    init() {
        // Detailed cache configuration
        let cacheConfig: MemoryCache<String, Post>.Configuration = .init(
            enableThreadSynchronization: true,
            memoryUsageLimitation: .init(capacity: 1000, memory: 10), // capacity items, memory in MB
            defaultTTL: 300.0,                  // 5 minutes for successful posts
            defaultTTLForNullElement: 60.0,     // 1 minute for not-found/invalid IDs
            ttlRandomizationRange: 3.0,         // jitter to avoid stampede
            keyValidator: { id in               // Demo-only: accept [A-Za-z0-9_-]. Update or remove in production.
                return !id.isEmpty && id.range(of: "[^a-zA-Z0-9_-]", options: .regularExpression) == nil
            },
            costProvider: { post in             // approximate memory cost in bytes
                post.id.utf8.count
                + post.title.utf8.count
                + post.body.utf8.count
                + post.author.utf8.count
                + MemoryLayout<Date>.size
            }
        )

        // Manager configuration (batching, concurrency, priority, retry)
        let config = PostsManager.Config(
            dataProvider: .asyncMultiprovide(maximumBatchCount: 2, MockAPI.fetchPosts),
            maxNumberOfQueueingTasks: 256,
            maxNumberOfRunningTasks: 4,
            retryCount: 1,                 // retry once on failure
            PriorityStrategy: .FIFO,        // fair processing order
            cacheConfig: cacheConfig
        )
        manager = PostsManager(config: config)
    }
    // ... other methods
}
```

#### Fetch methods (public API)

```swift
final class PostRepository {
    // ... other methods

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
```

Note:
- The `keyValidator` above is intentionally strict for demonstration. In production, adapt the validation to your real ID format (or remove it entirely) to avoid dropping valid requests.

### 2.4 Usage (in main)

`main.swift` runs three concurrent ViewModels to demonstrate execution merging and batching:

- **Detail ViewModel**: fetch one post by id
- **Favorites ViewModel**: fetch a list of posts
- **Carousel ViewModel**: fetch another list of posts (overlaps with others)

```swift
let repository = PostRepository()
let detailID = "101"
let favorites = ["101", "102", "103", "bad id", "104", "102"]
let recommendations = ["103", "104", "105", "101", "bad id", "105"]

// Three concurrent view models
mockPostDetailViewModel()
mockFavoritesViewModel()
mockRecommendationsCarouselModel()
```

## 3. Key Behavior & Logs

### 3.1 Execution Merging & Batching

- Multiple consumers requesting the same ID get a single execution and shared results
- Pending unique keys are grouped per batch and sent together to the data source (fewer round-trips)
- Cache stores results; repeated requests return quickly without refetching

### 3.2 Sample Logs

From a sample run of this example:

```
Starting concurrent ViewModels (detail + favorites + carousel) ...
[Detail ViewModel] start fetch, ids=[101]
[MockAPI] start fetch, ids=["101"]
[Favorites ViewModel] start fetch, ids=["101", "102", "103", "bad id", "104", "102"]
[MockAPI] start fetch, ids=["102", "103"]
[Carousel ViewModel] start fetch, ids=["103", "104", "105", "101", "bad id", "105"]
[MockAPI] start fetch, ids=["bad id", "104"]
[MockAPI] start fetch, ids=["105"]
[MockAPI] finish fetch, ids=["101"]
[MockAPI] finish fetch, ids=["102", "103"]
[MockAPI] finish fetch, ids=["105"]
[MockAPI] finish fetch, ids=["bad id", "104"]
[Detail ViewModel] ✓ 101: Post #101
[Detail ViewModel] finish fetch, ids=[101]
[Carousel ViewModel] completed: ok=5 miss=1
[Carousel ViewModel] finish fetch, ids=["103", "104", "105", "101", "bad id", "105"]
[Favorites ViewModel] completed: ok=5 miss=1
[Favorites ViewModel] finish fetch, ids=["101", "102", "103", "bad id", "104", "102"]
All viewModels done.
```

What this demonstrates:
- Requests for overlapping IDs are batched (see MockAPI grouped ids)
- Invalid IDs are filtered by the data source and return `nil`
- Single execution feeds multiple ViewModels due to execution merging

## 4. Clean Architecture Notes

- **PostRepository**: Data layer implementation (wraps tasks manager + data source)
- **Domain Layer**: Define `PostRepositoryProtocol` interface for the repository
- **Presentation Layer**: ViewModels depend on the domain interface and receive repository via DI

## 5. Implementation Details

### Current Code Structure
- `Package.swift` — SPM manifest (Monstra dependency)
- `Sources/ObjectFetchTask/Post.swift` — domain model
- `Sources/ObjectFetchTask/MockAPI.swift` — mocked data source
- `Sources/ObjectFetchTask/PostRepository.swift` — repository wrapping `KVLightTasksManager`
- `Sources/ObjectFetchTask/main.swift` — concurrent ViewModels demo

### Key Implementation Points
- `KVLightTasksManager<String, Post>` with `.asyncMultiprovide(maximumBatchCount: 2)`
- Priority strategy: **FIFO**; Concurrency: **4 running**, **256 queued**
- Retry: **1** attempt with default fixed interval
- Cache config: capacity **1000**, memory **10MB**, default TTLs (**300s** success, **60s** null)
- TTL jitter (**±3s**) to prevent stampede; key validation `[A-Za-z0-9_-]`
- `costProvider` approximates bytes from `Post` fields
- Shared caching and execution merging across ViewModels
- Deterministic mock data for repeatable runs

---

For details about cache configuration and cost units, see the root project README and `Sources/Monstore/MemoryCache/README.md`.

