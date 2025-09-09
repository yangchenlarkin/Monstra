<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

[English](README.md) | **简体中文**

# 对象获取任务示例

一个演示如何使用Monstra框架的`KVLightTasksManager`批量获取领域对象的示例，具有执行合并和缓存功能。它模拟三个ViewModel并发运行，并通过包装任务管理器和模拟API的仓储获取重叠的帖子ID。

## 1. 如何运行此示例

### 1.1 要求

- **支持平台**:
  - iOS 13.0+
  - macOS 10.15+
  - tvOS 13.0+
  - watchOS 6.0+
- **Swift**: 5.5+
- **依赖项**:
  - Monstra框架（本地开发版本）

### 1.2 下载仓库

```bash
git clone https://github.com/yangchenlarkin/Monstra.git
cd Monstra/Examples/KVLightTasksManager/ObjectFetchTask
```

### 1.3 使用Xcode打开ObjectFetchTask

```bash
# 从ObjectFetchTask目录
xed Package.swift
```

或在Xcode中手动操作：
1. 打开Xcode
2. 选择 `File → Open...`
3. 导航到 `ObjectFetchTask` 文件夹
4. 选择 `Package.swift`（不是根Monstra项目）
5. 点击打开

这将示例作为独立的Swift包打开。

## 2. 代码说明

### 2.1 Post（领域模型）

用于演示的最小模型：

```swift
struct Post: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let body: String
    let author: String
    let publishedAt: Date
}
```

### 2.2 MockAPI（数据源）

模拟网络延迟，为有效的字母数字ID返回确定性的`Post`对象；无效ID返回`nil`。

```swift
enum MockAPI {
    static func fetchPosts(ids: [String]) async throws -> [String: Post?] { /* ... */ }
}
```

### 2.3 PostRepository（数据层）

使用`.asyncMultiprovide`包装`KVLightTasksManager<String, Post>`来批量获取帖子，并公开：

- `getPost(id:)` 用于具有执行合并和缓存的单一获取
- `getPosts(ids:)` 用于列表的每键回调
- `getPostsBatch(ids:)` 用于单一聚合回调

简单初始化（快速开始）：

```swift
final class PostRepository {
    private typealias PostsManager = KVLightTasksManager<String, Post>
    private let manager: PostsManager
    init() {
        // 仅批处理的最小设置（详细配置见下文以完全控制）
        manager = PostsManager(maximumBatchCount: 2, MockAPI.fetchPosts)
    }

    // ... 其他方法
}
```

注意：
- `maximumBatchCount`设置为2用于演示和更容易的日志检查。在实际应用中增加它。

详细配置（面向生产）：

```swift
final class PostRepository {
    private typealias PostsManager = KVLightTasksManager<String, Post>
    private let manager: PostsManager
    init() {
        // 详细的缓存配置
        let cacheConfig: MemoryCache<String, Post>.Configuration = .init(
            enableThreadSynchronization: true,
            memoryUsageLimitation: .init(capacity: 1000, memory: 10), // 容量项目，内存单位MB
            defaultTTL: 300.0,                  // 成功帖子5分钟
            defaultTTLForNullElement: 60.0,     // 未找到/无效ID 1分钟
            ttlRandomizationRange: 3.0,         // 抖动避免雪崩
            keyValidator: { id in               // 仅演示：接受[A-Za-z0-9_-]。在生产中更新或删除。
                return !id.isEmpty && id.range(of: "[^a-zA-Z0-9_-]", options: .regularExpression) == nil
            },
            costProvider: { post in             // 字节的大致内存成本
                post.id.utf8.count
                + post.title.utf8.count
                + post.body.utf8.count
                + post.author.utf8.count
                + MemoryLayout<Date>.size
            }
        )

        // 管理器配置（批处理、并发性、优先级、重试）
        let config = PostsManager.Config(
            dataProvider: .asyncMultiprovide(maximumBatchCount: 2, MockAPI.fetchPosts),
            maxNumberOfQueueingTasks: 256,
            maxNumberOfRunningTasks: 4,
            retryCount: 1,                 // 失败时重试一次
            PriorityStrategy: .FIFO,        // 公平处理顺序
            cacheConfig: cacheConfig
        )
        manager = PostsManager(config: config)
    }
    // ... 其他方法
}
```

#### 获取方法（公共API）

