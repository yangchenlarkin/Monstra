import Foundation
import Monstra

// MARK: - Simple Download Example

@main
struct LargeFileDownloadManagerApp {
    static func main() async {
        print("🚀 Large File Download Manager with Monstra")
        print("===========================================")
        
        // Create a simple download manager using KVHeavyTasksManager
        let downloadManager = KVHeavyTasksManager<String, Data>(
            config: .init(
                dataProvider: .asyncMonoprovide { urlString in
                    guard let url = URL(string: urlString) else {
                        throw URLError(.badURL)
                    }
                    
                    print("📥 Starting download from: \(urlString)")
                    
                    // Simulate a large file download with progress
                    let data = try await downloadFile(from: url)
                    print("✅ Download completed: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
                    
                    return data
                },
                priorityStrategy: .FIFO,
                maxNumberOfRunningTasks: 2,
                maxNumberOfQueueingTasks: 5
            )
        )
        
        // Test URLs (small files for demonstration)
        let testURLs = [
            "https://httpbin.org/bytes/1024",      // 1KB
            "https://httpbin.org/bytes/2048",      // 2KB
            "https://httpbin.org/bytes/4096"       // 4KB
        ]
        
        print("\n📋 Starting downloads...")
        print("URLs to download:")
        for (index, url) in testURLs.enumerated() {
            print("  \(index + 1). \(url)")
        }
        
        do {
            // Download files concurrently using the task manager
            let results = try await withTaskGroup(of: (String, Data).self) { group in
                for urlString in testURLs {
                    group.addTask {
                        let data = try await downloadManager.fetch(for: urlString)
                        return (urlString, data)
                    }
                }
                
                var results: [(String, Data)] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
            
            print("\n✅ All downloads completed successfully!")
            print("\n📊 Download Summary:")
            for (index, (url, data)) in results.enumerated() {
                print("  File \(index + 1):")
                print("    🌐 URL: \(url)")
                print("    📏 Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Simulates downloading a file from a URL
    /// In a real implementation, this would use URLSession or Alamofire
    static func downloadFile(from url: URL) async throws -> Data {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Simulate file size based on URL
        let fileSize = url.absoluteString.contains("1024") ? 1024 :
                      url.absoluteString.contains("2048") ? 2048 :
                      url.absoluteString.contains("4096") ? 4096 : 1024
        
        // Generate mock data
        let data = Data(repeating: 0x42, count: fileSize)
        return data
    }
}
