import Foundation
import Monstra
import Combine

final class UserProfileManager {
    // Public publishers
    var userProfile: AnyPublisher<UserProfile?, Never> { userProfileSubject.removeDuplicates().eraseToAnyPublisher() }
    var isLoading: AnyPublisher<Bool, Never> { isLoadingSubject.removeDuplicates().eraseToAnyPublisher() }

    // Internal subjects to bridge non-published MonoTask state
    private let userProfileSubject = CurrentValueSubject<UserProfile?, Never>(nil)
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)

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

        // Initialize subjects from current MonoTask snapshot
        self.userProfileSubject.send(task.currentResult)
        self.isLoadingSubject.send(task.isExecuting)
    }

    func didLogin() {
        isLoadingSubject.send(true)
        Task {
            let result = await task.asyncExecute(forceUpdate: false)
            switch result {
            case .success(let profile):
                userProfileSubject.send(profile)
            case .failure:
                // Keep last known value; optionally send nil
                break
            }
            isLoadingSubject.send(false)
        }
    }

    func setUser(firstName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoadingSubject.send(true)
        Task {
            do {
                try await UserProfileMockAPI.setUser(firstName: firstName)
                let result = await task.asyncExecute(forceUpdate: true)
                switch result {
                case .success(let profile):
                    userProfileSubject.send(profile)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
            isLoadingSubject.send(false)
        }
    }

    func setUser(age: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoadingSubject.send(true)
        Task {
            do {
                try await UserProfileMockAPI.setUser(age: age)
                let result = await task.asyncExecute(forceUpdate: true)
                switch result {
                case .success(let profile):
                    userProfileSubject.send(profile)
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
            isLoadingSubject.send(false)
        }
    }
    
    func didLogout() {
        task.clearResult(ongoingExecutionStrategy: .cancel, shouldRestartWhenIDLE: false)
        userProfileSubject.send(nil)
        isLoadingSubject.send(false)
    }
}
