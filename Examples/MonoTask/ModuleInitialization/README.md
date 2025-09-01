<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

# Module Initialization Example

An example demonstrating how to initialize and cache an application configuration using `MonoTask` with execution merging, retry logic, and TTL caching. It also shows how consumers can access specific configuration values or compose usage strings without re-fetching the configuration.

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
cd Monstra/Examples/MonoTask/ModuleInitialization
```

### 1.3 Open ModuleInitialization Using Xcode

```bash
# From the ModuleInitialization directory
xed Package.swift
```

Or manually in Xcode:
1. Open Xcode
2. Go to `File → Open...`
3. Navigate to the `ModuleInitialization` folder
4. Select `Package.swift` (not the root Monstra project)
5. Click Open

This opens the example as a standalone Swift package.

## 2. Code Explanation

### 2.1 AppConfiguration (Domain Model)

Minimal configuration model (see `Sources/.../AppConfiguration.swift`).

```swift
struct AppConfiguration: Codable, Hashable {
    let config1: String
    let config2: String
}
```

### 2.2 AppConfigurationAPI (Data Source)

Simulates fetching the configuration with small artificial latency and simple logging.

```swift
enum AppConfigurationAPI {
    static func getAppConfiguration() async throws -> AppConfiguration { /* ... */ }
}
```

### 2.3 AppConfigurationManager (Initialization & Access Layer)

Wraps `MonoTask<AppConfiguration>` to initialize and cache the configuration once (TTL uses `.infinity`). Includes retry with fixed intervals.

- **Initialization**:
  - `initializeModule(completion:)` — starts the fetch (forceUpdate=false). Consumers can call at app launch.
- **Accessors** (all leverage `task.asyncExecute()` so they do not re-fetch once cached):
  - `getConfiguration()`: returns the whole configuration as `Result<AppConfiguration, Error>`
  - `getConfig1()`: returns `config1` string
  - `getConfig2()`: returns `config2` string
  - `useConfig1(str:)`: returns a composed string using `config1`
  - `useConfig2(str:)`: returns a composed string using `config2`

### 2.4 Usage (in main)

`main.swift` initializes the module and then demonstrates multiple concurrent consumers reading/using the configuration.

```swift
let manager = AppConfigurationManager()
print("[ModuleInitialization] start initializeModule()")
manager.initializeModule { result in /* log success/failure */ }

Task { print(await manager.getConfig1()) }
Task { print(await manager.getConfig2()) }
Task { print(await manager.useConfig1(str: "main.swift")) }
Task { print(await manager.useConfig2(str: "main.swift")) }
```

## 3. Key Behavior & Logs

### 3.1 Behavior

- **Execution Merging**: concurrent calls to accessors share one execution when not cached
- **Retry Logic**: fixed-interval retry is configured (2 attempts)
- **Infinite TTL**: configuration is cached for the app lifetime (unless you adapt strategy)
- **Single Source of Truth**: accessor functions do not duplicate fetches once initialized

### 3.2 Sample Logs

From a sample run of this example:

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

What this demonstrates:
- Initialization triggers a single configuration fetch
- Subsequent accessor calls use the cached configuration
- Result values show both raw config access and composed usage strings

## 4. Clean Architecture Notes

- **AppConfigurationManager**: Data/initialization layer wrapping `MonoTask` and the API
- **Domain Layer**: Define a protocol if needed for DI/testing (e.g., `AppConfigurationProvider`)
- **Presentation Layer**: Call `initializeModule()` at startup; use accessors where needed

## 5. Implementation Details

### Current Code Structure
- `Package.swift` — SPM manifest (Monstra dependency)
- `Sources/ModuleInitialization/AppConfiguration.swift` — configuration model
- `Sources/ModuleInitialization/AppConfigurationAPI.swift` — mocked data source
- `Sources/ModuleInitialization/AppConfigurationManager.swift` — manager wrapping `MonoTask`
- `Sources/ModuleInitialization/main.swift` — initialization & accessors demo

### Key Implementation Points
- `MonoTask<AppConfiguration>` with `resultExpireDuration = .infinity` (cache for app lifetime)
- Retry: `.count(count: 2, intervalProxy: .fixed(timeInterval: 0.2))`
- Accessors share the same cached result via `asyncExecute()`
