import Foundation
import Monstra

// Demo: unzip a local zip file to tmp directory
let zipFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("demo.zip")
let destDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("unzipped_demo")

typealias UnzipManager = KVHeavyTasksManager<URL, [URL], UnzipEvent, UnzipDataProvider>
let manager = UnzipManager(config: .init())

// In practice, ensure demo.zip exists at zipFile
manager.fetch(key: zipFile, customEventObserver: { event in
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
