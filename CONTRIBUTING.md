# Contributing to Monstore

Thank you for your interest in contributing to Monstore! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

- Use the GitHub issue tracker
- Include detailed reproduction steps
- Provide system information (OS, Swift version, etc.)
- Include code examples if possible

### Suggesting Enhancements

- Use the GitHub issue tracker
- Describe the enhancement clearly
- Explain why this enhancement would be useful
- Include use cases and examples

### Submitting Code

- Fork the repository
- Create a feature branch
- Make your changes
- Add tests for new functionality
- Ensure all tests pass
- Submit a pull request

## Development Setup

### Prerequisites

- Swift 5.10+
- Xcode 15+ (for iOS/macOS development)
- SwiftLint and SwiftFormat (installed via Homebrew)

### Setup Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Monstore.git
   cd Monstore
   ```

2. Install development tools:
   ```bash
   brew install swiftlint swiftformat sourcekitten
   ```

3. Build the project:
   ```bash
   swift build
   ```

4. Run tests:
   ```bash
   swift test
   ```

5. Run linting:
   ```bash
   swiftlint lint Sources/
   ```

6. Format code:
   ```bash
   swiftformat .
   ```

## Coding Standards

### Swift Style Guide

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint and SwiftFormat for consistent formatting
- Write clear, descriptive commit messages
- Use meaningful variable and function names

### Documentation

- Document all public APIs
- Include usage examples in documentation
- Update README.md for new features
- Add inline comments for complex logic

### Performance

- Consider performance implications of changes
- Add performance tests for new features
- Benchmark critical code paths
- Document performance characteristics

## Testing

### Test Requirements

- All new features must include tests
- Maintain test coverage above 90%
- Include both unit and integration tests
- Add performance tests for critical paths

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter TestClassName

# Run performance tests
swift test --filter PerformanceTests
```

### Test Guidelines

- Write clear, focused test cases
- Use descriptive test names
- Test edge cases and error conditions
- Mock external dependencies
- Use appropriate assertions

## Pull Request Process

### Before Submitting

1. **Ensure code quality**:
   - Run `swiftlint lint Sources/`
   - Run `swiftformat .`
   - Fix any warnings or errors

2. **Test thoroughly**:
   - Run all tests: `swift test`
   - Test on multiple platforms if applicable
   - Verify performance characteristics

3. **Update documentation**:
   - Update README.md if needed
   - Add API documentation for new features
   - Update CHANGELOG.md

### Pull Request Guidelines

- Use descriptive titles
- Include detailed descriptions
- Reference related issues
- Include before/after performance comparisons if applicable
- Add screenshots for UI changes (if applicable)

### Review Process

- All PRs require review
- Address review comments promptly
- Maintain clean commit history
- Squash commits when appropriate

## Release Process

### Versioning

- Follow [Semantic Versioning](https://semver.org/)
- Update version in Package.swift
- Update CHANGELOG.md
- Create release notes

### Release Checklist

- [ ] All tests pass
- [ ] Documentation is up to date
- [ ] CHANGELOG.md is updated
- [ ] Version is updated in Package.swift
- [ ] Performance benchmarks are documented
- [ ] Release notes are prepared

### Creating a Release

1. Update version numbers
2. Update CHANGELOG.md
3. Create a release branch
4. Submit PR for review
5. Merge and tag the release
6. Create GitHub release

## Getting Help

- Check existing issues and discussions
- Ask questions in GitHub Discussions
- Contact maintainers for urgent issues
- Review documentation and examples

## Recognition

Contributors will be recognized in:
- CHANGELOG.md
- README.md contributors section
- GitHub contributors page

Thank you for contributing to Monstore! 