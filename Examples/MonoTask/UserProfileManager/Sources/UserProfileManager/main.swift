import Foundation
import Monstra

// Minimal sanity check invoking the mock API directly for now
// Repository/MonoTask usage can be layered next.
let semaphore = DispatchSemaphore(value: 0)

Task {
    do {
        if let p1 = try await UserProfileMockAPI.getUserProfileAPI(id: "1") {
            print("Fetched: \([p1.id, p1.nickName, String(p1.age)].joined(separator: ", "))")
        }
        try await UserProfileMockAPI.setUserFirstName(id: "1", firstName: "Alicia")
        try await UserProfileMockAPI.setUserAge(id: "1", age: 25)
        if let p1b = try await UserProfileMockAPI.getUserProfileAPI(id: "1") {
            print("Updated: \([p1b.id, p1b.nickName, String(p1b.age)].joined(separator: ", "))")
        }
    } catch {
        print("Error: \(error)")
    }
    semaphore.signal()
}

semaphore.wait()
