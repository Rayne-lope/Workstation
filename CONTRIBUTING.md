# Contributing to Workstation

Thanks for your interest in contributing! This guide covers everything you need to get started.

## Prerequisites

- macOS 15.0+
- Xcode 16+ (for building the app)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [Beads CLI (`bd`)](https://github.com/gastownhall/beads) — for issue tracking

## Building

```bash
# Generate Xcode project
xcodegen generate

# Build (Debug)
./run-app build

# Build and launch
./run-app run

# Build Release (installs to /Applications)
./run-app release
```

## Running Tests

```bash
swift test
```

All 246+ tests must pass before submitting a PR.

## Contributing Code

1. Fork the repo and create a branch from `master`
2. Make your changes
3. Ensure `swift test` passes
4. Open a PR against `master` with a clear description of the change

## Issue Tracking

This project uses [Beads (`bd`)](https://github.com/gastownhall/beads) for issue tracking, not GitHub Issues. If you want to report a bug or request a feature, open a GitHub Issue and we'll triage it into Beads.

## Code Style

- Swift 6 concurrency (`async/await`, `Task`) — no Combine
- `@Observable` (Swift Observation) — not `ObservableObject`
- New files in `App/` require running `xcodegen generate` to regenerate the `.xcodeproj`
- No comments unless the *why* is non-obvious
