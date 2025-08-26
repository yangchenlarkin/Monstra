# Contributing to Monstra

Thank you for your interest in contributing to Monstra! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **🐛 Bug Reports**: Report bugs and issues
- **💡 Feature Requests**: Suggest new features and improvements
- **📚 Documentation**: Improve documentation and examples
- **🧪 Tests**: Add or improve tests
- **🔧 Code**: Submit bug fixes and new features
- **📖 Examples**: Create practical usage examples

## 🚀 Getting Started

### Prerequisites

- Swift 5.10+
- Xcode 15+ (for iOS/macOS development)
- Git

### Development Setup

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/Monstra.git
   cd Monstra
   ```

2. **Install development tools** (optional but recommended)
   ```bash
   brew install swiftlint swiftformat
   ```

3. **Build the project**
   ```bash
   swift build
   ```

4. **Run tests**
   ```bash
   swift test
   ```

## 📝 Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b bugfix/your-bug-description
```

### 2. Make Your Changes

- Follow the existing code style and patterns
- Add tests for new functionality
- Update documentation as needed
- Ensure all tests pass

### 3. Commit Your Changes

```bash
git add .
git commit -m "feat: add new feature description"
```

**Commit Message Format:**
- `feat:` for new features
- `fix:` for bug fixes
- `docs:` for documentation changes
- `test:` for test additions
- `refactor:` for code refactoring
- `style:` for formatting changes

### 4. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a Pull Request on GitHub.

## 🧪 Testing Guidelines

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suites
swift test --filter MonoTaskTests
swift test --filter MemoryCacheTests
swift test --filter PerformanceTests

# Run with verbose output
swift test --verbose
```

### Test Requirements

- **Coverage**: Aim for high test coverage (80%+)
- **Unit Tests**: Test individual components thoroughly
- **Integration Tests**: Test component interactions
- **Performance Tests**: Ensure performance characteristics
- **Edge Cases**: Test boundary conditions and error scenarios

## 📚 Code Style Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Add comprehensive documentation comments
- Keep functions focused and concise

### Documentation

- Use Swift DocC format for API documentation
- Include usage examples in comments
- Document complex algorithms and design decisions
- Keep README and documentation up to date

### Performance

- Consider performance implications of changes
- Run performance tests before and after changes
- Document performance characteristics
- Avoid unnecessary allocations and computations

## 🐛 Bug Reports

### Before Reporting

1. Check if the issue has already been reported
2. Try to reproduce the issue with the latest version
3. Check if it's a known limitation

### Bug Report Template

```markdown
**Description**
Brief description of the issue

**Steps to Reproduce**
1. Step 1
2. Step 2
3. Step 3

**Expected Behavior**
What you expected to happen

**Actual Behavior**
What actually happened

**Environment**
- OS: [e.g., macOS 14.0, iOS 17.0]
- Swift Version: [e.g., 5.10]
- Monstra Version: [e.g., 1.0.0]

**Additional Context**
Any other relevant information
```

## 💡 Feature Requests

### Feature Request Template

```markdown
**Problem Statement**
Describe the problem you're trying to solve

**Proposed Solution**
Describe your proposed solution

**Alternatives Considered**
Describe alternatives you've considered

**Additional Context**
Any other relevant information
```

## 🔍 Code Review Process

### Pull Request Requirements

- **Tests**: All tests must pass
- **Documentation**: Update relevant documentation
- **Examples**: Add examples for new features
- **Performance**: Consider performance impact
- **Backward Compatibility**: Maintain API compatibility

### Review Checklist

- [ ] Code follows project style guidelines
- [ ] Tests are comprehensive and pass
- [ ] Documentation is updated
- [ ] Performance impact is considered
- [ ] Backward compatibility is maintained
- [ ] Examples are provided for new features

## 📋 Issue Labels

We use the following labels to categorize issues:

- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Improvements or additions to documentation
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention is needed
- `performance`: Performance-related issues
- `question`: Further information is requested
- `wontfix`: This will not be worked on

## 🎯 Areas for Contribution

### High Priority

- Performance improvements
- Additional test coverage
- Documentation improvements
- Bug fixes

### Medium Priority

- New utility functions
- Additional examples
- Performance benchmarks
- Cross-platform support

### Low Priority

- Nice-to-have features
- Experimental implementations
- Additional convenience methods

## 📞 Getting Help

### Questions and Discussion

- **GitHub Discussions**: Use GitHub Discussions for questions
- **GitHub Issues**: Use Issues for bugs and feature requests
- **Pull Requests**: Use PRs for code contributions

### Community Guidelines

- Be respectful and inclusive
- Help others learn and contribute
- Provide constructive feedback
- Follow the project's code of conduct

## 🏆 Recognition

Contributors will be recognized in:

- Project README
- Release notes
- GitHub contributors list
- Project documentation

## 📄 License

By contributing to Monstra, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing to Monstra! 🚀
