#!/usr/bin/env swift

import Foundation
import Monstask
import MonstraBase
import Alamofire
import CryptoKit

class LocalDataProvider: Monstask.KVHeavyTaskDataProvider {
    typealias T = UInt
    typealias K = String
    typealias Element = String
    
    let key: K
    let progressCallback: ProgressCallback?
    let resultCallback: ResultCallback
    
    private var selfRetain: LocalDataProvider? = nil
    private var semaphore = DispatchSemaphore(value: 1)
    
    required init(key: K, progressCallback: ProgressCallback?, resultCallback: @escaping ResultCallback) {
        self.key = key
        self.progressCallback = progressCallback
        self.resultCallback = resultCallback
    }
    
    enum Errors: Error {
        case cancelled
    }
    
    func start() {
        semaphore.wait()
        defer { semaphore.signal() }
        
        if selfRetain != nil { return }
        selfRetain = self
        
        DispatchQueue.global().async { [weak self] in
            var res = ""
            guard let self else { return }
            for c in key {
                Thread.sleep(forTimeInterval: 1)
                semaphore.wait()
                defer { semaphore.signal() }
                if selfRetain == nil {
                    resultCallback(key, .failure(Errors.cancelled))
                    return
                }
                res.append(c)
                progressCallback?(key, .init(totalUnitCount: UInt(key.count), completedUnitCount: UInt(res.count)))
            }
            resultCallback(key, .success(res))
        }
    }
    
    func stop() -> Bool {
        semaphore.wait()
        defer { semaphore.signal() }
        selfRetain = nil
        
        return false
    }
}

class AlamofireDataProvider: Monstask.KVHeavyTaskDataProvider {
    typealias T = UInt64
    typealias K = URL
    typealias Element = Data
    
    let key: URL
    let progressCallback: ProgressCallback?
    let resultCallback: ResultCallback
    
    var tmpData: Data? = nil
    
    private var request: DownloadRequest? = nil
    
    required init(key: K, progressCallback: ProgressCallback?, resultCallback: @escaping ResultCallback) {
        self.key = key
        self.progressCallback = progressCallback
        self.resultCallback = resultCallback
    }
    
    func start() {
        let tmpDirectory = Self.getCachesDirectory()
        let scnFolder = tmpDirectory.appendingPathComponent("AlamofireDataProvider", isDirectory: true)
        let destinationURL = scnFolder.appendingPathComponent(key.absoluteString.md5())
        
        if let tmpData {
            request = AF.download(resumingWith: tmpData)
        } else {
            request = AF.download(key, to: { _, _ in return (destinationURL, [.createIntermediateDirectories, .removePreviousFile]) })
        }
        request?.downloadProgress { [weak self] progress in
            guard let self else { return }
            if progress.totalUnitCount > 0 {
                progressCallback?(key, .init(totalUnitCount: UInt64(progress.totalUnitCount), completedUnitCount: UInt64(progress.completedUnitCount)))
            } else {
                progressCallback?(key, .init(totalUnitCount: nil, completedUnitCount: UInt64(progress.completedUnitCount)))
            }
        }
        
        request?.responseData { [weak self] response in
            guard let self else { return }
            switch response.result {
            case .success(let data):
                self.resultCallback(key, .success(data))
            case .failure(let error):
                self.resultCallback(key, .failure(error))
            }
        }
    }
    
    func stop() -> Bool {
        request?.cancel(byProducingResumeData: { data in
            self.tmpData = data
            self.request = nil
        })
        return false
    }
    
    private static func getCachesDirectory() -> URL {
        if let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
           return cachesDirectory
        }
        return FileManager.default.temporaryDirectory
    }
}

extension String {
    func md5() -> String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

func loadLocalData() {
    let taskHandler = LocalDataProvider(key: "12345") { key, progress in
        print(progress)
    } resultCallback: { key, res in
        print(res)
    }

    taskHandler.start()
}

var taskHandler: AlamofireDataProvider? = nil
var onceToken: Bool {
    if _onceToken {
        _onceToken = false
        return true
    } else {
        return false
    }
}
var _onceToken = true

if let url = URL(string: "https://productionresultssa2.blob.core.windows.net/actions-results/1701f204-0172-40de-be9f-350cc2ecdebb/workflow-job-run-cd3f5f4f-de11-54c7-9e5c-60228f2b0933/artifacts/5fe2186078717de4f2fbf3b9c27e9eceab0d6a05cc0de6fa17290f1af50bece5.zip?rscd=attachment%3B+filename%3D%22IPA-zenni_Debug_6.5.8_291613_2025_07_29_16_13_24.zip%22&se=2025-07-29T09%3A30%3A37Z&sig=3tJbeOn4hLQdvUAbsFF7fRIt81f4NoUFGG2Bi%2FMnaso%3D&ske=2025-07-29T20%3A14%3A20Z&skoid=ca7593d4-ee42-46cd-af88-8b886a2f84eb&sks=b&skt=2025-07-29T08%3A14%3A20Z&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skv=2025-05-05&sp=r&spr=https&sr=b&st=2025-07-29T09%3A20%3A32Z&sv=2025-05-05") {
    taskHandler = AlamofireDataProvider(key: url) { key, progress in
        print("🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃")
        print(progress)
        print("🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃🏃")
        
        if progress.completedUnitCount > 719054, onceToken {
            taskHandler?.stop()
            DispatchQueue.global().asyncAfter(deadline: .now()+3) {
                taskHandler?.start()
            }
        }
    } resultCallback: { key, res in
        print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅")
        print(res)
        print("✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅✅")
    }
    taskHandler?.start()
}

RunLoop.main.run()
