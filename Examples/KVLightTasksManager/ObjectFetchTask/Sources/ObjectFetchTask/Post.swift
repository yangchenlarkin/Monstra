import Foundation

/// Domain model used by the example to represent a social post.
/// Minimal fields keep the focus on KVLightTasksManager behavior.
struct Post: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let body: String
    let author: String
    let publishedAt: Date
}
