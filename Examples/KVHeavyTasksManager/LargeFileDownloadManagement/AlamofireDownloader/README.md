# Alamofire Downloader with Monstra

A complete example project demonstrating how to use Monstra's `KVHeavyTasksManager` for efficient large file downloads with Alamofire.

## 🚀 Features

- **Large File Downloads**: Handle downloads of any size with progress tracking
- **Concurrent Downloads**: Download multiple files simultaneously with controlled concurrency
- **Progress Monitoring**: Real-time download progress with percentage and speed calculations
- **Error Handling**: Comprehensive error handling for network and file system issues
- **Monstra Integration**: Uses `KVHeavyTasksManager` for task coordination and resource management
- **Alamofire**: Leverages Alamofire's robust download capabilities

## 📋 Requirements

- **Platforms**: macOS 13.0+, iOS 16.0+
- **Swift**: 5.9+
- **Dependencies**: 
  - Monstra (0.0.5+)
  - Alamofire (5.8.0+)

## 🏗️ Project Structure

```
AlamofireDownloader/
├── Package.swift              # Swift Package Manager configuration
├── Sources/
│   └── main.swift            # Main application with download logic
├── Tests/
│   └── AlamofireDownloaderTests.swift  # Unit tests
└── README.md                  # This file
```

## 🔧 Installation & Setup

### 1. Clone or Download
```bash
# Navigate to the project directory
cd Examples/KVHeavyTasksManager/LargeFileDownloadManagement/AlamofireDownloader
```

### 2. Build the Project
```bash
# Build the project
swift build

# Run the application
swift run
```

### 3. Run Tests
```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose
```

## 💡 Usage Examples

### Basic Download
```swift
let downloadManager = try AlamofireDownloadManager()
let result = try await downloadManager.downloadFile(from: "https://example.com/file.zip")
```

### Using HeavyTasksManager
```swift
// Download with Monstra's task management
let result = try await downloadManager.downloadWithHeavyTasksManager(from: "https://example.com/file.zip")
```

### Multiple Concurrent Downloads
```swift
let urls = [
    "https://example.com/file1.zip",
    "https://example.com/file2.zip",
    "https://example.com/file3.zip"
]

let results = try await downloadManager.downloadMultipleFiles(from: urls)
```

## 🎯 Key Components

### DownloadProgress
Tracks download progress with:
- Bytes downloaded
- Total bytes
- Percentage completion

### DownloadResult
Contains download results:
- File location
- File size
- Download time
- Success status
- Error information

### AlamofireDownloadManager
Main download manager that:
- Integrates with `KVHeavyTasksManager`
- Handles file system operations
- Manages download destinations
- Provides progress callbacks

## 🔄 How It Works

1. **Initialization**: Creates a download directory and initializes `KVHeavyTasksManager`
2. **Task Submission**: Downloads are submitted to the heavy tasks manager
3. **Concurrency Control**: Maximum of 2 concurrent downloads, 10 queued
4. **Progress Tracking**: Real-time progress updates during download
5. **File Management**: Automatic file cleanup and destination management
6. **Result Handling**: Comprehensive result reporting with timing and size information

## 📊 Example Output

```
🚀 Alamofire Downloader with Monstra
=====================================

📋 Starting downloads...
URLs to download:
  1. https://speed.hetzner.de/100MB.bin
  2. https://speed.hetzner.de/1GB.bin
  3. https://httpbin.org/bytes/1048576

📥 Download Progress: 25.0% (26214400 / 104857600 bytes)
📥 Download Progress: 50.0% (52428800 / 104857600 bytes)
📥 Download Progress: 75.0% (78643200 / 104857600 bytes)
📥 Download Progress: 100.0% (104857600 / 104857600 bytes)

✅ Downloads completed successfully!

📊 Download Summary:
  File 1:
    📁 Location: 100MB.bin
    📏 Size: 100.0 MB
    ⏱️  Time: 12.34s
    🚀 Speed: 8.1 MB/s
```

## 🧪 Testing

The project includes comprehensive unit tests covering:
- Progress calculation accuracy
- Download result creation
- Error handling
- Edge cases

Run tests with:
```bash
swift test
```

## 🔍 Customization

### Modify Concurrency Limits
```swift
heavyTasksManager = KVHeavyTasksManager<String, DownloadResult>(
    config: .init(
        dataProvider: .asyncMonoprovide { ... },
        priorityStrategy: .FIFO,
        maxNumberOfRunningTasks: 5,    // Increase concurrent downloads
        maxNumberOfQueueingTasks: 20   // Increase queue size
    )
)
```

### Change Download Directory
```swift
// Custom download directory
downloadDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
```

### Add Custom Progress Handling
```swift
.downloadProgress { progress in
    // Custom progress handling
    let customProgress = DownloadProgress(
        bytesDownloaded: progress.completedUnitCount,
        totalBytes: progress.totalUnitCount
    )
    // Your custom logic here
}
```

## 🚨 Error Handling

The project handles various error scenarios:
- **Invalid URLs**: Malformed or empty URLs
- **Network Failures**: Download timeouts and connection issues
- **File System Errors**: Permission and disk space issues
- **Manager Deallocation**: Memory management issues

## 📚 Dependencies

### Monstra
- **KVHeavyTasksManager**: For task coordination and resource management
- **Concurrency Control**: Limits concurrent downloads to prevent resource exhaustion
- **Task Queuing**: Manages download queue with FIFO strategy

### Alamofire
- **Download Requests**: Robust download capabilities with resume support
- **Progress Tracking**: Real-time progress monitoring
- **Destination Management**: Flexible file destination handling
- **Error Handling**: Comprehensive network error management

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is part of the Monstra examples and follows the same license terms.
