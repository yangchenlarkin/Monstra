import Foundation
import Monstra
import ZIPFoundation

enum UnzipEvent {
    case didStart
    case progress(Double) // 0.0 - 1.0
    case didFinish
}

/// Unzips a .zip file from a given URL into a destination directory.
/// Key: URL to local .zip file
/// Result: [URL] list of extracted file URLs
final class UnzipDataProvider: Monstra.KVHeavyTaskBaseDataProvider<URL, [URL], UnzipEvent>,
    Monstra.KVHeavyTaskDataProviderInterface
{
    private let destinationDirectory: URL
    private var isRunning: Bool = false {
        didSet { customEventPublisher(isRunning ? .didStart : .didFinish) }
    }

    /// Required initializer used by KVHeavyTasksManager.
    /// Chooses a default destination directory based on the zip filename.
    required init(
        key: URL,
        customEventPublisher: @escaping CustomEventPublisher,
        resultPublisher: @escaping ResultPublisher
    ) {
        let baseDir = FileManager.default.temporaryDirectory
        let folderName = key.deletingPathExtension().lastPathComponent + "_unzipped"
        destinationDirectory = baseDir.appendingPathComponent(folderName, isDirectory: true)
        super.init(key: key, customEventPublisher: customEventPublisher, resultPublisher: resultPublisher)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        DispatchQueue.global(qos: .utility).async {
            let result: Result<[URL]?, Error>
            do {
                try FileManager.default.createDirectory(
                    at: self.destinationDirectory,
                    withIntermediateDirectories: true
                )
                let archive = try Archive(url: self.key, accessMode: .read)

                var extractedURLs: [URL] = []
                // Compute total entries for progress (single pass to count)
                var totalEntries = 0.0
                for _ in archive {
                    totalEntries += 1
                }

                var index = 0.0
                for entry in archive {
                    guard self.isRunning else { throw NSError(
                        domain: "Unzip",
                        code: -999,
                        userInfo: [NSLocalizedDescriptionKey: "Cancelled"]
                    ) }
                    let outURL = self.destinationDirectory.appendingPathComponent(entry.path)
                    let outDir = outURL.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
                    _ = try archive.extract(entry, to: outURL)
                    extractedURLs.append(outURL)
                    index += 1
                    self.customEventPublisher(.progress(min(1.0, index / max(1.0, totalEntries))))
                }
                result = .success(extractedURLs)
            } catch {
                result = .failure(error)
            }
            guard self.isRunning else { return }
            self.isRunning = false
            self.resultPublisher(result)
        }
    }

    @discardableResult
    func stop() -> KVHeavyTaskDataProviderStopAction {
        if isRunning { isRunning = false }
        return .dealloc
    }
}
