# PRD v2 — Beads Kanban Feature Roadmap

> Status: **draft brainstorm**, belum di-commit ke implementasi.
> Author: Rayne · Date: 2026-05-19 · Reviewed by: —

## Konteks

v1 (backend-first) sudah landed: app SwiftUI native yang wrap `bd` CLI,
dengan kanban view, list view, dependency management, auto-reload, dan
assignee branding (Claude/Codex/Other/initials). 170 test hijau,
xcodebuild SUCCEEDED.

Sekarang app **berfungsi** — tapi masih banyak operasi yang harus balik
ke CLI atau memaksa user buka detail panel. PRD ini memetakan
pengembangan **fase 2** untuk membuat workflow harian benar-benar
end-to-end di dalam app.

## Prinsip Pengembangan

1. **Setiap fitur harus mengurangi context-switch ke CLI.** Kalau fitur
   cuma "duplikat command line", skip.
2. **Konsisten dengan Craftboard style guide** — dark, gold accent,
   compact, minimal motion.
3. **Backend-first tetap berlaku** — service + store + test sebelum UI.
4. **Tidak melanggar convention bd** — file `.beads/issues.jsonl` tetap
   passive export; semua mutation lewat `bd` command.

---

## Tema 1 — Interaksi Cepat di Board

Tujuan: action paling sering (close, claim, ubah priority) bisa di
2 klik atau lebih sedikit.

### 1.1 Drag-and-Drop Antar Kolom ⭐
Drag card dari `Ready` → `In Progress` otomatis trigger `bd update
--claim`. Drop ke `Review` otomatis `--add-label human`. Drop ke `Done`
buka close sheet.

- **Value**: tinggi. Saat ini transisi status tersembunyi di menu.
- **Effort**: medium. `onDrag` + `dropDestination` di SwiftUI sudah
  mature.
- **Risk**: pastikan drop tidak conflict dengan select-to-open-detail.

### 1.2 Inline Quick-Edit Title
Double-click title di card → input field muncul → Enter commit
(`bd update --title="..."`).

- **Value**: medium. Typo rename sering.
- **Effort**: kecil.

### 1.3 Right-Click Context Menu
Klik kanan card → menu: Claim, Flag review, Close, Copy prompt,
Add blocker, Change priority. Saat ini menu hanya di detail view.

- **Value**: tinggi. Power-user feature.
- **Effort**: kecil. `.contextMenu` SwiftUI.

### 1.4 Keyboard Navigation
`J`/`K` pindah selection antar card, `Space` buka detail, `Cmd+N`
create, `X` close current. Mirror Linear/Github style.

- **Value**: tinggi untuk power user.
- **Effort**: medium. Perlu focus state management.

---

## Tema 2 — Visibility & Filter

Tujuan: dengan 50+ issue, harus bisa fokus ke subset yang relevan tanpa
scrolling.

### 2.1 Filter Bar di Header ⭐
Filter chip-row: priority, type, assignee, label. Multiple aktif =
intersection. State persist per workspace.

- **Value**: tinggi. Saat ini board penuh sesak kalau >20 issue.
- **Effort**: medium. Filter logic + UI chips.

### 2.2 Global Search (Cmd+F)
Spotlight-style overlay: search by id/title/description across semua
issue (termasuk closed). Click hasil → langsung scroll + select.

- **Value**: tinggi.
- **Effort**: medium. Pakai `bd search` atau filter in-memory.

### 2.3 Stale Issue Indicator
Card dengan `updated_at > 7 hari` dapet dot warning kecil. Bisa hide
via preference.

- **Value**: medium. Cegah issue terlantar.
- **Effort**: kecil. Sudah ada `lastReloadedAt`, tinggal compare.

### 2.4 Dependency Graph View
Tab baru di samping List/Kanban: visualisasi graph dependency
(arrow `A → B` artinya A blocks B). Pakai `bd dep tree` atau compute
in-memory.

- **Value**: medium. Berguna untuk epic dengan banyak sub-task.
- **Effort**: tinggi. Layout graph non-trivial.

---

## Tema 3 — Workflow Otomatisasi & Agent Loop

Tujuan: app jadi command center untuk run agent, bukan cuma viewer.

### 3.1 "Run Agent" Button ⭐
Tombol di detail view: pilih agent profile (Claude Executor / Codex /
dll.) → app generate prompt + open Terminal dengan command pre-filled.
Sebagian sudah ada (`copyAgentCommand`), tapi belum one-shot.

- **Value**: tinggi. Closes the loop "saya lihat issue → langsung kerjain".
- **Effort**: medium. `TerminalLauncher` sudah ada, tinggal extend.

### 3.2 Watch Mode untuk Hand-off
Setelah trigger agent, app monitor file watcher → notif macOS saat
issue masuk Review column (`label=human` ditambah). User tahu agent
selesai tanpa pantengin terminal.

- **Value**: tinggi untuk async workflow.
- **Effort**: medium. UNUserNotificationCenter + state diff.

