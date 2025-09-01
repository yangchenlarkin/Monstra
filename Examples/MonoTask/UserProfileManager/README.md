# UserProfile Manager Example

This example demonstrates single-instance user profile management with caching using `MonoTask`.

It shows how to:
- Cache a single user's profile with a 1 hour TTL
- Merge concurrent requests into one execution
- Refresh the cached profile after mutations where the set APIs do not return the profile
- Expose UI-friendly state via Combine publishers: `userProfile` and `isLoading`

## Architecture

- `UserProfileManager`
  - Holds a `MonoTask<UserProfile>` with `resultExpireDuration = 3600` seconds
  - Exposes Combine publishers:
    - `userProfile: AnyPublisher<UserProfile?, Never>`: emits cached/fetched profile
    - `isLoading: AnyPublisher<Bool, Never>`: emits whether the task is executing
  - Public API:
    - `didLogin()`: kicks off a fetch (forceUpdate=false) to warm the cache
    - `setUser(firstName:)`: updates nickname through API, then forces a refresh
    - `setUser(age:)`: updates age through API, then forces a refresh
    - `didLogout()`: clears cached result and cancels ongoing execution

- `UserProfileMockAPI`
  - Simulates get/set calls; setters do not return the profile

- `main.swift`
  - Subscribes to the two publishers and prints state transitions
  - Drives a simple flow: login → set first name → set age → logout

## How to Run

From this example directory:

```bash
swift run
```

## Expected Output

Below is a sample run log from the demo program:

```
update userProfile: nil
isLoading: false
trigger: didLogin
trigger set fistName: Alicia
isLoading: true
update userProfile: Optional(UserProfileManager.UserProfile(id: "1", nickName: "Alicia", age: 24))
isLoading: false
Did set firstName: Alicia
trigger set age: 10
isLoading: true
update userProfile: Optional(UserProfileManager.UserProfile(id: "1", nickName: "Alicia", age: 10))
isLoading: false
Did set age: 10
trigger didLogout
update userProfile: nil
Program ended with exit code: 0
```

## Key Points

- **One-call-one-callback**: all concurrent subscribers receive the same single result per execution.
- **Force refresh after set**: since set APIs do not return the updated model, the manager triggers `MonoTask` with `forceUpdate=true` to fetch fresh data.
- **Cache-first UX**: `didLogin()` warms the cache; subsequent reads within TTL avoid redundant network calls.
- **Clear on logout**: `didLogout()` cancels any in-flight work and clears cached data.
