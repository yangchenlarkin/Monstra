# Changelog

All notable changes to Monstra will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Enhanced README with comprehensive documentation
- Added CocoaPods support with podspec
- Created CONTRIBUTING.md guidelines
- Added MonoTask usage examples

### Changed
- Improved callback queue handling in MonoTask
- Enhanced test coverage and reliability

## [0.0.6] - 2025-08-28

### Added
- LargeFileDownloadManagement example enhancements
- AFNetworkingDataProvider with modern AFNetworking 4.x support
- Provider comparison and switching examples in README
- Monstra logo added to example README

### Changed
- AlamofireDataProvider now uses MemoryCache for resume data with 1GB limit
- Clarified MemoryCache.Configuration.costProvider docs (cost in bytes)
- Updated example README with implementation details and demo URLs

## [1.0.0] - 2025-01-26

### Added
- **MonstraBase**: Foundation utilities and data structures
  - `CPUTimeStamp`: High-precision CPU timestamp utilities
  - `Heap`: Efficient heap data structure implementation
  - `DoublyLink`: Doubly-linked list implementation
  - `HashQueue`: Hash-based queue implementation
  - `RetryCount`: Retry configuration and management
  - `TracingIDFactory`: Unique ID generation for execution tracking

- **Monstore**: Memory caching system
  - `LRUQueue`: High-performance LRU cache with O(1) operations
  - `TTLPriorityLRUQueue`: LRU cache with automatic TTL expiration
  - `MemoryCache`: Core caching functionality
  - `CacheStatistics`: Performance monitoring and metrics

- **Monstask**: Task execution framework
  - `MonoTask`: Single-instance task executor with TTL caching and retry logic
  - `KVHeavyTasksManager`: Heavy task management with priority strategies
  - `KVLightTasksManager`: Light task management for simple operations

### Features
- **Execution Merging**: Multiple concurrent requests merge into single execution
- **TTL-based Caching**: Configurable result expiration
- **Retry Logic**: Automatic retry with exponential backoff
- **Thread Safety**: Full thread safety with semaphore protection
- **Queue Management**: Separate queues for execution and callbacks
- **Manual Cache Control**: Cache invalidation with execution strategies

### Performance
- O(1) time complexity for core cache operations
- Optimized memory usage with object pooling
- High-performance data structures
- Comprehensive performance benchmarking

### Testing
- Extensive unit test coverage
- Performance tests and benchmarks
- Cross-scenario edge case testing
- Memory pressure and resource management tests

## [0.1.0] - 2024-12-01

### Added
- Initial project structure
- Basic memory cache implementation
- Foundation utilities

---

## Versioning

- **Major**: Breaking changes or major new features
- **Minor**: New features (backward compatible)
- **Patch**: Bug fixes and minor improvements

## Migration Guide

### From 0.x to 1.0
- No breaking changes - this is the first stable release
- All APIs remain the same
- Enhanced performance and reliability

---

For detailed information about each release, see the [GitHub releases](https://github.com/yangchenlarkin/Monstra/releases).