### 3.3 Pre-flight Panel
Sebelum bisa Close issue, panel cek: `bd lint`, `bd stale`,
`bd orphans`, tests pass. Show ✓/✗ per check.

- **Value**: medium. Cegah close prematur.
- **Effort**: medium.

### 3.4 Issue Template per Type
Saat create dengan type=bug, description pre-filled dengan template
"Repro / Expected / Actual / Env". Type=feature template
"Why / What / Out of scope" (sesuai convention GUIDE.md).

- **Value**: medium. Konsistensi description.
- **Effort**: kecil.

---

## Tema 4 — Visibility Antar-Project & Statistik

Tujuan: kalau punya multiple project pakai bd, app jadi dashboard
umum.

### 4.1 Multi-Workspace Tab
Tab bar (atau sidebar list) — switch antar project tanpa close window.
State per workspace cached.

- **Value**: tinggi kalau punya >1 project.
- **Effort**: medium-tinggi. State management non-trivial.

### 4.2 Stats Dashboard
Tab "Stats": chart burndown 30 hari, velocity per assignee, blocked
time distribution. Data dari `bd stats` + computed.

- **Value**: medium. Lebih ke retrospective tool.
- **Effort**: tinggi (chart). Bisa pakai Swift Charts.

### 4.3 Memory Browser
UI untuk `bd remember` — search & browse memories cross-session,
dengan tagging. Saat ini cuma via CLI.

- **Value**: medium. Memories sering lost karena lupa search.
- **Effort**: medium.

---

## Tema 5 — Quality of Life

### 5.1 Markdown Rendering di Description
Render description card/detail sebagai markdown (heading, list, code
block). Saat ini plain text.

- **Value**: tinggi. Description sering punya struktur.
- **Effort**: medium. Pakai `AttributedString` atau library `swift-markdown-ui`.

### 5.2 Color-blind Friendly Mode
Replace warna-only signals (priority dot, status badge) dengan
shape+color combo.

- **Value**: medium. Accessibility.
- **Effort**: kecil.

### 5.3 Onboarding Tour (First Launch)
Walkthrough 4-step: pilih workspace → buat issue pertama → klik claim
→ flag review.

- **Value**: kecil-medium. Sekali pakai.
- **Effort**: medium.

### 5.4 Compact / Comfortable Density Toggle
Card padding adjustable. Saat ini fixed compact.

- **Value**: kecil.
- **Effort**: kecil.

---

## Rekomendasi Slice MVP v2

Kalau cuma bisa pilih 5 fitur untuk fase berikutnya, ambil yang
ditandai ⭐ di atas:

| Prioritas | Fitur | Estimasi |
|-----------|-------|----------|
| P0 | 1.1 Drag-and-Drop antar kolom | M |
| P0 | 1.3 Right-click context menu | S |
| P1 | 2.1 Filter bar di header | M |
| P1 | 3.1 "Run Agent" button | M |
| P2 | 5.1 Markdown rendering | M |

Justifikasi: keempat fitur ini bersama-sama menutup *gap* terbesar
yang masih bikin user balik ke CLI atau open detail panel. Drag-drop
+ context menu menyentuh setiap transisi status. Filter bar menyelamatkan
saat board penuh. Run Agent menutup loop view → execute → review.
Markdown rendering bikin description finally readable.

## Yang Sengaja Tidak Masuk Roadmap

- **iOS app** — bd CLI butuh shell, tidak portable ke iOS sandbox.
- **Realtime collaboration** — bd sync model = git-based, bukan
  real-time. Out of scope arsitektur.
- **Issue komentar threading** — bd cuma punya `--notes` flat. Kalau
  butuh, pakai GitHub/Linear.
- **Plugin / extension system** — premature, app belum punya user
  base yang butuh ekstensibilitas.
- **AI auto-triage** — auto-assign agent berdasar label/title.
  Menarik tapi failure mode-nya jelek (agent ngerjain hal yang user
  belum approve).

## Open Questions

1. **Drag-and-drop**: pakai gesture native macOS atau custom dengan
   `.onDrag`/`.dropDestination`? Native akrab tapi lebih kaku.
2. **Multi-workspace**: tab di dalam satu window, atau spawn window
   baru per workspace? Tab lebih hemat resource.
3. **Filter persist**: per-workspace di preferences, atau session-only
   (reset on launch)? Saya cenderung per-workspace.
4. **Run Agent button**: pakai Terminal external, atau embed terminal
   view di app? External lebih aman (sandboxing); embed lebih seamless.

## Verifikasi (saat implementasi nanti)

Tiap fitur slice MVP harus:

1. Punya bd issue dengan acceptance criteria (`bd create --validate`).
2. Service/store layer di-test (`swift test`, baseline 170+).
3. xcodebuild SUCCEEDED.
4. Manual smoke pass (golden path + 1 edge case minimum).
5. Update GUIDE.md kalau ada perubahan convention/keyboard shortcut.
