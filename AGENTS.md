# AGENTS.md — Workstation

> Baca file ini di awal setiap sesi. Ini adalah sumber kebenaran untuk agent yang bekerja di repo ini.

---

## 1. Apa Ini

macOS native app (SwiftUI, Swift 6) yang menjadi antarmuka visual untuk **beads** issue tracker.
Stack: `App/` (SwiftUI views) · `Sources/BeadsWorkspace/` (stores, logic) · `Sources/BeadsContract/` (pure types) · `Tests/`.

---

## 2. Mulai Sesi

```bash
bd prime                  # refresh beads context (WAJIB di awal sesi)
bd list --status=in_progress   # cek ada kerjaan yang nyangkut
bd ready                  # list issue siap dikerjain
```

---

## 3. Build & Test

```bash
swift test                # logic tests — harus hijau penuh (246+)
./run-app build           # compile macOS app bundle
./run-app run             # launch app

# Kalau tambah file baru di App/:
xcodegen generate         # regenerate .xcodeproj dulu
./run-app build
```

---

## 4. Beads — Command Reference Lengkap

### 4.1 Cari & Lihat

```bash
bd prime                           # load/refresh full context
bd ready                           # issue siap dikerjain (tidak ada blocker)
bd list --status=open              # semua open
bd list --status=in_progress       # yang sedang dikerjain
bd list --status=review            # nunggu review manusia
bd blocked                         # yang ke-block dependency
bd show <id>                       # detail lengkap: desc, notes, deps
bd search "<keyword>"              # cari by teks
bd stats                           # ringkasan open/closed/blocked
```

### 4.2 Buat & Ubah

```bash
bd create \
  --title="Judul singkat" \
  --description="Why: ...\nWhat:\n- ...\nOut of scope:\n- ..." \
  --type=task|bug|feature|epic|chore \
  --priority=0|1|2|3|4

bd update <id> --claim                        # claim + set in_progress
bd update <id> --claim --assignee=claude      # claim + set assignee
bd update <id> --assignee=claude              # set assignee saja
bd update <id> --add-label human              # flag untuk review manusia
bd update <id> --remove-label human           # un-flag
bd update <id> --status=open                  # rollback ke open
bd update <id> --notes="catatan progress..."  # log progress / hand-off
bd update <id> --title="..." --description="..." --acceptance="..."
bd close <id> --reason="..."                  # tutup issue (lihat §5!)
bd close <id1> <id2> <id3>                   # tutup banyak sekaligus
```

> ⚠️ **JANGAN `bd edit`** — itu buka vim/nano dan nge-block agent.

### 4.3 Dependency

```bash
bd dep add <issue> <depends-on>   # <issue> TIDAK bisa dimulai sebelum <depends-on> selesai
bd dep remove <issue> <depends-on>
bd blocked                        # lihat semua issue yang ke-block
bd show <id>                      # termasuk "blocked by" dan "blocks"
```

Beads auto-detect cycle — kalau A blocks B dan B blocks A, `dep add` akan di-reject.

### 4.4 Memori & Knowledge

```bash
bd remember "insight atau keputusan penting"   # simpan cross-session
bd memories <keyword>                           # cari catatan
```

Pakai ini untuk konvensi, gotcha, keputusan arsitektur. **Jangan bikin MEMORY.md.**

### 4.5 Health & Hygiene

```bash
bd doctor                      # cek sync, hooks, masalah umum
bd doctor --check=conventions  # drift dari konvensi
bd stale                       # issue tidak ada aktivitas lama
bd orphans                     # issue dengan dep yang broken
bd preflight                   # pre-PR checks (lint + stale + orphans)
bd human <id>                  # flag untuk keputusan manusia
bd defer <id> --until="2026-09-01"  # tunda ke tanggal tertentu
```

### 4.6 Assignee Convention

| Assignee | Icon | Kapan |
|----------|------|-------|
| `claude` | ✦ gold sparkles | Claude / Claude Code |
| `codex` | `<>` biru | OpenAI Codex |
| `other` / `gemini` / `gpt` / `bot` | ⬡ ungu | AI lain |
| `rayne`, nama orang, dll. | initial | Manusia |

Token di-match case-insensitive substring. `claude-code`, `anthropic` → claude. `agent`, `llm` → other.

