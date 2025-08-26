---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: ['bug']
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Create cache with '...'
2. Call method '....'
3. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Actual behavior**
A clear and concise description of what actually happened.

**Code Example**
```swift
// Please provide a minimal code example that reproduces the issue
let cache = LRUQueue<String, Int>(capacity: 100)
// ... your code here
```

**Environment:**
 - OS: [e.g. iOS 17.0, macOS 14.0]
 - Swift Version: [e.g. 5.5]
 - Monstore Version: [e.g. 1.0.0]
 - Xcode Version: [e.g. 15.0]

**Additional context**
Add any other context about the problem here, including:
- Performance impact if applicable
- Memory usage patterns
- Concurrent access patterns
- Any error messages or stack traces

**Checklist**
- [ ] I have searched existing issues to avoid duplicates
- [ ] I have provided a minimal reproduction case
- [ ] I have included all relevant environment information
- [ ] I have tested with the latest version of Monstore 