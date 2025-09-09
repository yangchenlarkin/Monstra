<div align="center">
  <img src="Logo.png" alt="Monstra Logo" width="50%">
</div>

[![Swift](https://img.shields.io/badge/Swift-5.5-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![CocoaPods](https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg)](https://cocoapods.org)
[![Docs](https://img.shields.io/badge/docs-API%20Reference-blue)](https://yangchenlarkin.github.io/Monstra/)

[English](README.md) | **简体中文**

一个高性能的Swift框架，提供高效的任务执行、内存缓存和数据管理实用工具，具有智能执行合并、TTL缓存和重试逻辑功能。

文档：<a href="https://yangchenlarkin.github.io/Monstra/" target="_blank" rel="noopener noreferrer">API参考文档 (Jazzy)</a>  

## 🚀 特性

### Monstore - 缓存系统

#### MemoryCache
- **⏰ TTL & 优先级支持**：先进的生存时间功能，具有自动过期和可配置的基于优先级的淘汰策略
- **💥 雪崩保护**：智能TTL随机化防止缓存雪崩和同时过期级联
- **🛡️ 击穿保护**：全面的空值缓存和强大的键验证，增强可靠性d 
- **📊 统计与监控**：内置缓存统计、性能指标和实时监控功能

### Monstask - 任务执行框架

#### **MonoTask**

- **🔄 执行合并**：多个并发请求合并为单次执行
- **⏱️ TTL缓存**：结果缓存可配置持续时间，自动过期
- **🔄 高级重试逻辑**：指数退避、固定间隔和混合重试策略
- **🎯 手动缓存控制**：细粒度缓存失效，带有执行策略选项

#### **KVLightTasksManager**
- **📈 峰值削平**：通过基于优先级的调度防止过度的任务执行量（LIFO/FIFO策略，可配置限制）
- **🔄 批处理**：支持单个和批量数据提供，以提高后端执行效率
- **📊 并发执行**：可配置的并发任务限制（默认：4个运行，256个排队）
- **🎯 执行合并**：智能请求去重和合并，防止重复工作并优化资源使用
- **💾 结果缓存**：集成MemoryCache以优化性能

#### **KVHeavyTasksManager**
- **📊 进度跟踪**：实时进度更新，具有自定义事件发布和广播功能
- **🎯 基于优先级的调度**：高级LIFO/FIFO策略，支持智能中断
- **🔄 任务生命周期管理**：完整的启动/停止/恢复功能，保持提供者状态
- **📱 并发控制**：优化的并发执行限制（默认：2个运行，64个排队）
- **🎯 执行合并**：智能请求去重和合并，防止重复工作并优化资源使用
- **💾 结果缓存**：集成MemoryCache以增强性能和效率

## 🚀 快速开始

### 安装

#### Swift Package Manager（推荐）

在你的 `Package.swift` 中添加Monstra：

```swift
dependencies: [
    .package(url: "https://github.com/yangchenlarkin/Monstra.git", from: "0.1.0")
]
```

或直接在Xcode中添加：
1. File → Add Package Dependencies
2. 输入仓库URL：`https://github.com/yangchenlarkin/Monstra.git`
3. 选择要使用的版本

#### CocoaPods

在你的 `Podfile` 中添加Monstra：

```ruby
pod 'Monstra', '~> 0.1.0'
```

**注意**：Monstra作为统一框架发布，所以你可以一次获得所有组件。

## 🎯 何时使用各个组件

| 组件 | 最佳用于 | 关键特性 |
|-----------|----------|-------------|
| **MonoTask** | 单个昂贵操作 | 执行合并、TTL缓存、重试逻辑 |
| **KVLightTasksManager** | 快速、轻量级操作 | 批处理、键验证、高吞吐量 |
| **KVHeavyTasksManager** | 资源密集型操作 | 进度跟踪、生命周期管理、错误恢复 |

#### **各组件的使用场景**

- **MonoTask**：API调用、数据库查询、受益于缓存和去重的昂贵计算
- **KVLightTasksManager**：用户资料获取、搜索结果、配置加载、高频操作
- **KVHeavyTasksManager**：文件下载、视频处理、ML推理、带进度更新的长时间运行操作

## 💡 简单示例

### 1. MemoryCache
基本缓存操作，具有TTL、基于优先级和LRU淘汰。

**简单示例（默认配置）：**
```swift
import Monstra

// 使用默认配置创建基本缓存
let cache = MemoryCache<String, Int>()

// 设置不同优先级和TTL的值
cache.set(element: 42, for: "answer", priority: 10.0, expiredIn: 3600.0) // 1小时，高优先级
cache.set(element: 100, for: "score", priority: 1.0) // 默认TTL，低优先级
cache.set(element: nil, for: "user-999") // 缓存空值

// 使用FetchResult枚举获取值
switch cache.getElement(for: "answer") {
case .hitNonNullElement(let value):
    print("找到答案：\(value)")
case .hitNullElement:
    print("找到空值")
case .miss:
    print("键未找到或已过期")
case .invalidKey:
    print("无效键")
}

// 检查缓存状态
print("缓存计数：\(cache.count)")
print("缓存容量：\(cache.capacity)")
print("是否为空：\(cache.isEmpty)")
print("是否已满：\(cache.isFull)")

// 移除特定元素
let removed = cache.removeElement(for: "score")
print("已移除：\(removed ?? -1)")

// 清理过期元素
cache.removeExpiredElements()
```

**详细配置示例：**
```swift
// 所有选项的高级配置
let imageCache = MemoryCache<String, Data>(
    configuration: .init(
        // 线程安全：为并发访问启用DispatchSemaphore同步
        enableThreadSynchronization: true,
        
        // 内存和容量限制：最多100项，50MB内存使用
        memoryUsageLimitation: .init(
            capacity: 100,    // 缓存项的最大数量
            memory: 50        // 最大内存使用量（MB）
        ),
        
        // TTL设置：项目在缓存中停留的时间
        defaultTTL: 1800.0,              // 常规元素30分钟
        defaultTTLForNullElement: 300.0, // 空/nil元素5分钟
        
        // 缓存雪崩防护：将TTL随机化±30秒
        ttlRandomizationRange: 30.0,     // 防止所有项目同时过期
        
        // 键验证：只接受以"img_"开头的键
        keyValidator: { key in
            return key.hasPrefix("img_")  // 自定义验证逻辑
        },
        
        // 内存成本计算：使用实际数据大小进行淘汰决策
        costProvider: { data in
            return data.count             // 返回字节大小
        }
    )
)
```

### 2. MonoTask  
**单任务执行与合并**：处理单个任务执行、请求合并和结果缓存，如模块初始化、配置文件读取、API调用整合和结果缓存（例如：用户资料、电商购物车操作）

**简单示例（默认配置）：**
```swift
import Monstra

// 使用最小配置创建基本任务
let networkTask = MonoTask<Data> { callback in
    // 你的网络请求逻辑在这里
    let url = URL(string: "https://api.example.com/data")!
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            callback(.failure(error))
        } else if let data = data {
            callback(.success(data))
        }
    }.resume()
}

// 或者，你可以使用异步块来创建MonoTask

// 多种执行模式 - 只有一个网络请求
// 注意：所有执行都受益于MonoTask的执行合并

// 使用async/await执行
let result1: Result<Data, Error> = await networkTask.asyncExecute()
switch result1 {
case .success(let data):
    print("获得数据：\(data.count) 字节")
case .failure(let error):
    print("错误：\(error)")
}

// 使用async/await和try/catch执行
do {
    let result2: Data = try await networkTask.executeThrows() // 第二次执行，返回缓存结果
    print("结果2：\(result2)")
} catch {
    print("结果2错误：\(error)")
}

// 即发即忘执行
networkTask.justExecute()

// 基于回调的执行
networkTask.execute { result in
    switch result {
    case .success(let data):
        print("结果3（回调）：\(data.count) 字节")
    case .failure(let error):
        print("结果3（回调）错误：\(error)")
    }
}
```

**详细配置示例：**
```swift
// 自定义重试和队列设置的高级配置
let fileProcessor1 = MonoTask<ProcessedData>(
    retry: 3,  // 简单重试计数配置
    
    // 结果缓存：使用默认缓存配置
    resultExpireDuration: 300.0,      // 5分钟缓存持续时间
    
    // 任务队列：用于任务执行的自定义派发队列
    taskQueue: DispatchQueue.global(qos: .utility),  // 后台优先级队列
    
    // 回调队列：用于回调的自定义派发队列
    callbackQueue: DispatchQueue.global(qos: .userInitiated)  // 高优先级队列
) { callback in
    // 你的文件处理逻辑在这里
    let filePath = "/path/to/large/file.txt"
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let processedData = ProcessedData(content: data, metadata: ["size": data.count])
        callback(.success(processedData))
    } catch {
        callback(.failure(error))
    }
}

// 自定义重试和队列设置的高级配置
let fileProcessor2 = MonoTask<ProcessedData>(
    // 重试策略：具有3次尝试的指数退避
    retry: .count(
        count: 3,    // 最大重试次数
        intervalProxy: .exponentialBackoff(
            initialTimeInterval: 1.0,  // 从1秒延迟开始
            scaleRate: 2.0             // 每次重试延迟翻倍
        )
    ),
    
    // 结果缓存：使用默认缓存配置
    resultExpireDuration: 300.0,      // 5分钟缓存持续时间
    
    // 任务队列：用于任务执行的自定义派发队列
    taskQueue: DispatchQueue.global(qos: .utility),  // 后台优先级队列
    
    // 回调队列：用于回调的自定义派发队列
    callbackQueue: DispatchQueue.global(qos: .userInitiated)  // 高优先级队列
) { callback in
    // 你的文件处理逻辑在这里
    let filePath = "/path/to/large/file.txt"
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        let processedData = ProcessedData(content: data, metadata: ["size": data.count])
        callback(.success(processedData))
    } catch {
        callback(.failure(error))
    }
}
```

**异步任务块示例：**
```swift
// 使用现代Swift并发的异步/等待初始化
let unzipTask = MonoTask<[String]>(
    // 重试策略：文件操作的固定间隔重试
    retry: .count(
        count: 2,    // 为文件系统问题重试两次
        intervalProxy: .fixed(timeInterval: 1.0)  // 重试间等待1秒
    ),
    
    // 结果缓存：缓存解压文件列表10分钟
    resultExpireDuration: 600.0,      // 10分钟缓存持续时间
    
    // 任务队列：文件操作的后台队列
    taskQueue: DispatchQueue.global(qos: .utility),
    
    // 回调队列：UI更新的主队列
    callbackQueue: DispatchQueue.main
) {
    // 直接返回Result的异步任务块
    do {
        let archivePath = "/path/to/archive.zip"
        let extractPath = "/path/to/extract/"
        
        // 模拟异步解压操作
        let extractedFiles = try await unzipArchive(at: archivePath, to: extractPath)
        return .success(extractedFiles)
    } catch {
        return .failure(error)
    }
}

// 使用async/await
let extractedFiles = try await unzipTask.executeThrows()
print("解压了 \(extractedFiles.count) 个文件")
```

### 3. KVLightTasksManager
**大容量任务执行**：处理具有峰值削平的大容量操作，如图片下载、本地数据库批量读取、地图瓦片下载和缓存预热操作

**简单示例（默认配置）：**
```swift
import Monstra

// 创建用于处理图片下载的轻量级任务管理器
let imageTaskManager = KVLightTasksManager<UIImage> { (imageURL: URL, completion: @escaping (Result<UIImage?, Error>) -> Void) in
    // 简单的图片下载任务
    URLSession.shared.dataTask(with: imageURL) { data, response, error in
        if let error = error {
            completion(.failure(error))
        } else if let data = data, let image = UIImage(data: data) {
            completion(.success(image))
        } else {
            completion(.failure(NSError(domain: "ImageError", code: -1, userInfo: nil)))
        }
    }.resume()
}

// 获取多个图片
let imageURLs = [
    "https://example.com/image1.jpg",
    "https://example.com/image2.jpg", 
    "https://example.com/image3.jpg"
].compactMap { URL(string: $0) }

// 单独获取图片
for (index, url) in imageURLs.enumerated() {
    imageTaskManager.fetch(key: url) { key, result in
        switch result {
        case .success(let image):
            if let image = image {
                print("图片 \(index + 1) 下载成功：\(image.size)")
            } else {
                print("图片 \(index + 1) 返回nil")
            }
        case .failure(let error):
            print("图片 \(index + 1) 失败：\(error)")
        }
    }
}

// 一次获取多个图片，使用批量回调
imageTaskManager.fetch(keys: imageURLs) { key, result in
    switch result {
    case .success(let image):
        if let image = image {
            print("图片已下载：\(image.size)")
        } else {
            print("图片返回nil")
        }
    case .failure(let error):
        print("图片失败：\(error)")
    }
}
```

**批处理示例：**
```swift
// 创建用于批量获取用户资料数据的管理器
let userProfileManager = KVLightTasksManager<[String: UserProfile?]> { (userIDs: [String], completion: @escaping (Result<[String: UserProfile?], Error>) -> Void) in
    // 模拟批量API调用来获取多个用户资料
    DispatchQueue.global(qos: .utility).async {
        // 模拟网络延迟
        Thread.sleep(forTimeInterval: 0.1)
        
        var profiles: [String: UserProfile?] = [:]
        
        // 模拟批量API响应
        for userID in userIDs {
            let profile = UserProfile(
                id: userID,
                name: "用户 \(userID)",
                email: "user\(userID)@example.com",
                avatar: "https://example.com/avatars/\(userID).jpg"
            )
            profiles[userID] = profile
        }
        
        completion(.success(profiles))
    }
}

// 在单个批次中获取多个用户资料
let userIDs = ["user1", "user2", "user3"]

// 使用批量回调一次获取所有结果
userProfileManager.fetch(keys: userIDs, multiCallback: { results in
    print("批量加载了 \(results.count) 个用户：")
    for (userID, result) in results {
        switch result {
        case .success(let profile):
            if let profile = profile {
                print("  ✓ \(profile.name) (\(profile.email))")
            } else {
                print("  - \(userID)：未找到资料")
            }
        case .failure(let error):
            print("  ✗ \(userID)：\(error)")
        }
    }
})

// 为每个用户使用单独的回调（仍受益于批处理）
userProfileManager.fetch(keys: userIDs) { userID, result in
    switch result {
    case .success(let profile):
        if let profile = profile {
            print("单独：\(profile.name) 已加载")
        } else {
            print("单独：\(userID) - 未找到资料")
        }
    case .failure(let error):
        print("单独：\(userID) - \(error)")
    }
}
```

**高级配置示例：**
```swift
// 为图片下载创建具有自定义配置的管理器
let imageManager = KVLightTasksManager<UIImage>(
    config: .init(
        dataProvider: .multiprovide(maximumBatchCount: 4) { (imageURLs: [String], completion: @escaping (Result<[String: UIImage?], Error>) -> Void) in
            // 并行下载多个图片
            let group = DispatchGroup()
            var results = [String: UIImage?]()
            let lock = NSLock()
            
            for urlString in imageURLs {
                group.enter()
                
                guard let url = URL(string: urlString) else {
                    lock.lock()
                    results[urlString] = nil
                    lock.unlock()
                    group.leave()
                    continue
                }
                
                URLSession.shared.dataTask(with: url) { data, response, error in
                    defer { group.leave() }
                    
                    lock.lock()
                    if let data = data, let image = UIImage(data: data) {
                        results[urlString] = image
                    } else {
                        results[urlString] = nil
                    }
                    lock.unlock()
                }.resume()
            }
            
            group.notify(queue: .main) {
                completion(.success(results))
            }
        },
        maxNumberOfQueueingTasks: 32,     // 队列最多32个图片请求
        maxNumberOfRunningTasks: 4,       // 同时下载4个图片
        retryCount: 1,                    // 失败的下载重试一次
        PriorityStrategy: .FIFO,          // 优先处理最早的请求
        cacheConfig: .init(
            capacity: 100,                // 缓存最多100个图片
            memory: 50,                   // 50MB内存限制
            defaultTTL: 3600.0,           // 1小时缓存持续时间
            enableThreadSynchronization: true
        )
    )
)

// 下载多个图片
let imageURLs = [
    "https://example.com/image1.jpg",
    "https://example.com/image2.jpg",
    "https://example.com/image3.jpg"
]

// 下载所有图片
imageManager.fetch(keys: imageURLs) { url, result in
    switch result {
    case .success(let image):
        if let image = image {
            print("✓ 已下载：\(image.size)")
        } else {
            print("- 下载失败：\(url)")
        }
    case .failure(let error):
        print("✗ 错误：\(error)")
    }
}
```

### 4. KVHeavyTasksManager

**资源密集型操作**：处理需要大量资源的任务，如大文件下载、视频处理和ML推理，具有全面的进度跟踪

#### SimpleDataProvider实现

注意：
- `SimpleDataProvider` 故意保持最小化（阻塞I/O，无进度/恢复）以便于理解。
- 对于具有进度/恢复/取消的生产下载，请查看 `Examples/KVHeavyTasksManager/LargeFileDownloadManagement` 中的高级提供者。

```swift
import Foundation
import Monstra

enum SimpleDataProviderEvent {
    case didStart
    case didFinish
}

/// 仅用于教育目的的最小同步提供者。
class SimpleDataProvider: Monstra.KVHeavyTaskBaseDataProvider<URL, Data, SimpleDataProviderEvent>, Monstra.KVHeavyTaskDataProviderInterface {
    let semaphore = DispatchSemaphore(value: 1)
    var isRunning = false {
        didSet { customEventPublisher(isRunning ? .didStart : .didFinish) }
    }

    func start() {
        semaphore.wait(); defer { semaphore.signal() }
        guard !isRunning else { return }
        isRunning = true

        DispatchQueue.global().async {
            let result: Result<Data?, Error>
            do {
                let data = try Data(contentsOf: self.key, options: .mappedIfSafe)
                result = .success(data)
            } catch {
                result = .failure(error)
            }

            self.semaphore.wait(); defer { self.semaphore.signal() }
            guard self.isRunning else { return }
            self.isRunning = false
            self.resultPublisher(result)
        }
    }

    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        semaphore.wait(); defer { semaphore.signal() }
        guard isRunning else { return .dealloc }
        isRunning = false
        return .dealloc
    }
}
```

#### 最小使用方法

```swift
import Monstra

// 在后台队列上执行阻塞读取的教育性提供者
// 参见：Examples/KVHeavyTasksManager/LargeFileDownloadManagement/Sources/.../SimpleDataProvider.swift
typealias SimpleHeavyManager = KVHeavyTasksManager<URL, Data, SimpleDataProviderEvent, SimpleDataProvider>

let manager = SimpleHeavyManager(config: .init())
let fileURL = URL(string: "https://example.com/file.bin")!

// 观察简单的开始/完成事件并获取结果
manager.fetch(
    key: fileURL,
    customEventObserver: { event in
        switch event {
        case .didStart:  print("SimpleDataProvider：已开始")
        case .didFinish: print("SimpleDataProvider：已完成")
        }
    },
    result: { result in
        switch result {
        case .success(let data):
            print("已下载：\(data.count) 字节")
        case .failure(let error):
            print("失败：\(error)")
        }
    }
)
```

## 🚀 高级示例

### **⚡ MonoTask - 任务执行场景**
<table width="100%">
  <colgroup>
    <col width="40%" />
    <col width="40%" />
    <col width="20%" />
  </colgroup>
  <thead>
    <tr>
      <th>场景</th>
      <th>最佳实践</th>
      <th>示例链接</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>模块初始化</td>
      <td>使用重试逻辑缓存应用配置</td>
      <td><a href="Examples/MonoTask/ModuleInitialization/README_CN.md">模块初始化</a></td>
    </tr>
    <tr>
      <td>用户资料管理器</td>
      <td>带缓存的单实例用户资料管理</td>
      <td><a href="Examples/MonoTask/UserProfileManager/README_CN.md">用户资料管理器</a></td>
    </tr>
  </tbody>
</table>

### **🚀 KVLightTasksManager - 轻量级任务场景**
<table width="100%">
  <colgroup>
    <col width="40%" />
    <col width="40%" />
    <col width="20%" />
  </colgroup>
  <thead>
    <tr>
      <th>场景</th>
      <th>最佳实践</th>
      <th>示例链接</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>对象获取任务</td>
      <td>按ID列表批量获取对象，提升性能</td>
      <td><a href="Examples/KVLightTasksManager/ObjectFetchTask/README_CN.md">对象获取任务</a></td>
    </tr>
  </tbody>
</table>

### **🏗️ KVHeavyTasksManager - 重型任务场景**
<table width="100%">
  <colgroup>
    <col width="40%" />
    <col width="40%" />
    <col width="20%" />
  </colgroup>
  <thead>
    <tr>
      <th>场景</th>
      <th>最佳实践</th>
      <th>示例链接</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>大文件下载管理</td>
      <td>带进度跟踪的大文件下载</td>
      <td><a href="Examples/KVHeavyTasksManager/LargeFileDownloadManagement/README_CN.md">大文件下载器</a></td>
    </tr>
    <tr>
      <td>大文件解压</td>
      <td>带进度跟踪和资源管理的大型存档文件处理</td>
      <td><a href="Examples/KVHeavyTasksManager/LargeFileUnzip/README_CN.md">大文件解压</a></td>
    </tr>
  </tbody>
</table>

## 📋 要求

### 平台支持
- **iOS**：13.0+
- **macOS**：10.15+
- **tvOS**：13.0+
- **watchOS**：6.0+

### Swift版本
- **Swift**：5.5+

### 依赖项
- **Foundation**：内置（无外部依赖）
- **Alamofire**：仅用于示例可执行文件（核心库不需要）

## 🛡️ 关键优势与保护机制

### **Monstore保护特性**

### **缓存雪崩防护**
Monstra通过TTL随机化防止缓存雪崩攻击。当多个缓存条目同时过期时，可能导致后端请求突然激增。Monstra在可配置范围内随机化过期时间以分散负载。

```swift
let cache = MemoryCache<String, Data>(
    configuration: .init(
        ttlRandomizationRange: 30.0 // ±30秒随机化
    )
)
```

### **雪崩保护**
Monstra通过实现智能淘汰策略来防止内存雪崩。当内存使用接近限制时，系统会根据优先级、最近性和过期状态自动淘汰价值最低的条目。

```swift
let cache = MemoryCache<String, UIImage>(
    configuration: .init(
        memoryUsageLimitation: .init(
            capacity: 1000,    // 最多1000个图片
            memory: 500        // 最多500MB
        )
    )
)
```

### **击穿保护**
Monstra通过基于优先级的LRU淘汰防止缓存击穿。具有更高优先级的关键数据保留时间更长，而不太重要的数据在达到容量时首先被淘汰。

```swift
// 为关键数据设置高优先级
cache.set(element: userProfile, for: "user-123", priority: 10.0)

// 为临时数据设置低优先级
cache.set(element: searchResults, for: "search-query", priority: 1.0)
```

### **空元素缓存**
Monstra支持使用单独的TTL配置缓存空/nil元素，防止对不存在数据的重复数据库查询。

```swift
let cache = MemoryCache<String, User?>(
    configuration: .init(
        defaultTTL: 3600.0,           // 常规数据：1小时
        defaultTTLForNullElement: 300.0  // 空数据：5分钟
    )
)

// 缓存存在和不存在的用户
cache.set(element: user, for: "user-123")      // 常规缓存
cache.set(element: nil, for: "user-999")      // 空缓存
```

### **Monstask保护特性**

#### **MonoTask - 执行合并与去重**
MonoTask通过智能执行合并防止重复工作。当对同一任务发出多个并发请求时，只发生一次执行，而所有回调都接收相同的结果。

```swift
let task = MonoTask<String>(resultExpireDuration: 60.0) { callback in
    // 昂贵的网络调用
    performExpensiveOperation(callback)
}

// 多个并发调用 - 只有一个网络请求
Task {
    let result1 = await task.asyncExecute() // 发生网络调用
    let result2 = await task.asyncExecute() // 返回缓存结果
    let result3 = await task.asyncExecute() // 返回缓存结果
}
```

#### **MonoTask - 高级重试策略**
MonoTask提供复杂的重试机制，具有指数退避、固定间隔和混合方法，以优雅地处理瞬时故障。

```swift
// 具有3次重试的指数退避
let retryTask = MonoTask<Data>(
    retry: .count(
        count: 3, 
        intervalProxy: .exponentialBackoff(
            initialTimeInterval: 1.0, 
            scaleRate: 2.0
        )
    ),
    resultExpireDuration: 300.0
) { callback in
    performNetworkRequest(callback)
}

// 固定间隔重试
let fixedRetryTask = MonoTask<Data>(
    retry: .count(
        count: 5, 
        intervalProxy: .fixed(timeInterval: 2.0)
    )
) { callback in
    performDatabaseQuery(callback)
}
```

#### **MonoTask - 执行状态管理**
MonoTask提供对任务执行状态的细粒度控制，具有取消、重启和完成策略。

```swift
// 立即取消正在进行的执行
task.clearResult(ongoingExecutionStrategy: .cancel)

// 让执行完成，然后重启
task.clearResult(ongoingExecutionStrategy: .restart)

// 让执行正常完成，只是清除缓存
task.clearResult(ongoingExecutionStrategy: .allowCompletion)
```

#### **MonoTask - 多种执行模式**
MonoTask支持各种执行模式以适应不同的用例和编码风格。

```swift
// Async/await（推荐用于现代Swift）
let result = await task.asyncExecute()
switch result {
case .success(let data):
    updateUI(with: data)
case .failure(let error):
    showErrorMessage(error)
}

// 基于回调（用于遗留代码集成）
task.execute { result in
    switch result {
    case .success(let data):
        updateUI(with: data)
    case .failure(let error):
        showErrorMessage(error)
    }
}

// 即发即忘（用于预热缓存）
task.justExecute()
// 稍后，这可能会返回缓存的结果
let result = await task.asyncExecute()
```

#### **任务管理器 - 基于优先级的调度**
KVLightTasksManager和KVHeavyTasksManager提供具有LIFO/FIFO策略的基于优先级的调度，以实现最佳资源利用率。

```swift
let lightManager = KVLightTasksManager<String, User>(
    config: .init(
        dataProvider: .asyncMonoprovide { key in
            try await API.fetchUser(id: key)
        },
        PriorityStrategy: .LIFO,  // 最新请求获得优先级
        maxNumberOfRunningTasks: 4,
        maxNumberOfQueueingTasks: 256
    )
)

let heavyManager = KVHeavyTasksManager<String, Video>(
    config: .init(
        dataProvider: .asyncMonoprovide { key in
            try await VideoProcessor.process(key)
        },
        PriorityStrategy: .FIFO,  // 公平处理顺序
        maxNumberOfRunningTasks: 2,  // 对重型操作的限制
        maxNumberOfQueueingTasks: 64
    )
)
```

## 🤝 贡献

我们欢迎贡献！详情请查看我们的[贡献指南](CONTRIBUTING.md)。

### 开发流程

1. Fork仓库
2. 创建功能分支（`git checkout -b feature/amazing-feature`）
3. 进行更改
4. 为新功能添加测试
5. 确保所有测试通过（`swift test`）
6. 运行代码检查（`swiftlint lint Sources/`）
7. 提交更改（`git commit -m 'Add amazing feature'`）
8. 推送到分支（`git push origin feature/amazing-feature`）
9. 提交拉取请求

### 代码风格
- 遵循Swift API设计指南
- 使用有意义的变量和函数名称
- 添加全面的文档注释
- 确保所有公共API都有单元测试
- 维护性能基准

## 📄 许可证

本项目在MIT许可证下许可 - 详情请参见[LICENSE](LICENSE)文件。

## 🙏 致谢

- 受高性能缓存实现的启发
- 使用Swift优秀的类型系统和性能特征构建
- 为生产就绪性进行了广泛测试
- 特别感谢Swift社区的反馈和贡献
- 特别感谢[Cursor](https://cursor.sh) - AI优先代码编辑器，提升开发生产力

---

**为Swift社区用❤️制作**
