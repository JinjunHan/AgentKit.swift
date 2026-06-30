# Contributing to AgentKit.swift

First off, thank you for considering contributing to AgentKit! It's people like you that make open source great.

## Development Workflow

1. **Fork & Clone**: Fork the repository and clone it locally.
2. **Swift 6 Concurrency**: This project strictly uses Swift 6 concurrency (`Sendable`, `actor`). Ensure all your code compiles without warnings.
3. **No Third-Party Dependencies**: The core `AgentKit` target must remain free of third-party dependencies. Use native Apple frameworks only.
4. **Testing**: Add unit tests for any new functionality in `Tests/AgentKitTests`. Run `swift test` before submitting.
5. **Documentation**: All public APIs must have `///` SwiftDoc comments.

## Pull Requests

1. Create a branch for your feature (`feature/your-feature-name`).
2. Include a summary of your changes in the PR description.
3. Ensure CI passes.

We look forward to reviewing your pull requests!
