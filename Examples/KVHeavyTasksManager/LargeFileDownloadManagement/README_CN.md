<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

[English](README.md) | **简体中文**

# 大文件下载管理示例

一个全面的示例，演示如何使用Monstra框架的`KVHeavyTasksManager`结合Alamofire和AFNetworking提供程序实现带有进度跟踪、恢复功能和智能缓存的大文件下载。

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
  - Alamofire 5.8.0+
  - AFNetworking 4.0.0+

### 1.2 下载仓库

```bash
git clone https://github.com/yangchenlarkin/Monstra.git
cd Monstra/Examples/KVHeavyTasksManager/LargeFileDownloadManagement
```

### 1.3 使用Xcode打开LargeFileDownloadManagement

**重要：不要打开根项目！**

相反，只打开示例包：

```bash
# 从LargeFileDownloadManagement目录
xed Package.swift
```

或在Xcode中手动操作：
1. 打开Xcode
2. 选择 `File → Open...`
3. 导航到 `LargeFileDownloadManagement` 文件夹
4. 选择 `Package.swift`（不是根Monstra项目）
5. 点击打开

这避免了与主项目的冲突，并将示例作为独立的Swift包打开。

## 2. 代码说明

### 2.1 SimpleDataProvider（教学用，同步）

为了学习目的，此示例还包含一个非常小的提供程序：`SimpleDataProvider`。

特点：
- 发出简单的生命周期事件：`didStart`和`didFinish`
- 在后台队列上使用`Data(contentsOf:)`执行阻塞读取
- 无进度或恢复支持（保留用于教学用途；生产中使用流式传输）

注意：
- `Data(contentsOf:)`是同步的，将整个负载加载到内存中；这个提供程序故意简单。
- 对于生产，使用`AlamofireDataProvider`或`AFNetworkingDataProvider`来获得进度、取消和恢复功能。

#### 实现

```swift
import Foundation
import Monstra

enum SimpleDataProviderEvent {
    case didStart
    case didFinish
}

/// 仅用于教学目的的最小同步提供程序。
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

最小使用：

```swift
// 使用带有自定义事件类型的SimpleDataProvider
typealias SimpleManager = KVHeavyTasksManager<URL, Data, SimpleDataProviderEvent, SimpleDataProvider>

let simpleManager = SimpleManager(config: .init())
let fileURL = URL(string: "https://example.com/file.bin")!

