# Security Policy

## Supported Versions

We actively support the following versions of Monstra with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of Monstra seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please send an email to the repository maintainer or create a private security advisory on GitHub.

Include the following information:
- Type of issue (e.g. memory leak, concurrency issue, etc.)
- Full paths of source file(s) related to the issue
- Step-by-step instructions to reproduce the issue
- Impact of the issue and potential exploitation

### Response Timeline

We will acknowledge receipt within 48 hours and provide a detailed response within 72 hours.

## Security Best Practices

When using Monstra:

### Memory Management
- Always use provided memory limits in `MemoryCache`
- Monitor cache statistics for unusual patterns

### Task Execution  
- Validate input data before task execution
- Use appropriate timeout values
- Implement proper error handling

### Concurrency
- Follow documented concurrency limits
- Use provided synchronization mechanisms

## Security Features

- Automatic memory limit enforcement
- Thread-safe execution with proper synchronization
- Timeout protection for async operations
- Input validation for all cache operations
