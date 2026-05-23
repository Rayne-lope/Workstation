# AGENTS.md

## Repo Goal

This repository is the backend-first macOS Beads Kanban app.

The current shape is:
- Phase 0: Beads CLI contract spike
- Phase 1: project folder and workspace detection
- Phase 2: shell command runner, timeout/cancellation, and debug history

## Working Rules

- Use `bd` for Beads issue changes.
- Do not edit `.beads/` files directly.
- Keep app behavior tolerant: missing optional fields or warnings should not crash the UI.
- Prefer small, testable changes that preserve the existing contract.

## Common Commands

```bash
swift test
xcodebuild -project Workstation.xcodeproj -scheme Workstation -configuration Debug build
xcodebuild -project Workstation.xcodeproj -scheme Workstation -configuration Debug -derivedDataPath .derivedData build
open .derivedData/Build/Products/Debug/Workstation.app
```

## Notes For Agents

- Root workspace detection should respect `.git` and `.beads`.
- `AGENTS.md` is a warning-level workspace marker, not a hard requirement.
- Phase 2 command history is useful for debugging failures, so preserve metadata when adding new commands.
- Keep any new shell execution code timeout-aware and cancellation-aware.

## Worktree Testing

- Run tests from the worktree you are actively changing, not from the main tree.
- Treat each worktree as the source of truth for that task's `swift test` and `xcodebuild` runs.
- Keep the main tree as the coordination view only, then review and merge after the worktree passes checks.
- Use the same validation commands in every worktree:
  ```bash
  swift test
  xcodebuild -project Workstation.xcodeproj -scheme Workstation -configuration Debug build
  ```
- If you are unsure which checkout you are in, run `pwd` or `git worktree list` before testing.

## Recurring Tasks

This project supports **recurring tasks** — issues that repeat on a cadence with run history. They are **not** plain labels: each recurring issue has a sidecar `.beads/recurring/<issue-id>.json` containing `isRecurring`, `cadenceDays`, and a `history[]` array of run entries.

- **Lifecycle:** recurring issues are **not** closed via `bd close`. Each run ends with "Mark Run Complete" in the app (appends history, resets status to `open`).
- **Detect:** sidecar file exists + `"isRecurring": true`.
- **Create:** `bd create ...` normally, then write the sidecar JSON. Cadence defaults: refactor/audit = 30-90 days, housekeeping = 7 days, quarterly = 90.
- **Full spec:** see `GUIDE.md` section 7.5 (model fields, derived counters, badge UI, filter chip).

If a user describes a task as "recurring", "berulang", "rutin", "tiap N hari" — create it as a recurring task, not a one-shot.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:7510c1e2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds. However, if a git push command fails due to permission auto-rejection by the IDE/terminal sandbox environment (e.g. `permission requested: bash (git push...); auto-rejecting` or user permission limits), **DO NOT CRASH, RETRY IN AN INFINITE LOOP, OR HALT IMPLEMENTATION**. Instead, treat the local changes as completed successfully, explain to the user that pushing was blocked by sandbox permissions, and instruct the user to run `git push` manually in their terminal.
- NEVER stop before attempting a push - that leaves work stranded locally.
- NEVER say "ready to push when you are" - YOU must attempt the push first.
- If push fails due to standard merge conflicts or network errors, resolve and retry until it succeeds.
<!-- END BEADS INTEGRATION -->

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.
<!-- END BEADS CODEX SETUP -->
