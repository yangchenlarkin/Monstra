import Foundation
import Monstra

let semaphore = DispatchSemaphore(value: 0)
let manager = UserProfileManager()

// Initial get
let userProfileHandler = manager.userProfile.sink { userProfile in
    print("update userProfile: \(String(describing: userProfile))")
}

let isLoadingHandler = manager.isLoading.sink { isLoading in
    print("isLoading: \(isLoading)")
}

print("trigger: didLogin")
manager.didLogin()

print("trigger set fistName: Alicia")
// Update first name then age, forcing refresh after each
manager.setUser(firstName: "Alicia") { result in
    switch result {
    case .success:
        print("Did set firstName: Alicia")
        print("trigger set age: 10")
        manager.setUser(age: 10) { result in
            switch result {
            case .success:
                print("Did set age: 10")
                semaphore.signal()
            case .failure(let e):
                print("Set age error: \(e)")
                semaphore.signal()
            }
        }
    case .failure(let e):
        print("Set firstName error: \(e)")
        semaphore.signal()
    }
}

semaphore.wait()

print("trigger didLogout")
manager.didLogout()
