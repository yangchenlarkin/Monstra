import Foundation

/// Mocked API layer for user profile fetching and updates.
/// Provides async functions to simulate network requests.
enum UserProfileMockAPI {
    private static var storage: [String: UserProfile] = {
        // Seed with deterministic records
        var seed: [String: UserProfile] = [:]
        seed["1"] = UserProfile(id: "1", nickName: "Alice", age: 24)
        seed["2"] = UserProfile(id: "2", nickName: "Bob", age: 31)
        seed["3"] = UserProfile(id: "3", nickName: "Carol", age: 28)
        return seed
    }()

    /// Simulate fetching user profile by ID.
    static func getUserProfileAPI(id: String) async throws -> UserProfile? {
        try await Task.sleep(nanoseconds: 120_000_000) // 120ms
        return storage[id]
    }

    /// Simulate setting a user's first name (mapped to nickName for this example).
    /// Set APIs do not return the full UserProfile.
    static func setUserFirstName(id: String, firstName: String) async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        guard var profile = storage[id] else { return }
        profile.nickName = firstName
        storage[id] = profile
    }

    /// Simulate setting a user's age. Set APIs do not return the full UserProfile.
    static func setUserAge(id: String, age: Int) async throws {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        guard var profile = storage[id] else { return }
        profile.age = age
        storage[id] = profile
    }
}
