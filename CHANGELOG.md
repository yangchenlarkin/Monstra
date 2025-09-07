# Changelog

All notable changes to Monstra will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-27

### 🚀 Major Milestone: First Minor Release

### Added
- **Comprehensive Documentation**: Complete API documentation with Jazzy
- **Security Policy**: Added SECURITY.md with vulnerability reporting guidelines
- **Promotion Framework**: Swift Package Index submission and awesome-swift PR
- **CI/CD Optimization**: Split test coverage across parallel jobs for reliability
- **Release Workflow**: Professional release process with comprehensive checklists
- **Community Ready**: GitHub repository optimized for discoverability

### Enhanced
- **README Documentation**: Comprehensive examples and usage guides
- **CocoaPods Integration**: Full podspec with proper configuration
- **Test Coverage**: Maintained 99%+ coverage with improved reliability
- **Cross-Platform Support**: Verified iOS, macOS, tvOS, watchOS compatibility
- **Performance**: Optimized task execution and memory management

### Fixed
- **CI Reliability**: Resolved timeout issues with parallel test execution
- **Memory Management**: Fixed strong capture issues in MonoTask
- **Documentation Links**: All internal and external links verified
- **Version Consistency**: Synchronized versions across all project files

### Community
- **Swift Package Index**: Submitted for automatic discovery
- **awesome-swift**: PR submitted for community visibility
- **GitHub Optimization**: Enhanced repository with topics and social preview

## [0.0.9] - 2025-09-04

### Changed
- Removed debug print statements in `MonoTask` and routed output through `Log` where applicable
- CI: split per-class test jobs on develop; scheduled tests split per class
- README and installation snippets updated to 0.0.9
- CocoaPods podspec version bumped to 0.0.9

### Fixed
- Minor workflow stability improvements

## [0.0.8] - 2025-09-03

### Added
- Scheduled CI logs and analysis for long-running runs
- Guidance and groundwork for Jazzy API docs on feature/api-doc branch

### Changed
- README install snippets bumped to 0.0.8
- CocoaPods podspec version bumped to 0.0.8
- CI maintenance: artifact/cache actions updated to v4 in workflows

### Fixed
- Intermittent CI flakiness analysis; clarified that cancellations were due to max job runtime

## [0.0.7] - 2025-09-01

### Added
- MonoTask `forceUpdate` execution path and public APIs
- Unit tests: comprehensive coverage for forceUpdate scenarios
- Examples: UserProfileManager with Combine publishers and README
- Examples: ModuleInitialization with initialization flow and README

### Changed
- Root README: added links to new examples, updated version references

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
