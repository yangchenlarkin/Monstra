import Foundation
import Alamofire
import Monstra


let chrome = URL(string: "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg")!
let evernote = URL(string: "https://mac.desktop.evernote.com/builds/Evernote-latest.dmg")!
let slack = URL(string: "https://downloads.slack-edge.com/desktop-releases/mac/universal/4.45.69/Slack-4.45.69-macOS.dmg")!


let manager = KVHeavyTasksManager<URL, Data, Progress, AlamofireDataProvider>(config: .init())

manager.fetch(key: chrome) { result in
    
}

RunLoop.main.run()
