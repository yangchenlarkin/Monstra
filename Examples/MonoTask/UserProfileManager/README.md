<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

**English** | [简体中文](README_CN.md)

# UserProfile Manager Example

An example demonstrating how to manage a single user's profile using `MonoTask`—with execution merging, TTL caching, and post-mutation refresh via forced execution.

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
cd Monstra/Examples/MonoTask/UserProfileManager
```

### 1.3 Open UserProfileManager Using Xcode

```bash
# From the UserProfileManager directory
xed Package.swift
```

Or manually in Xcode:
1. Open Xcode
2. Go to `File → Open...`
3. Navigate to the `UserProfileManager` folder
4. Select `Package.swift` (not the root Monstra project)
5. Click Open

This opens the example as a standalone Swift package.

## 2. Code Explanation

### 2.1 UserProfile (Domain Model)

Minimal model used for demonstration (see `Sources/.../UserProfile.swift`).

### 2.2 UserProfileMockAPI (Data Source)

Simulates a single active user's profile with small artificial latency. Setters do not return the updated profile, so the app must fetch after setting.

```swift
enum UserProfileMockAPI {
    static func getUserProfileAPI() async throws -> UserProfile { /* ... */ }
    static func setUser(firstName: String) async throws { /* ... */ }
    static func setUser(age: Int) async throws { /* ... */ }
}
```

### 2.3 UserProfileManager (Data/State Layer)

Wraps `MonoTask<UserProfile>` to manage a single cached profile with `resultExpireDuration = 3600` seconds.

- **Public API**:
  - `didLogin()` — pre-warm cache (forceUpdate=false)
  - `setUser(firstName:)` — set nickname, then `forceUpdate=true` to refresh
  - `setUser(age:)` — set age, then `forceUpdate=true` to refresh
  - `didLogout()` — cancel in-flight and clear cached result

### 2.4 Usage (in main)

`main.swift` demonstrates the flow by calling various methods and logging the results.

```swift
let manager = UserProfileManager()

print("trigger: didLogin")
manager.didLogin()

print("trigger set firstName: Alicia")
manager.setUser(firstName: "Alicia") { result in
    switch result {
    case .success:
        print("Did set firstName: Alicia")
    case .failure(let error):
        print("Failed to set firstName: \(error)")
    }
}
```

## 3. Key Behavior & Logs

### 3.1 Behavior

- **Execution Merging**: multiple concurrent reads merge into one execution.
- **TTL Caching**: profile is cached for 1 hour.
- **Forced Refresh**: since setters return `Void`, a fresh execution updates the cached profile.
- **State Management**: Direct method calls with completion handlers for async operations.

### 3.2 Sample Logs

From a sample run of this example:

```
update userProfile: nil
isLoading: false
trigger: didLogin
trigger set fistName: Alicia
isLoading: true
update userProfile: Optional(UserProfileManager.UserProfile(id: "1", nickName: "Alicia", age: 24))
isLoading: false
Did set firstName: Alicia
trigger set age: 10
isLoading: true
update userProfile: Optional(UserProfileManager.UserProfile(id: "1", nickName: "Alicia", age: 10))
isLoading: false
Did set age: 10
trigger didLogout
update userProfile: nil
Program ended with exit code: 0
```

## 4. Clean Architecture Notes

- **UserProfileManager**: Data/state layer that wraps `MonoTask` and the mock API.
- **Domain Layer**: Define a protocol if needed for DI and testing.
- **Presentation Layer**: UI/ViewModels call manager methods and handle completion callbacks.

## 5. Implementation Details

### Current Code Structure
- `Package.swift` — SPM manifest (Monstra dependency)
- `Sources/UserProfileManager/UserProfile.swift` — domain model
- `Sources/UserProfileManager/UserProfileMockAPI.swift` — mocked data source
- `Sources/UserProfileManager/UserProfileManager.swift` — manager wrapping `MonoTask`
- `Sources/UserProfileManager/main.swift` — method calls demo

### Key Implementation Points
- `MonoTask<UserProfile>` with `resultExpireDuration = 3600` (1h TTL)
- Post-mutation refresh via `asyncExecute(forceUpdate: true)` keeping one-call-one-callback
- Direct method calls with completion handlers for async operations
- Deterministic mock data for repeatable runs
