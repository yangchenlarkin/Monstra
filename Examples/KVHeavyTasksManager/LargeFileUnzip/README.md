<div align="center">
  <img src="../../../Logo.png" alt="Monstra Logo" width="200"/>
</div>

# Large File Unzip Example

A comprehensive example demonstrating how to unzip large archive files with progress tracking using the Monstra framework's `KVHeavyTasksManager` and `ZIPFoundation`.

## 1. How to Run This Example

### 1.1 Requirements

- **Platforms**:
  - macOS 13.0+
  - iOS 16.0+
- **Swift**: 5.9+
- **Dependencies**:
  - Monstra framework (local development version)
  - ZIPFoundation 0.9.16+

### 1.2 Download the Repo

```bash
git clone https://github.com/yangchenlarkin/Monstra.git
cd Monstra/Examples/KVHeavyTasksManager/LargeFileUnzip
```

### 1.3 Open LargeFileUnzip Using Xcode

```bash
# From the LargeFileUnzip directory
xed Package.swift
```

Or manually in Xcode:
1. Open Xcode
2. Go to `File → Open...`
3. Navigate to the `LargeFileUnzip` folder
4. Select `Package.swift` (not the root Monstra project)
5. Click Open

This avoids conflicts with the main project and opens the example as a standalone Swift package.

## 2. Code Explanation

### 2.1 UnzipDataProvider

The `UnzipDataProvider` is a custom implementation of the `KVHeavyTaskDataProviderInterface` that unzips a local `.zip` file to a destination directory and reports progress.

**Key aspects:**
- **Key**: `URL` to the local `.zip` file
- **Result**: `[URL]?` — extracted file URLs (or `nil` on failure)
- **Events**: `UnzipEvent.didStart`, `UnzipEvent.progress(Double)`, `UnzipEvent.didFinish`

**Notes:**
- Progress is computed by iterating archive entries and emitting a normalized fraction.
- Cancellation marks the provider as stopped; entry extraction loop will throw and terminate gracefully.

#### Event Type
```swift
enum UnzipEvent {
    case didStart
    case progress(Double) // 0.0 ... 1.0
    case didFinish
}
```

### 2.2 Usage (in main)

The `main.swift` demonstrates downloading a remote `.zip` (Battle.net installer) to a local path and then unzipping it using `KVHeavyTasksManager`.

```swift
import Foundation
import Monstra
import ZIPFoundation

// Download a remote zip to a local path and then unzip
let zipFilePath = URL(filePath: "demo.zip")
guard let battleNetRemoteURL = URL(string: "https://downloader.battle.net/download/installer/mac/1.0.61/Battle.net-Setup.zip") else {
    fatalError("Invalid Battle.net remote URL")
}

// Naive synchronous download (for demo only)
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
    guard let tmp = tempURL else { throw NSError(domain: "UnzipDemo", code: -1, userInfo: [NSLocalizedDescriptionKey: "No temp file"]) }

    let fm = FileManager.default
    if fm.fileExists(atPath: zipFilePath.path) { try fm.removeItem(at: zipFilePath) }
    try fm.moveItem(at: tmp, to: zipFilePath)
    print("✅ Downloaded to: \(zipFilePath.path)")
} catch {
    print("❌ Download failed: \(error)")
}

typealias UnzipManager = KVHeavyTasksManager<URL, [URL], UnzipEvent, UnzipDataProvider>
let manager = UnzipManager(config: .init())

manager.fetch(key: zipFilePath, customEventObserver: { event in
    switch event {
    case .didStart:
        print("Unzip started")
    case let .progress(p):
        print(String(format: "Progress: %.2f%%", p * 100))
    case .didFinish:
        print("Unzip finished")
    }
}, result: { result in
    print("Result: \(result)")
})

RunLoop.main.run()
```

## 🏗️ Implementation Details

### Current Code Structure
- `Package.swift` — SPM manifest (Monstra + ZIPFoundation dependencies)
- `Sources/LargeFileUnzip/UnzipDataProvider.swift` — provider implementation
- `Sources/LargeFileUnzip/main.swift` — example entry point (download + unzip)

### Key Implementation Features
- **Entry-wise Progress**: Emits progress for each extracted archive entry.
- **Safe Destination Handling**: Creates necessary subdirectories before writing files.
- **Graceful Stop**: Marks running state and exits cleanly on cancellation.

## 🌐 Demo Archive

This example downloads Battle.net installer archive to demonstrate unzip of a real-world file:

- URL: `https://downloader.battle.net/download/installer/mac/1.0.61/Battle.net-Setup.zip`

You can replace the URL or point to your own `.zip` file for testing.

---

## 📚 Enhanced Framework Documentation

For details about memory cost units and cache configuration, see the documentation in the root project README and `Sources/Monstore/MemoryCache/README.md`.
