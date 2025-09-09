<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

[English](README.md) | **简体中文**

# 大文件解压示例

一个全面的示例，演示如何使用Monstra框架的`KVHeavyTasksManager`和`ZIPFoundation`进行带有进度跟踪的大型档案文件解压。

## 1. 如何运行此示例

### 1.1 要求

- **支持平台**:
  - macOS 13.0+
  - iOS 16.0+
- **Swift**: 5.9+
- **依赖项**:
  - Monstra框架（本地开发版本）
  - ZIPFoundation 0.9.16+

### 1.2 下载仓库

```bash
git clone https://github.com/yangchenlarkin/Monstra.git
cd Monstra/Examples/KVHeavyTasksManager/LargeFileUnzip
```

### 1.3 使用Xcode打开LargeFileUnzip

```bash
# 从LargeFileUnzip目录
xed Package.swift
```

或在Xcode中手动操作：
1. 打开Xcode
2. 选择 `File → Open...`
3. 导航到 `LargeFileUnzip` 文件夹
4. 选择 `Package.swift`（不是根Monstra项目）
5. 点击打开

这避免了与主项目的冲突，并将示例作为独立的Swift包打开。

## 2. 代码说明

### 2.1 UnzipDataProvider

`UnzipDataProvider`是`KVHeavyTaskDataProviderInterface`的自定义实现，将本地`.zip`文件解压到目标目录并报告进度。

**关键方面：**
- **键**：本地`.zip`文件的`URL`
- **结果**：`[URL]?` — 提取的文件URL（失败时为`nil`）
- **事件**：`UnzipEvent.didStart`、`UnzipEvent.progress(Double)`、`UnzipEvent.didFinish`

**注意：**
- 通过迭代档案条目并发出标准化分数来计算进度。
- 取消将提供程序标记为已停止；条目提取循环将抛出并优雅地终止。

#### 事件类型
```swift
enum UnzipEvent {
    case didStart
    case progress(Double) // 0.0 ... 1.0
    case didFinish
}
```

### 2.2 使用方法（在main中）

`main.swift`演示下载远程`.zip`文件（Battle.net安装程序）到本地路径，然后使用`KVHeavyTasksManager`解压它。

```swift
import Foundation
import Monstra
import ZIPFoundation

// 下载远程zip到本地路径然后解压
let zipFilePath = URL(filePath: "demo.zip")
guard let battleNetRemoteURL = URL(string: "https://downloader.battle.net/download/installer/mac/1.0.61/Battle.net-Setup.zip") else {
    fatalError("无效的Battle.net远程URL")
}

// 简单同步下载（仅用于演示）
do {
    let semaphore = DispatchSemaphore(value: 0)
    var downloadError: Error?
    var tempURL: URL?

    let task = URLSession.shared.downloadTask(with: battleNetRemoteURL) { location, _, error in
        defer { semaphore.signal() }
        if let error { downloadError = error; return }
        tempURL = location
    }
    task.resume()
    semaphore.wait()

    if let error = downloadError { throw error }
    guard let tmp = tempURL else { throw NSError(domain: "UnzipDemo", code: -1, userInfo: [NSLocalizedDescriptionKey: "没有临时文件"]) }

    let fm = FileManager.default
    if fm.fileExists(atPath: zipFilePath.path) { try fm.removeItem(at: zipFilePath) }
    try fm.moveItem(at: tmp, to: zipFilePath)
    print("✅ 已下载到：\(zipFilePath.path)")
} catch {
    print("❌ 下载失败：\(error)")
}

typealias UnzipManager = KVHeavyTasksManager<URL, [URL], UnzipEvent, UnzipDataProvider>
let manager = UnzipManager(config: .init())

manager.fetch(key: zipFilePath, customEventObserver: { event in
    switch event {
    case .didStart:
        print("解压开始")
    case let .progress(p):
        print(String(format: "进度：%.2f%%", p * 100))
    case .didFinish:
        print("解压完成")
    }
}, result: { result in
    print("结果：\(result)")
})

RunLoop.main.run()
```

## 🏗️ 实现细节

### 当前代码结构
- `Package.swift` — SPM清单（Monstra + ZIPFoundation依赖）
- `Sources/LargeFileUnzip/UnzipDataProvider.swift` — 提供程序实现
- `Sources/LargeFileUnzip/main.swift` — 示例入口点（下载 + 解压）

### 关键实现特性
- **逐条目进度**：为每个提取的档案条目发出进度。
- **安全目标处理**：在写入文件之前创建必要的子目录。
- **优雅停止**：标记运行状态并在取消时干净退出。

## 🌐 演示档案

此示例下载Battle.net安装程序档案以演示现实世界文件的解压：

- URL：`https://downloader.battle.net/download/installer/mac/1.0.61/Battle.net-Setup.zip`

您可以替换URL或指向您自己的`.zip`文件进行测试。

---

## 📚 增强的框架文档

有关内存成本单位和缓存配置的详细信息，请参见根项目README和`Sources/Monstore/MemoryCache/README.md`中的文档。
