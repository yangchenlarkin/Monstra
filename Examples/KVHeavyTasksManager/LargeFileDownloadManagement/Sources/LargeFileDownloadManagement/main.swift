import Alamofire
import Foundation
import Monstra

let chrome = URL(string: "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg")!
let evernote = URL(string: "https://mac.desktop.evernote.com/builds/Evernote-latest.dmg")!
let slack =
    URL(string: "https://downloads.slack-edge.com/desktop-releases/mac/universal/4.45.69/Slack-4.45.69-macOS.dmg")!

typealias AFNetworkingManager = KVHeavyTasksManager<
    URL,
    Data,
    Progress,
    AFNetworkingDataProvider
> // try AlamofireDataProvider to see the difference
typealias AlamofireManager = KVHeavyTasksManager<
    URL,
    Data,
    Progress,
    AlamofireDataProvider
> // try AFNetworkingDataProvider to see the difference

let manager1 = AFNetworkingManager(config: .init())

let config2 = AlamofireManager
    .Config(
        maxNumberOfQueueingTasks: 1,
        maxNumberOfRunningTasks: 1,
        priorityStrategy: .FIFO
    ) // try other strategies to see the difference
let manager2 = AlamofireManager(config: config2)

Task {
    // Execution Merging
    await withTaskGroup(of: Void.self) { group in
        for i in 0 ..< 10 {
            group.addTask {
                let result = await manager1.asyncFetch(key: chrome, customEventObserver: { progress in
                    print("fetch task \(i). progress: \(progress.completedUnitCount) / \(progress.totalUnitCount)")
                })
                print("fetch task \(i). result: \(result)")
            }
        }
    }

    // task queueing
    manager2.fetch(key: chrome, customEventObserver: { progress in
        print("downloading chrome: \(100 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount))%")
    }) { result in
        print("did fetch chrome. result: \(result)")
    }
    manager2.fetch(key: slack, customEventObserver: { progress in
        print("downloading slack: \(100 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount))%")
    }, result: { result in
        print("did fetch slack. result: \(result)")
    })
    manager2.fetch(key: evernote, customEventObserver: { progress in
        print("downloading evernote: \(100 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount))%")
    }, result: { result in
        print("did fetch evernote. result: \(result)")
    })
}

RunLoop.main.run()
