import Foundation

/// Mocked API layer for user profile fetching and updates.
/// Provides async functions to simulate network requests.
enum UserProfileMockAPI {
    private static var storage: UserProfile = {
        // Seed with deterministic records
        return UserProfile(id: "1", nickName: "Alice", age: 24)
    }()

    /// Simulate fetching user profile by ID.
    static func getUserProfileAPI() async throws -> UserProfile {
        try await Task.sleep(nanoseconds: 120_000_000) // 120ms
        return storage
    }

    /// Simulate setting a user's first name (mapped to nickName for this example).
    /// Set APIs do not return the full UserProfile.
    static func setUser(firstName: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        storage.nickName = firstName
    }

    /// Simulate setting a user's age. Set APIs do not return the full UserProfile.
    static func setUser(age: Int) async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        storage.age = age
    }
}
