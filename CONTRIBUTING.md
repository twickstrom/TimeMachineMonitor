# Contributing to TimeMachineMonitor

First off, thank you for considering contributing to TimeMachineMonitor! It's people like you that make TimeMachineMonitor such a great tool.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps which reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed after following the steps
* Explain which behavior you expected to see instead and why
* Include screenshots if relevant
* Include your macOS version and Time Machine configuration

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Describe the current behavior and explain which behavior you expected to see instead
* Explain why this enhancement would be useful

### Pull Requests

* Fill in the required template
* Do not include issue numbers in the PR title
* Follow the bash/Python style guides
* Include thoughtfully-worded, well-structured tests
* Document new code
* End all files with a newline

## Development Setup

1. Fork the repo
2. Clone your fork
3. Create a branch for your feature/fix
4. Make your changes
5. Test thoroughly on macOS 14+
6. Commit with clear messages
7. Push to your fork
8. Create a Pull Request

## Style Guides

### Bash Style Guide

* Use 4 spaces for indentation
* Use `snake_case` for function and variable names
* Use `UPPER_CASE` for constants and exported variables
* Always quote variables unless you have a specific reason not to
* Use `[[ ]]` instead of `[ ]` for conditionals
* Add comments for complex logic

### Python Style Guide

* Follow PEP 8
* Use type hints for all functions
* Document all classes and functions
* Keep line length under 100 characters

## Testing

* Test on multiple macOS versions if possible (14.0+)
* Test with both initial and incremental backups
* Test with various Time Machine destinations
* Verify no memory leaks during long-running sessions

## Questions?

Feel free to open an issue with your question or contact the maintainer.

Thank you for contributing!
