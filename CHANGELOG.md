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
