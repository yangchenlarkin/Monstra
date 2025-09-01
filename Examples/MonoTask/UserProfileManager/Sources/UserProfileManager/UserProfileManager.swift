import Foundation
import Monstra
import Combine

final class UserProfileManager {
    var userProfile: AnyPublisher<UserProfile?, Never> { task.$result.removeDuplicates().eraseToAnyPublisher()}
    var isLoading: AnyPublisher<Bool, Never> { task.$isExecuting.removeDuplicates().eraseToAnyPublisher() }
    private let task: MonoTask<UserProfile>

    init() {
        // 1 hour TTL
        self.task = MonoTask<UserProfile>(
            retry: .never,
            resultExpireDuration: 3600.0
        ) { callback in
            Task {
                do {
                    // Assuming a single active user ID for the example. In real apps, pass context.
                    let profile = try await UserProfileMockAPI.getUserProfileAPI()
                    callback(.success(profile))
                } catch {
                    callback(.failure(error))
                }
            }
        }
    }

    func didLogin() {
        task.justExecute(forceUpdate: false)
    }

    func setUser(firstName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await UserProfileMockAPI.setUser(firstName: firstName)
                await task.asyncExecute(forceUpdate: true)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func setUser(age: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await UserProfileMockAPI.setUser(age: age)
                await task.asyncExecute(forceUpdate: true)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func didLogout() {
        task.clearResult(ongoingExecutionStrategy: .cancel, shouldRestartWhenIDLE: false)
    }
}