```swift
final class PostRepository {
    // ... 其他方法

    /// 通过id获取单一帖子，具有执行合并和缓存
    func getPost(id: String, completion: @escaping (Result<Post?, Error>) -> Void) {
        manager.fetch(key: id) { _, result in
            completion(result)
        }
    }

    /// 通过ids获取多个帖子，具有批处理API和缓存
    func getPosts(ids: [String], completion: @escaping (_ id: String, _ result: Result<Post?, Error>) -> Void) {
        manager.fetch(keys: ids) { id, result in
            completion(id, result)
        }
    }

    /// 获取多个帖子并接收单一聚合回调
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

注意：
- 上面的`keyValidator`故意严格用于演示。在生产中，将验证适配到您的实际ID格式（或完全删除它）以避免丢弃有效请求。

### 2.4 使用方法（在main中）

`main.swift`运行三个并发ViewModels来演示执行合并和批处理：

- **详细ViewModel**：通过id获取一个帖子
- **收藏ViewModel**：获取帖子列表
- **轮播ViewModel**：获取另一个帖子列表（与其他重叠）

```swift
let repository = PostRepository()
let detailID = "101"
let favorites = ["101", "102", "103", "bad id", "104", "102"]
let recommendations = ["103", "104", "105", "101", "bad id", "105"]

// 三个并发视图模型
mockPostDetailViewModel()
mockFavoritesViewModel()
mockRecommendationsCarouselModel()
```

## 3. 关键行为与日志

### 3.1 执行合并与批处理

- 多个消费者请求相同ID获得单次执行和共享结果
- 待处理的唯一键按批次分组并一起发送到数据源（更少的往返）
- 缓存存储结果；重复请求快速返回而不重新获取

### 3.2 示例日志

来自此示例的运行示例：

```
开始并发ViewModels（详细 + 收藏 + 轮播）...
[详细ViewModel] 开始获取，ids=[101]
[MockAPI] 开始获取，ids=["101"]
[收藏ViewModel] 开始获取，ids=["101", "102", "103", "bad id", "104", "102"]
[MockAPI] 开始获取，ids=["102", "103"]
[轮播ViewModel] 开始获取，ids=["103", "104", "105", "101", "bad id", "105"]
[MockAPI] 开始获取，ids=["bad id", "104"]
[MockAPI] 开始获取，ids=["105"]
[MockAPI] 完成获取，ids=["101"]
[MockAPI] 完成获取，ids=["102", "103"]
[MockAPI] 完成获取，ids=["105"]
[MockAPI] 完成获取，ids=["bad id", "104"]
[详细ViewModel] ✓ 101: Post #101
[详细ViewModel] 完成获取，ids=[101]
[轮播ViewModel] 完成：成功=5 错过=1
[轮播ViewModel] 完成获取，ids=["103", "104", "105", "101", "bad id", "105"]
[收藏ViewModel] 完成：成功=5 错过=1
[收藏ViewModel] 完成获取，ids=["101", "102", "103", "bad id", "104", "102"]
所有viewModels完成。
```

这演示了什么：
- 重叠ID的请求被批处理（参见MockAPI分组的ids）
- 无效ID被数据源过滤并返回`nil`
- 由于执行合并，单次执行为多个ViewModels提供数据

## 4. 清洁架构说明

- **PostRepository**：数据层实现（包装任务管理器 + 数据源）
- **领域层**：为仓储定义`PostRepositoryProtocol`接口
- **表示层**：ViewModels依赖领域接口并通过DI接收仓储

## 5. 实现细节

### 当前代码结构
- `Package.swift` — SPM清单（Monstra依赖）
- `Sources/ObjectFetchTask/Post.swift` — 领域模型
- `Sources/ObjectFetchTask/MockAPI.swift` — 模拟数据源
- `Sources/ObjectFetchTask/PostRepository.swift` — 包装`KVLightTasksManager`的仓储
- `Sources/ObjectFetchTask/main.swift` — 并发ViewModels演示

### 关键实现要点
- `KVLightTasksManager<String, Post>`使用`.asyncMultiprovide(maximumBatchCount: 2)`
- 优先级策略：**FIFO**；并发性：**4个运行**，**256个排队**
- 重试：**1**次尝试，默认固定间隔
- 缓存配置：容量**1000**，内存**10MB**，默认TTLs（**300秒**成功，**60秒**null）
- TTL抖动（**±3秒**）防止雪崩；键验证`[A-Za-z0-9_-]`
- `costProvider`从`Post`字段近似字节数
- ViewModels间的共享缓存和执行合并
- 可重复运行的确定性模拟数据

---

有关缓存配置和成本单位的详细信息，请参见根项目README和`Sources/Monstore/MemoryCache/README.md`。
