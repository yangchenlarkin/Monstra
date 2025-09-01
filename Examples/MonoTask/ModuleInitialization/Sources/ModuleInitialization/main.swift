import Foundation
import Monstra

let semaphore = DispatchSemaphore(value: 0)
let manager = AppConfigurationManager()

print("[ModuleInitialization] start initializeModule()")
manager.initializeModule { result in
    switch result {
    case .success(let config):
        print("[ModuleInitialization] initialized: config1=\(config.config1), config2=\(config.config2)")
    case .failure(let error):
        print("[ModuleInitialization] failed: \(error)")
    }
}

Task {
    print(await manager.getConfig1())
}

Task {
    print(await manager.getConfig2())
}

Task {
    print(await manager.useConfig1(str: "main.swift"))
}

Task {
    print(await manager.useConfig2(str: "main.swift"))
}

semaphore.wait()

