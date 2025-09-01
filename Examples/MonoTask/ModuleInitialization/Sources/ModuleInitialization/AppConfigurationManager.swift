import Foundation
import Monstra

final class AppConfigurationManager {
    private let task: MonoTask<AppConfiguration>

    init() {
        self.task = MonoTask<AppConfiguration>(
            retry: .count(count: 2, intervalProxy: .fixed(timeInterval: 0.2)),
            resultExpireDuration: .infinity
        ) { callback in
            Task {
                do {
                    let cfg = try await AppConfigurationAPI.getAppConfiguration()
                    callback(.success(cfg))
                } catch {
                    callback(.failure(error))
                }
            }
        }
    }

    func initializeModule(completion: ((Result<AppConfiguration, Error>) -> Void)? = nil) {
        task.execute(forceUpdate: false, then: completion)
    }

    func getConfiguration() async -> Result<AppConfiguration, Error> {
        await task.asyncExecute()
    }
    
    func getConfig1() async -> Result<String, Error> {
        switch await task.asyncExecute() {
        case .success(let config):
            return .success(config.config1)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func useConfig1(str: String) async -> Result<String, Error> {
        switch await task.asyncExecute() {
        case .success(let config):
            return .success("\(str) is using \(config.config1)")
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func getConfig2() async -> Result<String, Error> {
        switch await task.asyncExecute() {
        case .success(let config):
            return .success(config.config2)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func useConfig2(str: String) async -> Result<String, Error> {
        switch await task.asyncExecute() {
        case .success(let config):
            return .success("\(str) is using \(config.config2)")
        case .failure(let error):
            return .failure(error)
        }
    }
}


