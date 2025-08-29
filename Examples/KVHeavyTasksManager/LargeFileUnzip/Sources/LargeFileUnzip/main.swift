import Foundation
import Monstra
import ZIPFoundation

// Demo: download a remote zip to local path and unzip
let zipFilePath = URL(filePath: "demo.zip")
guard let battleNetRemoteURL = URL(string: "https://downloader.battle.net/download/installer/mac/1.0.61/Battle.net-Setup.zip") else {
    fatalError("Invalid Battle.net remote URL")
}

// Download the remote ZIP to zipFilePath synchronously (for demo purposes)
do {
    print("📥 Downloading: \(battleNetRemoteURL.absoluteString)")
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

    // Move to destination (replace if exists)
    let fm = FileManager.default
    if fm.fileExists(atPath: zipFilePath.path) {
        try fm.removeItem(at: zipFilePath)
    }
    try fm.moveItem(at: tmp, to: zipFilePath)
    print("✅ Downloaded to: \(zipFilePath.path)")
} catch {
    print("❌ Download failed: \(error)")
}

typealias UnzipManager = KVHeavyTasksManager<URL, [URL], UnzipEvent, UnzipDataProvider>
let manager = UnzipManager(config: .init())

// Unzip the downloaded demo.zip
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