simpleManager.fetch(
    key: fileURL,
    customEventObserver: { event in
        switch event {
        case .didStart:  print("简单提供程序：didStart")
        case .didFinish: print("简单提供程序：didFinish")
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

### 2.2 AlamofireDataProvider

`AlamofireDataProvider`是`KVHeavyTaskDataProvider`协议的自定义实现，使用Alamofire处理文件下载。

#### 关键特性：
- **恢复功能**：使用恢复数据缓存自动恢复中断的下载
- **进度跟踪**：具有详细指标的实时进度更新
- **内存缓存集成**：使用Monstra的MemoryCache进行恢复数据存储
- **错误处理**：全面的错误管理和报告
- **智能缓存**：具有1GB内存限制的智能缓存管理，用于恢复数据

#### 下载策略：
1. **恢复数据缓存**：在MemoryCache中存储恢复数据，限制1GB
2. **恢复逻辑**：使用缓存的恢复数据自动从部分下载恢复
3. **进度跟踪**：通过自定义事件进行实时进度更新
4. **错误处理**：全面的错误管理和报告
5. **文件管理**：自动目录创建和文件路径管理

### 2.3 AFNetworkingDataProvider

`AFNetworkingDataProvider`是`KVHeavyTaskDataProvider`协议的自定义实现，使用AFNetworking 4.x处理文件下载。

#### 关键特性：
- **现代AFNetworking**：使用基于URLSession架构的AFNetworking 4.x
- **进度跟踪**：使用AFNetworking的进度系统进行实时进度更新
- **文件管理**：自动目录创建和文件路径管理
- **错误处理**：具有适当清理的全面错误处理
- **文件扩展名保留**：为下载的文件维护原始文件扩展名

#### 下载策略：
1. **目录创建**：自动创建具有适当权限的下载目录
2. **文件命名**：使用MD5哈希生成具有保留扩展名的唯一文件名
3. **进度跟踪**：通过AFNetworking的进度系统进行实时进度更新
4. **文件读取**：读取完成的下载并返回Data对象
5. **会话管理**：适当的URLSession生命周期管理

### 2.4 使用方法（在main中）

main.swift文件演示了两个提供程序与`KVHeavyTasksManager`的高级使用，包括现代async/await和传统回调模式。它展示了如何使用类型别名轻松在提供程序之间切换。

#### 演示的关键特性：

**0. 使用类型别名的提供程序切换：**
```swift
typealias AFNetworkingManager = KVHeavyTasksManager<URL, Data, Progress, AFNetworkingDataProvider>
typealias AlamofireManager = KVHeavyTasksManager<URL, Data, Progress, AlamofireDataProvider>
```
这允许通过更改类型别名使用轻松在提供程序之间切换。

**1. 执行合并（多个回调，单次下载）：**
```swift
// 多个异步任务共享相同的下载
await withTaskGroup(of: Void.self) { group in
    for i in 0..<10 {
        group.addTask {
            let result = await manager1.asyncFetch(key: chrome, customEventObserver: { progress in
                print("获取任务 \(i). 进度: \(progress.completedUnitCount) / \(progress.totalUnitCount)")
            })
            print("获取任务 \(i). 结果: \(result)")
        }
    }
}
```

#### 关键框架行为：

**多个回调，单次执行**：Monstra框架允许为同一下载任务注册多个回调，但实际下载只发生一次。这在日志中得到了证明：

**文件系统和缓存行为：**
```
📁 使用系统缓存目录：/Users/zennish/Library/Caches
📁 生成的目标URL：/Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18
🚀 开始下载键：https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg
获取任务 0. 进度: 10943 / 229019705
获取任务 1. 进度: 10943 / 229019705
获取任务 2. 进度: 10943 / 229019705
...
获取任务 9. 进度: 229019705 / 229019705
📁 AFNetworking目标回调被调用，返回：/Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18.dmg
📁 下载完成，文件URL：/Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18.dmg
📁 预期目标：/Users/zennish/Library/Caches/AFNetworkingDataProvider/b339168e62d77e242b7e9e454d82fb18.dmg
✅ 下载成功完成：229019705 字节
获取任务 0. 结果: success(Optional(229019705 字节))
获取任务 1. 结果: success(Optional(229019705 字节))
...
获取任务 9. 结果: success(Optional(229019705 字节))
```

**这意味着什么：**
- **10个不同的回调**为同一下载注册
- **只执行了1个实际下载**（如单个"从头开始新下载"消息所示）
- **所有10个回调**都收到进度更新和完成结果
- **高效的资源使用** - 同一URL没有重复下载

这种模式对于应用的多个部分需要相同文件的场景很有用，确保高效下载和所有消费者间的一致状态。

**2. 任务队列（顺序下载）：**
```swift
// 有限并发的自定义配置
let config = Manager.Config(maxNumberOfQueueingTasks: 1, maxNumberOfRunningTasks: 1, priorityStrategy: .FIFO)
let manager = Manager(config: config)

// 下载将顺序执行
manager.fetch(key: chrome) { result in
    print("Chrome下载完成")
}
manager.fetch(key: slack) { result in
    print("Slack下载完成")
}
manager.fetch(key: evernote) { result in
    print("Evernote下载完成")
}
```

**任务队列行为：**
此配置确保下载按有限并发顺序执行。日志显示顺序执行：

```
📁 使用系统缓存目录：/Users/zennish/Library/Caches
📁 生成的目标URL：/Users/zennish/Library/Caches/AlamofireDataProvider/b339168e62d77e242b7e9e454d82fb18
🚀 为键开始新下载：https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg
获取evernote结果：failure(Monstra.KVHeavyTasksManager<Foundation.URL, Foundation.Data, __C.NSProgress, LargeFileDownloadManagement.AlamofireDataProvider>.Errors.taskEvictedDueToPriorityConstraints(https://mac.desktop.evernote.com/builds/Evernote-latest.dmg))
下载chrome：0.0017893656792545428%
下载chrome：0.004180426308731819%
下载chrome：0.006571486938209094%
下载chrome：0.008958617774832957%
下载chrome：0.011349678404310231%
......
下载chrome：99.57528894729822%
下载chrome：99.69696537684388%
下载chrome：99.81857194340549%
下载chrome：99.94018549626549%
下载chrome：100.0%
✅ 下载成功完成：229019705 字节
📁 使用系统缓存目录：/Users/zennish/Library/Caches
📁 生成的目标URL：/Users/zennish/Library/Caches/AlamofireDataProvider/5825d1009072c995406c037b2fdc7507
🚀 为键开始新下载：https://downloads.slack-edge.com/desktop-releases/mac/universal/4.45.69/Slack-4.45.69-macOS.dmg
获取chrome结果：success(Optional(229019705 字节))
下载slack：0.008185515174136616%
下载slack：0.016579784322574478%
下载slack：0.02497405347101234%
下载slack：0.033368322619450205%
下载slack：0.1747368217616714%
......
下载slack：99.78830551824257%
下载slack：99.92599594674667%
下载slack：100.0%
✅ 下载成功完成：194966348 字节
获取slack结果：success(Optional(229019705 字节))
```

**这显示了什么：**
- **顺序执行**：首先下载Chrome，然后Slack
- **任务驱逐**：由于优先级约束，Evernote任务被驱逐
- **进度跟踪**：每个下载的实时进度更新
- **缓存管理**：每个下载获得唯一的缓存文件
- **完成处理**：每个下载完成后交付结果

---

**💡 专业提示**：尝试不同的优先级策略以查看它们如何影响任务执行！如代码中所述：

```swift
let config2 = Manager.Config(maxNumberOfQueueingTasks: 1, maxNumberOfRunningTasks: 1, priorityStrategy: .FIFO) // 尝试其他策略以查看差异
```

尝试不同的`priorityStrategy`值以观察它们如何改变下载顺序和任务处理行为。

---

## 🔄 **提供程序比较**

此示例包含两个不同的网络数据提供程序以演示Monstra框架的灵活性：

### **AlamofireDataProvider**
- 使用**Alamofire**网络库
- 内置恢复功能，带有`resumeData`和MemoryCache集成
- 使用MD5哈希的自动文件路径管理
- 使用Alamofire的进度系统进行进度跟踪
- 带有1GB内存限制的恢复数据缓存

### **AFNetworkingDataProvider**  
- 使用**AFNetworking 4.x**网络库
- 现代基于URLSession的架构
- 自动目录创建和文件管理
- 使用AFNetworking的进度系统进行进度跟踪
- 使用基于MD5的命名进行文件扩展名保留

**💡 尝试在提供程序之间切换以查看差异：**

```swift
// 尝试AlamofireDataProvider以查看差异
let manager = Manager<URL, Data, Progress, AlamofireDataProvider>()

// 尝试AFNetworkingDataProvider以查看差异  
let manager = Manager<URL, Data, Progress, AFNetworkingDataProvider>()
```

两个提供程序都实现了相同的`KVHeavyTaskDataProviderInterface`，因此您可以轻松在它们之间交换而不更改业务逻辑！

### 2.4 SimpleDataProvider（教学用，同步）

为了学习目的，此示例还包含一个非常小的提供程序：`SimpleDataProvider`。

特点：
- 发出简单的生命周期事件：`didStart`和`didFinish`
- 在后台队列上使用`Data(contentsOf:)`执行阻塞读取
- 无进度或恢复支持（保留用于教学用途；生产中使用流式传输）

最小使用：

```swift
// 使用带有自定义事件类型的SimpleDataProvider
typealias SimpleManager = KVHeavyTasksManager<URL, Data, SimpleDataProviderEvent, SimpleDataProvider>

let simpleManager = SimpleManager(config: .init())
let fileURL = URL(string: "https://example.com/file.bin")!

simpleManager.fetch(
    key: fileURL,
    customEventObserver: { event in
        switch event {
        case .didStart:  print("简单提供程序：didStart")
        case .didFinish: print("简单提供程序：didFinish")
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

注意：
- `Data(contentsOf:)`是同步的，将整个负载加载到内存中；这个提供程序故意简单。
- 对于生产，使用`AlamofireDataProvider`或`AFNetworkingDataProvider`来获得进度、取消和恢复功能。

## 🏗️ **实现细节**

### **当前代码结构**
示例包含三个主要Swift文件：

1. **`main.swift`** - 演示两个提供程序的主执行文件
2. **`AlamofireDataProvider.swift`** - 基于Alamofire的下载提供程序，带有恢复缓存
3. **`AFNetworkingDataProvider.swift`** - 基于AFNetworking 4.x的下载提供程序

### **关键实现特性**

#### **恢复数据缓存（AlamofireDataProvider）**
```swift
static let resumeDataCache: MemoryCache<URL, Data> = .init(
    configuration: .init(
        memoryUsageLimitation: .init(memory: 1024), 
        costProvider: { $0.count }
    )
) // 恢复数据1GB限制
```

#### **文件扩展名保留（AFNetworkingDataProvider）**
```swift
let fileName = key.absoluteString.md5()
let fileExtension = key.pathExtension.isEmpty ? "download" : key.pathExtension
let destinationURL = downloadFolder.appendingPathComponent("\(fileName).\(fileExtension)")
```

#### **简易提供程序切换**
```swift
// 通过更改类型别名在提供程序之间切换
let manager1 = AFNetworkingManager(config: .init())
let manager2 = AlamofireManager(config: config2)
```

---

## 🌐 **演示URL和文件类型**

示例下载三种不同类型的文件以演示各种场景：

- **Chrome DMG** (`googlechrome.dmg`) - 大型macOS应用程序安装程序（~229MB）
- **Slack DMG** (`Slack-4.45.69-macOS.dmg`) - 中等大小的应用程序安装程序（~195MB）  
- **Evernote DMG** (`Evernote-latest.dmg`) - 用于优先级约束测试的应用程序安装程序

选择这些文件是因为它们：
- 代表现实世界的下载场景
- 具有不同的大小以测试内存管理
- 可公开访问用于演示目的
- 显示框架如何处理各种文件类型和大小

---

## 📚 **增强的框架文档**

Monstra框架已通过更清晰的文档进行了增强，以获得更好的开发者体验：

### **MemoryCache成本提供程序澄清**
`MemoryCache.Configuration.costProvider`现在包含关于成本单位的清晰文档：

```swift
/// ## 重要说明：
/// - **成本单位**：返回值表示**字节**中的内存成本
/// - 返回的元素应该是**正数**和**合理的**（避免极大的元素）
/// - 应该对相同输入保持**一致**（确定性的）
/// - **性能**：此闭包在驱逐期间频繁调用，因此保持快速
/// - **内存限制**：所有元素的总成本不应超过`MemoryUsageLimitation.memory`
/// - **默认行为**：如果未指定，返回0，依赖自动内存布局计算
public let costProvider: (Element) -> Int
```

**关键好处：**
- **清晰的单位规格**：开发者知道以字节返回值
- **准确的内存管理**：驱逐决策的适当字节级精度
- **更好的性能**：理解costProvider在驱逐期间频繁调用
- **一致的行为**：确定性和合理成本计算的指南

**使用示例：**
```swift
let cache = MemoryCache<String, Data>(configuration: .init(
    costProvider: { data in data.count }  // 为Data对象返回字节数
))

let stringCache = MemoryCache<String, String>(configuration: .init(
    costProvider: { string in string.utf8.count }  // 为String对象返回字节数
))
```

这种增强确保开发者可以做出关于内存成本计算和缓存管理策略的明智决策。
