# Codex Agent Briefing — Beads Kanban

Halo Codex. File ini adalah konteks wajib sebelum kamu mulai kerja di repo ini.
Baca sekali, ikuti seterusnya. User komunikasi pakai Bahasa Indonesia, santai
tapi padat — jawaban panjang tanpa nilai akan dicabut.

## 1. Apa Project Ini

Native macOS SwiftUI app yang membungkus CLI `bd` (Beads) untuk issue tracking
lokal. Spec lengkap ada di `prd_beads_kanban_backend_first.md` — itu source of
truth untuk semua phase backend. Jangan menyimpang dari PRD tanpa diskusi.

## 2. Struktur Repo

```
Sources/
  BeadsContract/      # Pure models, Codable, no I/O (cross-platform)
  BeadsWorkspace/     # Services + stores (UserDefaults, shell, validation)
App/                  # Xcode app target (SwiftUI views + view models)
Tests/
  BeadsContractTests/
  BeadsWorkspaceTests/
Fixtures/             # JSON fixtures untuk decoder tests
Package.swift         # SPM manifest (test runner)
project.yml           # xcodegen config (App target)
```

Kontrak pemisahan ketat:
- `BeadsContract` tidak boleh import AppKit/SwiftUI/UserDefaults.
- `BeadsWorkspace` boleh Foundation + Combine. Tidak ada SwiftUI di sini.
- `App/` boleh apapun. Cuma App yang tahu tentang SwiftUI/AppKit.

## 3. Build & Test

```bash
swift test                    # SPM unit tests — paling cepat, gunakan ini dulu
swift build                   # Verifikasi compile contract+workspace
xcodegen generate             # Refresh Workstation.xcodeproj setelah edit project.yml
xcodebuild -scheme Workstation -destination 'platform=macOS' build
```

`swift test` adalah authority untuk koreksi kode. Jangan terdistraksi oleh
diagnostics stale di Xcode (SourceKit sering ketinggalan beberapa detik).

## 4. Beads Workflow — WAJIB

Project ini pakai `bd` untuk SEMUA tracking. Aturan keras:

- **JANGAN** pakai TodoWrite, TaskCreate, atau markdown TODO list.
- **JANGAN** pakai `bd edit` (buka $EDITOR, blocking).
- **JANGAN** asumsi field; jalankan `bd prime` untuk command reference penuh.
- Sebelum nulis kode, `bd ready` lalu `bd update <id> --claim`.
- Setelah selesai, `bd close <id> --reason="..."`. Wajib reason singkat.

Quick reference:
```bash
bd ready                       # Issue siap dikerjakan
bd show <id>                   # Detail issue
bd update <id> --claim         # Klaim
bd close <id1> <id2> ...       # Tutup (bisa multiple)
bd remember "insight"          # Memori persisten lintas sesi
bd memories <keyword>          # Cari memori
```

Priority pakai angka 0-4 atau P0-P4 (0=critical, 2=medium, 4=backlog). JANGAN
pakai string "high"/"medium"/"low" — itu invalid.

## 5. Konvensi Kode

- **Tanpa komentar** kecuali WHY-nya non-obvious (workaround bug, invariant
  tersembunyi). Identifier yang baik mengexplain WHAT.
- **Tanpa abstraksi prematur**. 3 baris mirip lebih baik dari helper baru.
- **Tanpa backward-compat shim** kecuali ada user data di produksi (untuk
  Codable persisted profile, ya — pakai `decodeIfPresent` + default).
- **Tanpa error handling defensif** untuk skenario yang tidak bisa terjadi.
  Validasi cuma di boundary (user input, external CLI output).
- **Tanpa fitur di luar scope task**. Bug fix tidak butuh cleanup di
  sekitarnya. Refactor menunggu task refactor sendiri.
- Test framework: **Swift Testing** (`@Test`, `#expect`, `@Suite`). Bukan XCTest.
- Untuk `@MainActor` types, suite-nya juga `@MainActor`.

## 6. Pola Penting

- **Persisted state** (UserDefaults): kunci pakai prefix `com.beads.app.*`.
  Migrasi dari legacy key one-time di init store, lihat pola di
  `AgentProfileStore.swift` dan `PreferencesStore.swift`.
- **Custom Codable init** untuk model yang persisted: pakai `decodeIfPresent`
  per field dengan default fallback. Contoh di `AgentProfile.swift` dan
  `AppPreferences.swift`.
- **Shell commands**: lewat `ShellCommandRunner` (protocol-based). Test pakai
  `StubCommandRunner` di `Tests/BeadsWorkspaceTests/Support/`.
- **Prompt + command generation**: `PromptGenerator` (BeadsContract). Profile
  punya `commandArgsTemplate` dengan `{{prompt}}` placeholder.

## 7. Session-Close Protocol

Sebelum bilang "selesai":

1. `bd close <id> --reason="..."` untuk semua issue yang beres.
2. Jalankan `swift test` — semua hijau.
3. Jalankan `swift build` (atau xcodebuild kalau menyentuh App/).
4. Tidak ada yang stranded — kalau ada follow-up, `bd create` issue baru.

Catatan: project ini **local-only**, tidak ada git remote. Tidak perlu push.

## 8. Komunikasi dengan User

- Bahasa Indonesia. Santai. Jangan pakai "Tentu!", "Dengan senang hati", atau
  closer "Semoga membantu!".
- Output pendek default. Panjang hanya kalau ada nilai per kalimat.
- Konfirmasi sebelum destructive action (rm, reset --hard, force push).
- Tanya 1 pertanyaan fokus kalau ambigu, jangan daftar panjang.

## 9. PRD sebagai Source of Truth

Phase backend (Phase 0–11) didefinisikan di `prd_beads_kanban_backend_first.md`
§10. Jangan menamai task "Phase 12" — section §12+ adalah top-level (Future
Work, Open Questions), bukan phase. Kalau mau scope-add di luar PRD, sebut
eksplisit di issue title.
