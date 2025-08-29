# Large File Unzip Example

Demonstrates unzipping large archives with progress tracking using `KVHeavyTasksManager` and `ZIPFoundation`.

## How to Run

```bash
cd Examples/KVHeavyTasksManager/LargeFileUnzip
xed Package.swift
```

In `main.swift`, ensure a valid `.zip` file exists at the configured path, then run.

## Provider

`UnzipDataProvider` emits simple events (`didStart`, `progress(Double)`, `didFinish`) and returns extracted file URLs.

```swift
enum UnzipEvent {
    case didStart
    case progress(Double)
    case didFinish
}
```

See `Sources/LargeFileUnzip/UnzipDataProvider.swift` for details.
