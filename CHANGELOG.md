# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive performance test suite with scale testing
- Time complexity analysis for LRUQueue and LRUQueueWithTTL
- SwiftLint and SwiftFormat configuration for code quality
- English performance test report with operation count details
- Large-scale testing (10,000 operations) for time complexity verification

### Changed
- Refactored LRUQueue implementation for better performance
- Optimized LRUQueueWithTTL with improved TTL management
- Enhanced Heap implementation with better memory efficiency
- Updated README with comprehensive usage examples

### Fixed
- Corrected method calls in scale tests
- Fixed SwiftLint configuration for cache library requirements
- Improved test organization and structure

## [0.1.0] - 2024-12-19

### Added
- Initial release of Monstore cache library
- LRUQueue: High-performance LRU cache implementation
- LRUQueueWithTTL: LRU cache with time-to-live support
- Heap: Efficient heap data structure implementation
- CPUTimeStamp: High-precision CPU timestamp utilities
- MemoryCache: Core memory caching functionality
- Comprehensive unit tests for all components
- Performance benchmarks and comparisons
- MIT License

### Features
- O(1) time complexity for core operations
- Memory-efficient implementations with object pooling
- Thread-safe design considerations
- Generic implementations supporting any Hashable key types
- Automatic TTL expiration management
- High-precision performance measurement tools

---

## Version History

- **0.1.0**: Initial release with core cache implementations
- **Unreleased**: Performance optimizations and comprehensive testing

## Migration Guide

### From 0.1.0 to Unreleased
No breaking changes. All existing APIs remain compatible.

## Contributing

When adding new features or making changes, please update this changelog following the format above. 