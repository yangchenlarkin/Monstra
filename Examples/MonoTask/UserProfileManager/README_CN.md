<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

[English](README.md) | **简体中文**

# 用户资料管理器示例

一个演示如何使用 `MonoTask` 管理单个用户资料的示例—具有执行合并、TTL缓存和通过强制执行进行变更后刷新。

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
cd Monstra/Examples/MonoTask/UserProfileManager
```

### 1.3 使用Xcode打开UserProfileManager

```bash
# 从UserProfileManager目录
xed Package.swift
```

或在Xcode中手动操作：
1. 打开Xcode
2. 选择 `File → Open...`
3. 导航到 `UserProfileManager` 文件夹
4. 选择 `Package.swift`（不是根Monstra项目）
5. 点击打开

这将示例作为独立的Swift包打开。

## 2. 代码说明

### 2.1 UserProfile（领域模型）

用于演示的最小模型（参见 `Sources/.../UserProfile.swift`）。

### 2.2 UserProfileMockAPI（数据源）

模拟单个活跃用户的资料，具有小的人工延迟。设置器不返回更新的资料，因此应用必须在设置后获取。

```swift
enum UserProfileMockAPI {
    static func getUserProfileAPI() async throws -> UserProfile { /* ... */ }
    static func setUser(firstName: String) async throws { /* ... */ }
    static func setUser(age: Int) async throws { /* ... */ }
}
```

### 2.3 UserProfileManager（数据/状态层）

包装 `MonoTask<UserProfile>` 以管理具有 `resultExpireDuration = 3600` 秒的单个缓存资料。

- **公共API**:
  - `didLogin()` — 预热缓存（forceUpdate=false）
  - `setUser(firstName:)` — 设置昵称，然后 `forceUpdate=true` 刷新
  - `setUser(age:)` — 设置年龄，然后 `forceUpdate=true` 刷新
  - `didLogout()` — 取消正在进行的操作并清除缓存结果

### 2.4 使用方法（在main中）

`main.swift` 通过调用各种方法并记录结果来演示流程。

```swift
let manager = UserProfileManager()

print("触发：didLogin")
manager.didLogin()

print("触发设置firstName：Alicia")
manager.setUser(firstName: "Alicia") { result in
    switch result {
    case .success:
        print("成功设置firstName：Alicia")
    case .failure(let error):
        print("设置firstName失败：\(error)")
    }
}
```

## 3. 关键行为与日志

### 3.1 行为

- **执行合并**：多个并发读取合并为一次执行。
- **TTL缓存**：资料缓存1小时。
- **强制刷新**：由于设置器返回 `Void`，新的执行会更新缓存的资料。
- **状态管理**：直接方法调用，异步操作带完成处理程序。

### 3.2 示例日志

来自此示例的运行示例：

```
更新用户资料：nil
是否加载中：false
触发：didLogin
触发设置firstName：Alicia
是否加载中：true
更新用户资料：Optional(UserProfileManager.UserProfile(id: "1", nickName: "Alicia", age: 24))
是否加载中：false
成功设置firstName：Alicia
触发设置年龄：10
是否加载中：true
更新用户资料：Optional(UserProfileManager.UserProfile(id: "1", nickName: "Alicia", age: 10))
是否加载中：false
成功设置年龄：10
触发didLogout
更新用户资料：nil
程序结束，退出代码：0
```

## 4. 清洁架构说明

- **UserProfileManager**：包装 `MonoTask` 和模拟API的数据/状态层。
- **领域层**：如需要DI和测试，定义协议。
- **表示层**：UI/ViewModels调用管理器方法并处理完成回调。

## 5. 实现细节

### 当前代码结构
- `Package.swift` — SPM清单（Monstra依赖）
- `Sources/UserProfileManager/UserProfile.swift` — 领域模型
- `Sources/UserProfileManager/UserProfileMockAPI.swift` — 模拟数据源
- `Sources/UserProfileManager/UserProfileManager.swift` — 包装 `MonoTask` 的管理器
- `Sources/UserProfileManager/main.swift` — 方法调用演示

### 关键实现要点
- `MonoTask<UserProfile>` 使用 `resultExpireDuration = 3600`（1小时TTL）
- 通过 `asyncExecute(forceUpdate: true)` 进行变更后刷新，保持一次调用一次回调
- 异步操作的直接方法调用与完成处理程序
- 可重复运行的确定性模拟数据
