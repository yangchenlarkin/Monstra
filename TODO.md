# TODO

## KVLightTasks Enhancements

### 1. Add Cache-Related Test Cases for KVLightTasks
- [ ] Add comprehensive test cases for cache functionality in KVLightTasks
- [ ] Test cache hit scenarios (null and non-null elements)
- [ ] Test cache miss scenarios
- [ ] Test cache eviction and TTL expiration
- [ ] Test cache statistics and reporting
- [ ] Test cache configuration options
- [ ] Test concurrent cache access patterns

### 2. Add Structured Concurrency Interfaces to KVLightTasks
- [ ] Implement async/await interfaces for KVLightTasks
- [ ] Add `async func fetch(key: K) async throws -> Element?`
- [ ] Add `async func fetch(keys: [K]) async throws -> [K: Element?]`
- [ ] Add `func fetch(keys: [K]) async throws -> [(K, Element?)]`
- [ ] Implement proper task cancellation support
- [ ] Add structured concurrency with task groups
- [ ] Ensure backward compatibility with existing callback-based APIs

### 3. Add Single Callback Interface for All Keys
- [ ] Add interface that triggers callback only once when all keys are processed
- [ ] Implement `func fetch(keys: [K], completion: @escaping ([(K, Result<Element?, Error>)]) -> Void)`
- [ ] Add `async func fetch(keys: [K]) async throws -> [(K, Element?)]`
- [ ] Ensure all keys are processed before single callback is triggered
- [ ] Handle partial failures gracefully
- [ ] Add timeout support for batch operations
- [ ] Implement proper error aggregation for batch failures

## Implementation Notes

### Cache Testing Strategy
- Focus on testing the integration between KVLightTasks and MemoryCache
- Test different cache configurations and their impact on performance
- Verify cache statistics reporting functionality

### Structured Concurrency Design
- Maintain existing callback-based API for backward compatibility
- Add new async interfaces alongside existing ones
- Use Swift's structured concurrency features for better error handling and cancellation

### Batch Callback Interface
- Ensure atomic behavior - either all keys succeed or proper error handling
- Consider implementing progress reporting for large batches
- Add configuration options for batch timeout and retry behavior 