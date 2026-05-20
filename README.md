# Beads Kanban Spike

Phase 0 contract spike for a backend-first macOS Beads Kanban app.

## What is here

- `BeadIssue` model with tolerant optional fields
- JSON decoder helpers for `bd list`, `bd ready`, and `bd show`
- sample fixtures under `Fixtures/`
- tests that validate the contract
- a macOS SwiftUI app target in `BeadsKanbanApp.xcodeproj`

## Notes

- This environment does not currently have `bd` installed, so the fixtures are representative contract samples rather than captured live output.
- Once `bd` is available, replace the fixture contents with real command output from a Beads workspace.
- The Xcode project is generated from `project.yml` with `xcodegen`.
- To build and open the app with one short command, run `./run-app`.
- To build only, run `./run-app build`.
