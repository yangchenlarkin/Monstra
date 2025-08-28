import Foundation
import Alamofire
import Monstra


let chrome = URL(string: "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg")!
let evernote = URL(string: "https://mac.desktop.evernote.com/builds/Evernote-latest.dmg")!
let slack = URL(string: "https://downloads.slack-edge.com/desktop-releases/mac/universal/4.45.69/Slack-4.45.69-macOS.dmg")!

Task {
    let manager = KVHeavyTasksManager<URL, Data, Progress, AlamofireDataProvider>(config: .init())

    // Execution Merging
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<10 {
            group.addTask {
                let result = await manager.asyncFetch(key: chrome, customEventObserver: { progress in
                    print("fetch task \(i). progress: \(progress.completedUnitCount) / \(progress.totalUnitCount)")
                })
                print("fetch task \(i). result: \(result)")
            }
        }
    }


}

RunLoop.main.run()
