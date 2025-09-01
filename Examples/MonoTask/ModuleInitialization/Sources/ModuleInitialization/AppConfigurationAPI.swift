import Foundation

enum AppConfigurationAPI {
    static func getAppConfiguration() async throws -> AppConfiguration {
        print("[Mock api] start fetch configuration")
        try await Task.sleep(nanoseconds: 120_000_000)
        print("[Mock api] did fetch configuration")
        return AppConfiguration(config1: "value-1", config2: "value-2")
    }
}


