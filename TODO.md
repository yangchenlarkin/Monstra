# TODO

## KVLightTasks Enhancements

### 1. Add Cache-Related Test Cases for KVLightTasks
- [x] Add comprehensive test cases for cache functionality in KVLightTasks
- [x] Test cache hit scenarios (null and non-null elements)
- [x] Test cache miss scenarios
- [x] Test cache eviction and TTL expiration
- [x] Test cache statistics and reporting
- [x] Test cache configuration options
- [x] Test concurrent cache access patterns

### 2. Add Structured Concurrency Interfaces to KVLightTasks
- [x] Implement async/await interfaces for KVLightTasks
- [x] Add `async func fetch(key: K) async throws -> Element?`
- [x] Add `async func fetch(keys: [K]) async throws -> [K: Element?]`
- [x] Add `func fetch(keys: [K]) async throws -> [(K, Element?)]`
- [x] Implement proper task cancellation support
- [x] Add structured concurrency with task groups
- [x] Ensure backward compatibility with existing callback-based APIs

### 3. Add Single Callback Interface for All Keys
- [x] Add interface that triggers callback only once when all keys are processed
- [x] Implement `func fetch(keys: [K], completion: @escaping ([(K, Result<Element?, Error>)]) -> Void)`
- [x] Add `async func fetch(keys: [K]) async throws -> [(K, Element?)]`
- [x] Ensure all keys are processed before single callback is triggered
- [x] Handle partial failures gracefully
- [x] Add timeout support for batch operations
- [x] Implement proper error aggregation for batch failures

### 4. Check KVLightTasksTests for Batch Processing Order Issues
- [x] Review all test cases that use batch fetch data providers (multifetch/asyncMultifetch)
- [x] Identify tests where keys are mixed (success/failure keys together)
- [x] Check for tests where `Set<K>(keys)` conversion affects batch ordering
- [x] Found problematic test cases:
  - `testErrorPropagationInBatches` (line 866): Tests mixed success/failure keys in batches
  - `testMultifetchErrorHandling` (line 406): Tests error_key with normal keys in same batch
  - `testMixedValidInvalidKeys` (line 2983): Tests valid/invalid keys mixed together
  - `testKeysWithComplexValidationRules` (line 3216): Tests various key patterns mixed
  - `testAsyncMonofetchDataProviderWithErrors` (line 3862): Tests error_key with normal keys
  - `testAsyncMultifetchDataProviderWithErrors` (line 3981): Tests error_key in batch with other keys
- [x] These tests may have non-deterministic behavior due to Set conversion losing key order
- [x] Consider adding explicit batch ordering tests or documenting the non-deterministic nature

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