---

## 5. Completion Protocol (PENTING)

**Cek jenis file yang diubah, lalu pilih path:**

```
Menyentuh file UI / visual?
  App/*.swift, *.xcassets, *View.swift, *Sheet.swift, dll.
         │
        YES → flag review (manusia harus lihat):
               bd update <id> --add-label human \
                 --notes="<ringkasan Indonesia: apa yang dikerjain, hasil test>"
               ─── STOP. Tunggu manusia. ───
         │
        NO → hanya logic/data/tests?
             Sources/*, Tests/*, *.swift (non-UI)
             + build SUKSES + swift test HIJAU
                    │
                   YES → self-close boleh:
                          bd close <id> --reason="<ringkasan Indonesia: apa yang berubah, N/N tests>"
```

**Contoh notes yang benar:**
```bash
# Review path:
bd update Workstation-xyz --add-label human \
  --notes="Tambah spinner di pojok kanan atas IssueCardView. Trigger: status==in_progress.
Build sukses, swift test 246/246 hijau. Perlu visual check di app."

# Self-close path:
bd close Workstation-abc \
  --reason="Implementasi GoalParser.parse() + toggle(). Pure logic, no UI.
swift test 252/252 hijau, xcodebuild SUCCEEDED."
```

---

## 6. Arsitektur Singkat

```
App/                    SwiftUI views, sheets, modals
  IssueCardView.swift   Kartu issue di kanban
  KanbanBoardView.swift Board utama + drag-drop
  IssueListView.swift   List view alternatif
  WorkstationTheme.swift  Color tokens & font helpers

Sources/BeadsContract/  Pure Swift types (no UI deps)
  BeadIssue.swift       Model utama
  PromptGenerator.swift Generator prompt untuk agent
  GoalParser.swift      Parser acceptance criteria checkbox

Sources/BeadsWorkspace/ @MainActor @Observable stores
  IssueStore.swift      CRUD + filter + dependency graph
  EpicStore.swift       Epic ↔ child linking
  RecurringStore.swift  Recurring task sidecar mgmt
  SoundscapeManager.swift  Audio feedback (AVFoundation)

Tests/                  Swift Testing (@Test, @Suite, #expect)
.beads/recurring/       Sidecar JSON per recurring issue
project.yml             xcodegen config → Workstation.xcodeproj
```

**File baru di `App/` → wajib `xcodegen generate` sebelum build.**

---

## 7. Konvensi Kode

- **Observable**: pakai `@Observable` (Swift 6), bukan `ObservableObject`
- **Async**: `Task` + `async/await`, bukan Combine
- **Decode safe**: `decodeIfPresent(...) ?? default` untuk field baru di Codable
- **Colors**: selalu pakai `WorkstationTheme.*` (adaptive dark/light). Jangan hardcode `Color.black`
- **Font**: `WorkstationTheme.Fonts.display()` / `.body()`, jangan `.system(size:)`
- **Radius**: `WorkstationTheme.Radius.large / .medium / .small`

---

## 8. Recurring Tasks

Issue berulang punya sidecar di `.beads/recurring/<id>.json`. **Jangan `bd close`** — lifecycle-nya beda:

```
open → in_progress → "Mark Run Complete" → open (ulang)
```

Buat: `bd create ...` + tulis sidecar. Detail lengkap: **GUIDE.md §7.5**.

---

## 9. Common Pitfalls

| Salah | Benar |
|-------|-------|
| `bd close` setelah coding UI | `bd update --add-label human` |
| `bd edit <id>` | `bd update <id> --field=value` |
| `./run-app build` setelah tambah file baru di `App/` | `xcodegen generate` dulu |
| Hardcode `Color.black` / `.white` | `WorkstationTheme.background` / `textPrimary` |
| `ObservableObject` + `@Published` | `@Observable` + plain `var` |
| Edit `.beads/issues.jsonl` langsung | Selalu via `bd` command |
| Bikin MEMORY.md / TODO.md | `bd remember` / `bd create` |

---

## 10. Referensi

- **GUIDE.md** — workflow lengkap + flow contoh + recovery
- **CLAUDE.md** — instruksi session management
- **references/workstations_style_guide.md** — visual design system
- **references/workstation_ui_ux.md** — UX patterns
