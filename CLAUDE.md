# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

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
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->


## Recurring Tasks (PENTING — sering kelewat)

Proyek ini punya **recurring tasks** — issue yang berulang berkala dengan history run, cadence, dan overdue tracking. **Bukan** label biasa: pakai sidecar JSON di `.beads/recurring/<id>.json`.

**Tanda issue itu recurring:** sidecar file ada + `isRecurring: true`.

**Lifecycle berbeda dari one-shot:**
- One-shot: `open` → `in_progress` → `review` → `closed`.
- Recurring: `open` → `in_progress` → **"Mark Run Complete"** (append history, reset ke `open`) → ulang. **Jangan `bd close`** recurring task.

**Cara buat recurring task** (kalau user minta task "berulang" / "rutin" / "tiap N hari"):
1. `bd create ...` issue biasa.
2. Tulis `.beads/recurring/<issue-id>.json`:
   ```json
   { "cadenceDays" : 30, "history" : [], "isRecurring" : true, "issueID" : "Workstation-xxx" }
   ```
3. Atau via UI: buka issue di app, scroll panel detail ke section "Recurring Task", toggle on, pilih cadence chip.

**Cadence default:** refactoring/audit = 30-90 hari, housekeeping = 7 hari, quarterly = 90.

Detail lengkap (model, derived fields, badge UI, filter "Recurring only") ada di **`GUIDE.md` section 7.5**.

## Build & Test

```bash
swift test                                          # CLI/logic tests (246+ harus hijau)
./run-app build                                     # macOS app bundle
./run-app run                                       # launch app
```

## Architecture Overview

- `App/` — SwiftUI views (macOS native, Craftboard dark theme, accent gold).
- `Sources/BeadsContract/` — pure Swift types (BeadIssue, RecurringMetadata, dst). Tidak depend ke UI/Foundation-only.
- `Sources/BeadsWorkspace/` — `@MainActor @Observable` stores (`IssueStore`, `RecurringStore`, `AgentRunTranscriptStore`). Wrap shell calls ke `bd` CLI + file I/O.
- `Tests/` — Swift Testing framework (`@Test`, `@Suite`, `#expect`).
- `.beads/recurring/` — sidecar JSON per recurring issue.
- `project.yml` → `xcodegen generate` → `BeadsKanbanApp.xcodeproj`. Tambah file di `App/` perlu regenerasi pbxproj.

## Conventions & Patterns

- Pakai `@Observable` (Swift 6 Observation), bukan `ObservableObject`.
- Async via Swift Concurrency (`Task`, `async/await`), bukan Combine.
- Backwards-compat decode: pakai `decodeIfPresent(...) ?? default` untuk field baru di tipe Codable yang sudah ke-persist.
- File baru di `App/` → jalanin `xcodegen generate` sebelum `./run-app build`.
