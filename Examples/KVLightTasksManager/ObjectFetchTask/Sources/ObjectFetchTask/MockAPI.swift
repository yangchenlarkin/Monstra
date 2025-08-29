import Foundation

/// Simple mocked API that returns deterministic Post objects for valid ids.
/// Demonstrates how a repository would depend on a data source.
enum MockAPI {
    /// Simulate a batch fetch of posts by ID list.
    /// - Parameter ids: list of post identifiers
    /// - Returns: dictionary mapping id -> Post? (nil indicates not found/invalid)
    static func fetchPosts(ids: [String]) async throws -> [String: Post?] {
        print("[MockAPI] start fetch, ids=\(ids)")
        // Simulate network latency
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        var results: [String: Post?] = [:]

        for id in ids {
            // Simple validation: IDs must be non-empty and alphanumeric
            guard !id.isEmpty, id.range(of: "[^a-zA-Z0-9_-]", options: .regularExpression) == nil else {
                results[id] = nil
                continue
            }

            // Generate deterministic content based on id for repeatability
            let title = "Post #\(id)"
            let body = "This is a mocked body for post #\(id)."
            let author = ["Alice", "Bob", "Carol", "Dave"][id.count % 4]
            let publishedAt = Date()

            results[id] = Post(
                id: id,
                title: title,
                body: body,
                author: author,
                publishedAt: publishedAt
            )
        }

        print("[MockAPI] finish fetch, ids=\(ids)")
        return results
    }
}
