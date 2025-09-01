import Foundation

/// Domain model representing a user's profile.
/// This keeps the example focused on MonoTask orchestration rather than model complexity.
struct UserProfile: Codable, Hashable, Identifiable {
    let id: String
    var nickName: String
    var age: Int

    // Map to requested property names where applicable
    var userID: String { id }
}
