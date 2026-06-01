# Workstation

> Native macOS kanban board for the [Beads](https://github.com/gastownhall/beads) (`bd`) issue tracker.

Workstation is a SwiftUI desktop app that wraps the `bd` CLI into a visual, keyboard-driven interface — dark Craftboard theme, gold accents, collapsible sidebar, and a live terminal drawer so you never leave the app to run a command.

---

## Features

- **Kanban board** — drag issues across `open → in_progress → review → closed` columns
- **Issue detail drawer** — dependency graph, agent run timeline, blocker management
- **Command palette** `⌘⇧K` — jump to any issue or action without touching the mouse
- **Quick capture** `⌘⇧N` — create an issue in two keystrokes
- **Live terminal** — run `bd` commands inline, output streams in real time
- **Recurring tasks** — cadence-aware tasks with run history and overdue badges
- **Workspace detection** — opens any folder with `.git` + `.beads`, validates env on launch
- **macOS Widget** — glanceable issue counts from the desktop

---

## Download

Grab the latest `.dmg` from [Releases](https://github.com/Rayne-lope/Workstation/releases/latest).

> **First launch:** right-click → **Open** to bypass Gatekeeper (app is ad-hoc signed, not notarized).

---

## Requirements

- macOS 15.0+
- [Beads CLI (`bd`)](https://github.com/gastownhall/beads) installed and a `.beads` workspace initialized

---

## Build from Source

```bash
# 1. Install XcodeGen
brew install xcodegen

# 2. Generate the Xcode project
xcodegen generate

# 3. Build and launch (Debug)
./run-app

# 4. Or build Release + install to /Applications
./run-app release
```

### Run tests

```bash
swift test
```

---

## Project Structure

```
App/                  # SwiftUI views (58 files)
Sources/
  BeadsContract/      # Pure Swift models — no I/O, no UI
  BeadsWorkspace/     # Stores, shell runner, workspace validation
Tests/
  BeadsContractTests/
  BeadsWorkspaceTests/
project.yml           # XcodeGen config (source of truth for .xcodeproj)
Package.swift         # SPM manifest (used by swift test)
run-app               # Build/run utility script
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## AI Agent Integration

This repo is set up for AI-assisted development:

- `CLAUDE.md` — Claude Code project config
- `AGENTS.md` — agent coordination rules and workflow
- `codex.md` — Codex agent briefing

Issue tracking uses [Beads](https://github.com/gastownhall/beads), not GitHub Issues.
