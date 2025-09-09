<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

[English](README.md) | **简体中文**

# 模块初始化示例

一个演示如何使用 `MonoTask` 初始化和缓存应用配置的示例，具有执行合并、重试逻辑和TTL缓存功能。它还展示了消费者如何访问特定的配置值或组合使用字符串，而无需重新获取配置。

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
cd Monstra/Examples/MonoTask/ModuleInitialization
```

### 1.3 使用Xcode打开ModuleInitialization

```bash
# 从ModuleInitialization目录
xed Package.swift
```

或在Xcode中手动操作：
1. 打开Xcode
2. 选择 `File → Open...`
3. 导航到 `ModuleInitialization` 文件夹
4. 选择 `Package.swift`（不是根Monstra项目）
5. 点击打开

这将示例作为独立的Swift包打开。

## 2. 代码说明

### 2.1 AppConfiguration（领域模型）

最小配置模型（参见 `Sources/.../AppConfiguration.swift`）。

```swift
struct AppConfiguration: Codable, Hashable {
    let config1: String
    let config2: String
}
```

### 2.2 AppConfigurationAPI（数据源）

模拟获取配置，具有小的人工延迟和简单日志记录。

```swift
enum AppConfigurationAPI {
    static func getAppConfiguration() async throws -> AppConfiguration { /* ... */ }
}
```

### 2.3 AppConfigurationManager（初始化与访问层）

包装 `MonoTask<AppConfiguration>` 以初始化和缓存配置一次（TTL使用 `.infinity`）。包括固定间隔重试。

- **初始化**:
  - `initializeModule(completion:)` — 开始获取（forceUpdate=false）。消费者可以在应用启动时调用。
- **访问器**（都利用 `task.asyncExecute()`，因此缓存后不会重新获取）:
  - `getConfiguration()`: 返回完整配置作为 `Result<AppConfiguration, Error>`
  - `getConfig1()`: 返回 `config1` 字符串
  - `getConfig2()`: 返回 `config2` 字符串
  - `useConfig1(str:)`: 返回使用 `config1` 的组合字符串
  - `useConfig2(str:)`: 返回使用 `config2` 的组合字符串

### 2.4 使用方法（在main中）

`main.swift` 初始化模块，然后演示多个并发消费者读取/使用配置。

```swift
let manager = AppConfigurationManager()
print("[ModuleInitialization] start initializeModule()")
manager.initializeModule { result in /* 记录成功/失败 */ }

Task { print(await manager.getConfig1()) }
Task { print(await manager.getConfig2()) }
Task { print(await manager.useConfig1(str: "main.swift")) }
Task { print(await manager.useConfig2(str: "main.swift")) }
```

## 3. 关键行为与日志

### 3.1 行为

- **执行合并**：未缓存时，并发调用访问器共享一次执行
- **重试逻辑**：配置了固定间隔重试（2次尝试）
- **无限TTL**：配置缓存应用生命周期（除非您调整策略）
- **单一数据源**：访问器函数初始化后不会重复获取

### 3.2 示例日志

来自此示例的运行示例：

```
[ModuleInitialization] start initializeModule()
[Mock api] start fetch configuration
[Mock api] did fetch configuration
[ModuleInitialization] initialized: config1=value-1, config2=value-2
success("value-1")
success("main.swift is using value-1")
success("value-2")
success("main.swift is using value-2")
```

这演示了什么：
- 初始化触发单个配置获取
- 后续访问器调用使用缓存的配置
- 结果值显示原始配置访问和组合使用字符串

## 4. 清洁架构说明

- **AppConfigurationManager**：包装 `MonoTask` 和API的数据/初始化层
- **领域层**：如需要DI/测试，定义协议（例如：`AppConfigurationProvider`）
- **表示层**：在启动时调用 `initializeModule()`；在需要时使用访问器

## 5. 实现细节

### 当前代码结构
- `Package.swift` — SPM清单（Monstra依赖）
- `Sources/ModuleInitialization/AppConfiguration.swift` — 配置模型
- `Sources/ModuleInitialization/AppConfigurationAPI.swift` — 模拟数据源
- `Sources/ModuleInitialization/AppConfigurationManager.swift` — 包装 `MonoTask` 的管理器
- `Sources/ModuleInitialization/main.swift` — 初始化与访问器演示

### 关键实现要点
- `MonoTask<AppConfiguration>` 使用 `resultExpireDuration = .infinity`（应用生命周期缓存）
- 重试：`.count(count: 2, intervalProxy: .fixed(timeInterval: 0.2))`
- 访问器通过 `asyncExecute()` 共享相同的缓存结果
