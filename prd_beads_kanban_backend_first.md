# PRD — Backend-First macOS Beads Kanban App

## 1. Ringkasan Produk

Aplikasi ini adalah **native macOS app berbasis Swift** untuk mengelola issue/task dari **Beads (`bd`)** secara visual dan praktis. Fokus versi awal bukan pada UI yang cantik, melainkan pada fondasi backend lokal yang stabil: memilih folder project, mendeteksi Beads workspace, menjalankan command `bd`, membaca JSON, memetakan issue ke state Kanban, dan menyediakan aksi dasar seperti create, claim, update, close, reopen, serta copy prompt untuk Claude/Codex.

UI di fase awal boleh sederhana/jelek, selama seluruh alur backend berfungsi benar, aman, dan mudah dites.

---

## 2. Tujuan Utama

### 2.1 Tujuan Produk

Membangun aplikasi macOS lokal yang dapat:

1. Membuka folder project lokal yang memakai Beads.
2. Membaca issue dari Beads lewat `bd` CLI.
3. Menampilkan issue dalam struktur Kanban dasar.
4. Menjalankan operasi issue dasar lewat `bd` CLI.
5. Menjadi control panel untuk workflow AI Agent:
   - Human membuat ide/task.
   - Codex memperjelas spesifikasi.
   - Claude Code mengeksekusi issue.
   - Beads menjadi source of truth.

### 2.2 Tujuan Teknis

Aplikasi harus memiliki backend layer yang:

1. Tidak langsung menulis ke file internal `.beads`.
2. Semua operasi tulis dilakukan lewat `bd` CLI.
3. Semua command dijalankan di root folder project yang benar.
4. Output JSON dari `bd` diparse menjadi model Swift yang stabil.
5. Error dari CLI ditangkap dan ditampilkan dengan jelas.
6. Siap dikembangkan ke UI yang lebih polished di fase berikutnya.

---

## 3. Non-Goals untuk Versi Awal

Hal-hal berikut **tidak dikerjakan dulu**:

1. UI sekelas Linear/Jira.
2. Multi-user collaboration real-time.
3. Cloud sync custom.
4. Login/account system.
5. Menulis langsung ke database/file `.beads`.
6. Membuat issue tracker baru selain Beads.
7. Embed Claude/Codex secara langsung di app.
8. AI agent berjalan otomatis penuh tanpa kontrol user.
9. Mobile/iOS app.
10. Marketplace extension/plugin.

---

## 4. Target User

### 4.1 Primary User

Developer solo atau small-team developer yang:

- memakai macOS,
- coding lokal di folder project,
- ingin issue tracker local-first,
- ingin workflow dengan AI coding agent,
- ingin melihat task Beads dalam bentuk Kanban.

### 4.2 Secondary User

Project manager teknis yang ingin:

- menulis task/spec,
- melihat progress issue,
- memicu workflow Codex/Claude lewat prompt,
- tetap menjaga semua task tersimpan di repository lokal.

---

## 5. Prinsip Produk

1. **Backend dulu, UI belakangan.**
   Kalau command, parsing, state, dan mutation belum stabil, UI tidak dipoles dulu.

2. **Beads adalah source of truth.**
   App hanya client/visualizer/controller di atas Beads.

3. **CLI-first.**
   Semua operasi Beads dilakukan via `bd` CLI agar kompatibel dengan behavior resmi Beads.

4. **Local-first.**
   Tidak ada server wajib. Semua bekerja di folder project lokal.

5. **Safe by default.**
   Operasi destruktif seperti close/delete harus jelas dan bisa dikonfirmasi.

6. **Agent-friendly.**
   App harus mendukung workflow Codex/Claude melalui prompt generation dan command context.

---

## 6. Definisi Sukses MVP

MVP dianggap sukses jika user bisa melakukan alur berikut dari awal sampai akhir:

1. Buka app.
2. Pilih folder project lokal.
3. App mendeteksi apakah folder memiliki `.git` dan `.beads`.
4. App memvalidasi `bd` CLI tersedia.
5. App menjalankan `bd list --json` dan menampilkan issue.
6. App menjalankan `bd ready --json` dan menandai issue yang ready.
7. User bisa klik issue untuk melihat detail dari `bd show <id> --json`.
8. User bisa claim issue lewat `bd update <id> --claim`.
9. User bisa close issue lewat `bd close <id> --reason "..."`.
10. User bisa copy prompt Claude untuk issue tertentu.
11. Semua error CLI ditampilkan dengan pesan yang jelas.

---

## 7. Arsitektur Teknis

### 7.1 High-Level Architecture

```text
macOS SwiftUI App
  ↓
Project Workspace Layer
  ↓
Beads CLI Service
  ↓
bd command
  ↓
Project folder / .beads
```

### 7.2 Komponen Utama

```text
App
├── ProjectSelection
├── ProjectValidator
├── ShellCommandRunner
├── BeadsService
├── BeadsJSONDecoder
├── IssueStore / ViewModel
├── KanbanStateMapper
├── PromptGenerator
└── Basic UI Layer
```

---

## 8. Data Flow

### 8.1 Load Project

```text
User memilih folder
  ↓
App mencari project root
  ↓
Validasi .git
  ↓
Validasi .beads
  ↓
Validasi bd CLI
  ↓
Load issues
```

### 8.2 Load Issues

```text
BeadsService.listIssues()
  ↓
run: bd list --json
  ↓
parse JSON
  ↓
IssueStore.issues
  ↓
KanbanStateMapper
  ↓
UI render
```

### 8.3 Load Ready Issues

```text
BeadsService.readyIssues()
  ↓
run: bd ready --json
  ↓
parse JSON
  ↓
IssueStore.readyIssueIDs
  ↓
KanbanStateMapper marks Ready column
```

### 8.4 Mutasi Issue

```text
User action
  ↓
BeadsService executes bd command
  ↓
If success: reload issue list + ready list
  ↓
If failure: show error
```

---

## 9. Model Data Awal

### 9.1 ProjectWorkspace

```swift
struct ProjectWorkspace: Identifiable, Codable {
    let id: UUID
    let rootURL: URL
    let name: String
    let hasGit: Bool
    let hasBeads: Bool
    let hasAgentsFile: Bool
    let bdAvailable: Bool
}
```

### 9.2 BeadIssue

Model harus dibuat toleran karena struktur JSON bisa berbeda antar versi Beads. Field opsional lebih aman untuk MVP.

```swift
struct BeadIssue: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let status: String?
    let priority: Int?
    let issueType: String?
    let description: String?
    let acceptanceCriteria: String?
    let createdAt: String?
    let updatedAt: String?
    let labels: [String]?
    let assignee: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case priority
        case issueType = "issue_type"
        case description
        case acceptanceCriteria = "acceptance_criteria"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case labels
        case assignee
    }
}
```

### 9.3 KanbanColumn

```swift
enum KanbanColumn: String, CaseIterable, Identifiable {
    case backlog = "Backlog"
    case ready = "Ready"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case done = "Done"

    var id: String { rawValue }
}
```

### 9.4 CommandResult

```swift
struct CommandResult {
    let command: String
    let arguments: [String]
    let workingDirectory: URL
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let durationMs: Int
}
```

---

## 10. Backend Requirements

## Phase 0 — Technical Spike & Beads CLI Contract

### Goal

Membuktikan bahwa Swift app bisa menjalankan `bd`, membaca JSON, dan melakukan operasi dasar di folder project lokal.

### Sub-phase 0.1 — Manual CLI Verification

#### Requirements

- Buat project dummy lokal.
- Jalankan `git init`.
- Jalankan `bd init`.
- Buat beberapa issue manual.
- Pastikan command berikut bekerja:

```bash
bd list --json
bd ready --json
bd show <id> --json
bd update <id> --claim
bd close <id> --reason "done"
bd reopen <id>
```

#### Acceptance Criteria

- Ada minimal 5 issue dummy.
- Ada minimal 1 issue ready.
- Ada minimal 1 issue closed.
- Output JSON dari `bd list`, `bd ready`, dan `bd show` disimpan sebagai sample fixture untuk testing.

### Sub-phase 0.2 — JSON Shape Discovery

#### Requirements

- Simpan output JSON ke file lokal app test fixture:

```text
Fixtures/
├── bd-list.json
├── bd-ready.json
└── bd-show.json
```

- Catat field apa saja yang tersedia.
- Pastikan decoder Swift tidak crash jika field hilang.

#### Acceptance Criteria

- Decoder bisa parse fixture tanpa error.
- Minimal field `id` dan `title` terbaca.
- Field opsional tidak menyebabkan crash.

---

## Phase 1 — Project Folder & Workspace Detection

### Goal

App dapat memilih folder project, menemukan root project, dan memvalidasi environment.

### Sub-phase 1.1 — Folder Picker

#### Requirements

- User bisa klik `Choose Project Folder`.
- App membuka macOS folder picker.
- User hanya bisa memilih folder, bukan file.
- Path folder tersimpan di state app.

#### Acceptance Criteria

- App menampilkan path folder yang dipilih.
- Jika user cancel, app tidak crash.
- Jika folder tidak bisa diakses, app menampilkan error.

### Sub-phase 1.2 — Project Root Discovery

#### Requirements

- Jika user memilih subfolder project, app naik ke parent folder sampai menemukan `.git` atau `.beads`.
- Jika tidak ditemukan, app tetap bisa menampilkan folder sebagai kandidat, tapi statusnya `Not a Beads project`.

#### Acceptance Criteria

- Memilih `project/src` tetap mendeteksi `project/` sebagai root jika `.git` atau `.beads` ada di root.
- Jika memilih `Downloads`, app menampilkan status invalid.

### Sub-phase 1.3 — Workspace Validation

#### Requirements

App memvalidasi:

- `.git` exists.
- `.beads` exists.
- `AGENTS.md` exists.
- `bd` CLI available.
- `bd list --json` bisa dijalankan dari folder tersebut.

#### Acceptance Criteria

- UI menampilkan status validasi:

```text
Git: OK / Missing
Beads: OK / Missing
AGENTS.md: OK / Missing
bd CLI: OK / Missing
bd list: OK / Failed
```

- Jika `.beads` tidak ada, app menawarkan command suggestion: `bd init`.
- Jika `bd` tidak ada, app memberi instruksi install.

---

## Phase 2 — ShellCommandRunner

### Goal

Membuat service generik untuk menjalankan command lokal secara aman, reusable, dan testable.

### Sub-phase 2.1 — Basic Command Execution

#### Requirements

- Buat `ShellCommandRunner`.
- Menggunakan `Process()`.
- Mendukung:
  - executable,
  - arguments,
  - working directory,
  - stdout capture,
  - stderr capture,
  - exit code,
  - duration.

#### Acceptance Criteria

- Bisa menjalankan `/usr/bin/env bd --version`.
- Bisa menjalankan `/usr/bin/env git status` di folder project.
- stdout dan stderr tertangkap.
- non-zero exit code tidak membuat app crash.

### Sub-phase 2.2 — Timeout & Cancellation

#### Requirements

- Set timeout default, misalnya 30 detik.
- Jika command terlalu lama, process dihentikan.
- User bisa cancel operasi reload.

#### Acceptance Criteria

- Command hang tidak membuat app freeze.
- Error timeout ditampilkan sebagai error khusus.
- UI tetap responsive.

### Sub-phase 2.3 — Command Logging

#### Requirements

- Simpan command terakhir dalam memory log.
- Log berisi:
  - command,
  - working directory,
  - exit code,
  - duration,
  - timestamp.

#### Acceptance Criteria

- Developer bisa melihat command history di debug panel sederhana.
- Error mudah ditelusuri.

---

## Phase 3 — BeadsService Core

### Goal

Membuat service utama yang membungkus command `bd` menjadi API Swift.

### Sub-phase 3.1 — Read Commands

#### Requirements

Implementasikan:

```swift
func listIssues() async throws -> [BeadIssue]
func readyIssues() async throws -> [BeadIssue]
func showIssue(id: String) async throws -> BeadIssue
```

Command yang digunakan:

```bash
bd list --json
bd ready --json
bd show <id> --json
```

#### Acceptance Criteria

- `listIssues()` mengembalikan array issue.
- `readyIssues()` mengembalikan array issue ready.
- `showIssue()` mengembalikan detail issue.
- Semua error CLI dibungkus dalam `BeadsError`.

### Sub-phase 3.2 — Create Issue

#### Requirements

Implementasikan:

```swift
func createIssue(input: CreateIssueInput) async throws -> BeadIssue?
```

Input minimal:

```swift
struct CreateIssueInput {
    let title: String
    let description: String?
    let issueType: String?
    let priority: Int?
    let acceptanceCriteria: String?
}
```

Command contoh:

```bash
bd create "Title" --json
bd create "Title" -t feature -p 1 --description "..." --acceptance "..." --json
```

#### Acceptance Criteria

- User bisa membuat issue baru dari app.
- Setelah create, issue list reload.
- Jika create gagal, form tidak hilang dan error muncul.

### Sub-phase 3.3 — Claim Issue

#### Requirements

Implementasikan:

```swift
func claimIssue(id: String) async throws
```

Command:

```bash
bd update <id> --claim
```

#### Acceptance Criteria

- Issue bisa diclaim dari app.
- Setelah claim, list reload.
- Issue berpindah ke In Progress jika status mendukung.

### Sub-phase 3.4 — Update Issue Status/Priority

#### Requirements

Implementasikan:

```swift
func updateIssue(id: String, input: UpdateIssueInput) async throws
```

Input:

```swift
struct UpdateIssueInput {
    let title: String?
    let description: String?
    let priority: Int?
    let status: String?
}
```

Command contoh:

```bash
bd update <id> --title "..."
bd update <id> --priority 2
bd update <id> --status in_progress
```

#### Acceptance Criteria

- Minimal priority dan title bisa diupdate.
- Update status optional, tergantung dukungan CLI.
- Jika command tidak didukung oleh versi Beads, error ditampilkan jelas.

### Sub-phase 3.5 — Close & Reopen Issue

#### Requirements

Implementasikan:

```swift
func closeIssue(id: String, reason: String) async throws
func reopenIssue(id: String) async throws
```

Command:

```bash
bd close <id> --reason "..."
bd reopen <id>
```

#### Acceptance Criteria

- Close wajib memiliki reason.
- Reopen mengembalikan issue ke state aktif.
- Setelah close/reopen, list reload.

---

## Phase 4 — Issue Store & State Management

### Goal

Membuat state layer yang menghubungkan backend service ke UI.

### Sub-phase 4.1 — IssueStore

#### Requirements

Buat `IssueStore` sebagai `ObservableObject` atau `@Observable`.

State minimal:

```swift
var issues: [BeadIssue]
var readyIssueIDs: Set<String>
var selectedIssue: BeadIssue?
var isLoading: Bool
var errorMessage: String?
var lastReloadedAt: Date?
```

Actions:

```swift
func reload()
func selectIssue(id: String)
func claimSelectedIssue()
func closeSelectedIssue(reason: String)
func createIssue(...)
```

#### Acceptance Criteria

- UI bisa observe perubahan issue.
- Loading state benar.
- Error tidak membuat state rusak.

### Sub-phase 4.2 — Refresh Strategy

#### Requirements

- Manual refresh button.
- Auto refresh setelah mutasi sukses.
- Optional polling ringan setiap 30–60 detik, tapi default off untuk MVP.

#### Acceptance Criteria

- Setelah create/claim/close, issue list selalu up-to-date.
- Tidak ada double reload berlebihan.

### Sub-phase 4.3 — Sorting & Filtering Backend State

#### Requirements

- Sort issue by priority lalu updated date.
- Filter by status.
- Filter by text search.
- Filter by ready.

#### Acceptance Criteria

- Store bisa memberi computed properties:

```swift
var backlogIssues: [BeadIssue]
var readyIssues: [BeadIssue]
var inProgressIssues: [BeadIssue]
var blockedIssues: [BeadIssue]
var doneIssues: [BeadIssue]
```

---

## Phase 5 — Kanban State Mapping

### Goal

Membuat mapping dari Beads issue state ke kolom Kanban.

### Sub-phase 5.1 — Column Mapping Rules

#### Rules

```text
Done:
- status == closed

In Progress:
- status == in_progress
- or issue has assignee/claim indicator if available

Ready:
- issue.id exists in readyIssueIDs
- and status is not closed
- and not in progress

Blocked:
- status == blocked
- or has unresolved blockers if dependency data available

Backlog:
- open issue
- not ready
- not in progress
- not closed
```

#### Acceptance Criteria

- Satu issue hanya muncul di satu kolom.
- Ready dihitung dari `bd ready --json`, bukan hanya status.
- Closed issue tidak muncul di Ready walaupun ada di ready set karena bug data.

### Sub-phase 5.2 — Unknown Status Handling

#### Requirements

Jika status tidak dikenal:

- tampilkan di Backlog,
- beri badge `Unknown status`,
- jangan crash.

#### Acceptance Criteria

- App tetap berjalan meski Beads menambah status baru.

---

## Phase 6 — Minimal UI untuk Menguji Backend

### Goal

Membuat UI seadanya untuk membuktikan backend berfungsi.

### Sub-phase 6.1 — App Shell

#### Requirements

- Sidebar kiri sederhana.
- Main content area.
- Debug/status bar bawah.

#### Acceptance Criteria

- Ada tombol `Choose Project Folder`.
- Ada tombol `Reload`.
- Ada indikator project path.
- Ada indikator error.

### Sub-phase 6.2 — Basic Issue List

#### Requirements

Sebelum Kanban polished, tampilkan tabel/list semua issue.

Kolom minimal:

```text
ID | Title | Status | Priority | Ready
```

#### Acceptance Criteria

- Semua issue dari `bd list --json` terlihat.
- Ready issue diberi marker.
- Klik issue menjalankan atau memakai `bd show <id> --json`.

### Sub-phase 6.3 — Basic Kanban Columns

#### Requirements

- Tampilkan 5 kolom:
  - Backlog
  - Ready
  - In Progress
  - Blocked
  - Done
- Card cukup berupa rectangle sederhana.

#### Acceptance Criteria

- Issue tampil di kolom yang benar.
- Jumlah issue per kolom benar.
- UI boleh tidak cantik.

### Sub-phase 6.4 — Issue Detail Panel

#### Requirements

Panel detail menampilkan:

- ID,
- title,
- status,
- priority,
- description,
- acceptance criteria,
- labels,
- created/updated date.

Actions:

- Claim,
- Close,
- Reopen,
- Copy Claude Prompt,
- Copy Codex Prompt.

#### Acceptance Criteria

- Klik issue menampilkan detail.
- Claim/Close/Reopen bekerja.
- Prompt berhasil disalin ke clipboard.

---

## Phase 7 — Agent Workflow Backend

### Goal

Mendukung workflow Codex dan Claude tanpa embed API terlebih dahulu.

### Sub-phase 7.1 — Prompt Generator

#### Requirements

Buat `PromptGenerator`.

Functions:

```swift
func claudeImplementationPrompt(issueID: String) -> String
func codexSpecPrompt(issueID: String) -> String
func codexNewFeaturePrompt(featureIdea: String) -> String
```

#### Claude Prompt Template

```text
Run bd prime.

Work on issue <ISSUE_ID>.

Steps:
1. Read the issue with `bd show <ISSUE_ID> --json`.
2. Claim it with `bd update <ISSUE_ID> --claim`.
3. Implement only the acceptance criteria for this issue.
4. Run relevant tests.
5. Summarize changed files.
6. Close the issue only if validation passes.
```

#### Codex Prompt Template

```text
Run bd prime.

You are the AI Spec Writer for this repository.
Refine issue <ISSUE_ID> into a complete implementation spec.

Rules:
- Do not edit source code.
- Update the Beads issue with implementation notes.
- Add acceptance criteria.
- Create child issues if needed.
- Add dependencies where necessary.
```

#### Acceptance Criteria

- Prompt bisa disalin ke clipboard.
- Prompt memasukkan issue ID yang benar.
- Prompt tidak hardcode path project yang salah.

### Sub-phase 7.2 — Open Terminal in Project

#### Requirements

- Tombol membuka Terminal/iTerm di project folder.
- Optional langsung menjalankan `claude`.
- Optional langsung menjalankan `codex`.

#### Acceptance Criteria

- Terminal terbuka di path project yang benar.
- Path dengan spasi aman.
- Jika command `claude` tidak ditemukan, user tetap bisa mengetik manual.

### Sub-phase 7.3 — Command Suggestions

#### Requirements

App bisa menampilkan command yang sebaiknya dijalankan user:

```bash
bd init
bd setup claude
bd setup codex
bd ready --json
```

#### Acceptance Criteria

- Jika `.beads` missing, tampilkan `bd init`.
- Jika `AGENTS.md` missing, tampilkan `bd setup claude` atau `bd setup codex`.

---

## Phase 8 — Error Handling & Reliability

### Goal

Membuat app tidak gampang rusak saat CLI gagal, folder salah, atau JSON berubah.

### Sub-phase 8.1 — Error Taxonomy

#### Requirements

Buat enum error:

```swift
enum BeadsAppError: Error {
    case bdNotInstalled
    case invalidProjectFolder
    case beadsNotInitialized
    case commandFailed(command: String, stderr: String, exitCode: Int32)
    case jsonDecodeFailed(raw: String)
    case timeout(command: String)
    case permissionDenied(path: String)
}
```

#### Acceptance Criteria

- Error teknis diterjemahkan ke pesan manusia.
- stderr tetap bisa dilihat di debug detail.

### Sub-phase 8.2 — JSON Decoder Resilience

#### Requirements

- Field opsional.
- Unknown fields ignored.
- Jika array root berbeda, tangani fallback jika memungkinkan.

#### Acceptance Criteria

- App tidak crash kalau ada field baru.
- Jika decode gagal, tampilkan raw JSON di debug panel.

### Sub-phase 8.3 — Safe Mutations

#### Requirements

- Close issue wajib reason.
- Untuk close/reopen, tampilkan confirmation minimal.
- Tidak ada destructive action silent.

#### Acceptance Criteria

- User tidak bisa close tanpa reason.
- Error close tidak menghapus issue dari UI.

---

## Phase 9 — Local Persistence

### Goal

Menyimpan preferensi lokal app, bukan data issue.

### Sub-phase 9.1 — Recent Projects

#### Requirements

Simpan daftar recent project folder.

Data:

```swift
struct RecentProject: Codable, Identifiable {
    let id: UUID
    let path: String
    let name: String
    let lastOpenedAt: Date
}
```

#### Acceptance Criteria

- App menampilkan recent projects saat dibuka.
- Klik recent project langsung validasi dan load.
- Jika folder sudah hilang, tampilkan error dan opsi remove.

### Sub-phase 9.2 — User Preferences

#### Requirements

Simpan:

- last selected project,
- preferred terminal app,
- auto refresh on/off,
- default close reason template,
- default issue type.

#### Acceptance Criteria

- Preferences tersimpan antar app restart.
- Tidak menyimpan issue data sebagai source of truth.

---

## Phase 10 — Testing Strategy

### Goal

Backend bisa dites tanpa selalu membutuhkan project Beads nyata.

### Sub-phase 10.1 — Unit Test Decoder

#### Requirements

- Test parse fixture `bd-list.json`.
- Test parse fixture `bd-ready.json`.
- Test parse fixture `bd-show.json`.
- Test missing optional fields.

#### Acceptance Criteria

- Decoder tests pass.
- Minimal 3 fixture tests.

### Sub-phase 10.2 — Mock Command Runner

#### Requirements

Buat protocol:

```swift
protocol CommandRunning {
    func run(_ command: CommandRequest) async throws -> CommandResult
}
```

Implementasi:

- `ShellCommandRunner` untuk real command.
- `MockCommandRunner` untuk test.

#### Acceptance Criteria

- BeadsService bisa dites tanpa menjalankan `bd` nyata.
- Mock bisa simulate success/failure.

### Sub-phase 10.3 — Integration Test Optional

#### Requirements

- Buat temp directory.
- Jalankan `git init`.
- Jalankan `bd init` jika `bd` tersedia.
- Buat issue.
- Test list/create/close.

#### Acceptance Criteria

- Integration test bisa diskip otomatis jika `bd` tidak tersedia.
- Tidak merusak folder user.

---

## Phase 11 — Backend Completion Criteria

Backend dianggap siap untuk UI polish jika:

1. Project folder bisa dipilih dan divalidasi.
2. `bd` CLI availability bisa dicek.
3. Issue bisa diload dari `bd list --json`.
4. Ready issue bisa diload dari `bd ready --json`.
5. Detail issue bisa diload dari `bd show <id> --json`.
6. Issue bisa dibuat.
7. Issue bisa diclaim.
8. Issue bisa ditutup dengan reason.
9. Issue bisa direopen.
10. Semua operasi mutation reload data setelah sukses.
11. Error CLI ditampilkan jelas.
12. Recent projects tersimpan.
13. Prompt Claude/Codex bisa digenerate.
14. Terminal bisa dibuka di folder project.
15. Minimal unit test untuk decoder dan service mock tersedia.

---

## 12. UI Requirements Minimal

Walaupun fokus backend, tetap perlu UI minimal untuk mengetes.

### 12.1 Required Screens

1. **Welcome / Project Picker**
   - Choose Project Folder
   - Recent Projects
   - Validation status

2. **Main Board**
   - Simple sidebar
   - Issue list atau Kanban basic
   - Reload button

3. **Issue Detail**
   - Data issue
   - Actions
   - Prompt buttons

4. **Debug Panel**
   - Last command
   - stdout/stderr
   - exit code
   - decode errors

### 12.2 UI Quality Bar

UI boleh sederhana, tapi harus:

- tidak membingungkan,
- tidak crash,
- action jelas,
- error terlihat,
- loading state terlihat.

---

## 13. Command Contract

### 13.1 Required Commands

App harus mendukung command berikut:

```bash
bd --version
bd list --json
bd ready --json
bd show <id> --json
bd create <title> --json
bd update <id> --claim
bd close <id> --reason <reason>
bd reopen <id>
```

### 13.2 Optional Commands

```bash
bd init
bd setup claude
bd setup codex
bd dep add <id> <blocked-by-id>
bd sync
bd dolt push
```

Untuk MVP, optional commands cukup ditampilkan sebagai suggestion atau manual action, tidak wajib dieksekusi otomatis.

---

## 14. Security & Safety Considerations

1. App hanya menjalankan command yang sudah ditentukan, bukan arbitrary shell string.
2. Gunakan argument array, bukan string shell gabungan.
3. Escape path saat membuka Terminal.
4. Jangan menjalankan command dari folder yang belum divalidasi tanpa konfirmasi.
5. Jangan mengeksekusi prompt AI otomatis di fase awal.
6. Jangan menyimpan secret/token.
7. Jangan mengupload data project ke server.

---

## 15. Performance Requirements

1. Loading issue kecil-menengah harus terasa cepat.
2. Untuk repo dengan ratusan issue, app tetap responsive.
3. Command `bd list` dan `bd ready` dijalankan async.
4. UI tidak boleh freeze saat command berjalan.
5. Reload berulang harus dicegah dengan loading lock atau cancellation.

---

## 16. Observability / Debugging

### Debug Panel Minimal

Tampilkan:

```text
Last command: bd list --json
Working dir: /Users/name/Developer/app
Exit code: 0
Duration: 120ms
stdout size: 24 KB
stderr: empty
```

Jika error:

```text
Command failed
bd list --json
exit code: 1
stderr: no beads workspace found
```

---

## 17. Suggested Folder Structure Swift Project

```text
BeadsKanban/
├── App/
│   └── BeadsKanbanApp.swift
├── Models/
│   ├── BeadIssue.swift
│   ├── ProjectWorkspace.swift
│   ├── CommandResult.swift
│   └── KanbanColumn.swift
├── Services/
│   ├── ShellCommandRunner.swift
│   ├── BeadsService.swift
│   ├── ProjectValidator.swift
│   ├── ProjectRootFinder.swift
│   └── PromptGenerator.swift
├── Stores/
│   ├── IssueStore.swift
│   └── ProjectStore.swift
├── Views/
│   ├── WelcomeView.swift
│   ├── MainBoardView.swift
│   ├── IssueListView.swift
│   ├── KanbanBoardView.swift
│   ├── IssueDetailView.swift
│   └── DebugPanelView.swift
├── Utilities/
│   ├── Clipboard.swift
│   ├── TerminalLauncher.swift
│   └── DateFormatting.swift
└── Tests/
    ├── Fixtures/
    ├── BeadsJSONDecoderTests.swift
    ├── BeadsServiceTests.swift
    └── ProjectValidatorTests.swift
```

---

## 18. Detailed Phase Plan

## Milestone A — Backend Proof

### Phase A1 — CLI Spike

Deliverables:

- Dummy Beads project.
- JSON fixtures.
- Notes about actual JSON shape.

Exit Criteria:

- Developer understands exact `bd` command behavior.

### Phase A2 — ShellCommandRunner

Deliverables:

- `CommandRunning` protocol.
- `ShellCommandRunner` implementation.
- Basic command execution test.

Exit Criteria:

- Swift app can run `bd --version` and capture output.

### Phase A3 — Project Validation

Deliverables:

- Folder picker.
- Root finder.
- Project validator.

Exit Criteria:

- App can detect valid/invalid Beads project.

---

## Milestone B — Beads Data Layer

### Phase B1 — Read-only BeadsService

Deliverables:

- `listIssues()`.
- `readyIssues()`.
- `showIssue()`.
- JSON models.

Exit Criteria:

- App can show issue list from real Beads project.

### Phase B2 — Issue Store

Deliverables:

- `IssueStore`.
- Reload logic.
- Loading/error state.

Exit Criteria:

- UI updates when reload is clicked.

### Phase B3 — Kanban Mapping

Deliverables:

- Computed columns.
- Ready mapping.
- Unknown status fallback.

Exit Criteria:

- Every issue appears in exactly one column.

---

## Milestone C — Mutations

### Phase C1 — Create Issue

Deliverables:

- Create issue form minimal.
- `createIssue()` service.

Exit Criteria:

- New issue appears after create.

### Phase C2 — Claim Issue

Deliverables:

- Claim button.
- `claimIssue()` service.

Exit Criteria:

- Issue can be claimed and reloaded.

### Phase C3 — Close/Reopen

Deliverables:

- Close with reason.
- Reopen button.

Exit Criteria:

- Done column updates correctly.

---

## Milestone D — Agent Workflow

### Phase D1 — Prompt Generation

Deliverables:

- Claude prompt.
- Codex prompt.
- Clipboard integration.

Exit Criteria:

- User can copy correct prompt for selected issue.

### Phase D2 — Terminal Launcher

Deliverables:

- Open Terminal in project.
- Optional open with `claude`.
- Optional open with `codex`.

Exit Criteria:

- Terminal opens at correct project path.

---

## Milestone E — Reliability

### Phase E1 — Error Handling

Deliverables:

- Error taxonomy.
- Human-readable error messages.
- Debug details.

Exit Criteria:

- App handles missing `bd`, invalid folder, failed command, and bad JSON.

### Phase E2 — Local Persistence

Deliverables:

- Recent projects.
- Last selected project.
- Preferences.

Exit Criteria:

- User can reopen app and continue from recent project.

### Phase E3 — Tests

Deliverables:

- Decoder tests.
- Mock service tests.
- Project validator tests.

Exit Criteria:

- Backend changes can be tested reliably.

---

## 19. Acceptance Criteria Global MVP

MVP backend-first selesai jika semua ini terpenuhi:

```text
[ ] User bisa memilih folder project.
[ ] App bisa menemukan root project dari subfolder.
[ ] App memvalidasi .git.
[ ] App memvalidasi .beads.
[ ] App memvalidasi bd CLI.
[ ] App bisa run bd list --json.
[ ] App bisa parse issue list.
[ ] App bisa run bd ready --json.
[ ] App bisa menandai ready issues.
[ ] App bisa run bd show <id> --json.
[ ] App bisa create issue.
[ ] App bisa claim issue.
[ ] App bisa close issue dengan reason.
[ ] App bisa reopen issue.
[ ] App reload setelah mutation.
[ ] App punya command log/debug panel.
[ ] App punya recent projects.
[ ] App bisa generate Claude prompt.
[ ] App bisa generate Codex prompt.
[ ] App bisa copy prompt ke clipboard.
[ ] App bisa open Terminal di project folder.
[ ] Error ditampilkan jelas.
[ ] UI minimal bisa dipakai untuk mengetes semua fitur backend.
```

---

## 20. Future UI Polish Phase

Setelah backend stabil, baru masuk UI polish:

1. Linear-style dark UI.
2. Drag-and-drop cards.
3. Animated transitions.
4. Better sidebar.
5. Label colors.
6. Priority icons.
7. Dependency graph.
8. Command palette.
9. Keyboard shortcuts.
10. Multi-project dashboard.

---

## 21. Future Advanced Backend

Setelah MVP:

1. File watcher untuk auto reload saat `.beads` berubah.
2. Beads MCP integration optional.
3. Multi-repo ready queue.
4. Git branch awareness.
5. Commit/test result linking.
6. Claude/Codex session launcher.
7. Activity timeline.
8. Dependency graph parser.
9. Sync status panel.
10. AI-generated issue refinement inside app.

---

## 22. Recommended First Implementation Order

Urutan kerja paling aman:

```text
1. Buat dummy Beads project manual.
2. Simpan JSON fixtures.
3. Buat Swift app kosong.
4. Buat ShellCommandRunner.
5. Buat ProjectValidator.
6. Buat BeadsService read-only.
7. Buat IssueStore.
8. Tampilkan issue dalam List sederhana.
9. Tambahkan Ready mapping.
10. Tambahkan detail issue.
11. Tambahkan create issue.
12. Tambahkan claim issue.
13. Tambahkan close/reopen.
14. Tambahkan prompt generator.
15. Tambahkan terminal launcher.
16. Tambahkan recent projects.
17. Tambahkan debug panel.
18. Baru rapikan Kanban UI.
```

---

## 23. MVP Scope Cutline

Jika waktu terbatas, MVP paling kecil adalah:

```text
Must Have:
- Choose folder
- Validate bd
- bd list --json
- bd ready --json
- Basic Kanban columns
- bd show detail
- claim
- close
- copy Claude prompt

Should Have:
- create issue
- reopen issue
- recent projects
- debug panel

Could Have:
- terminal launcher
- Codex prompt
- search/filter

Not Now:
- drag-and-drop
- beautiful UI
- embedded AI
- cloud sync
```

---

## 24. Final Product Direction

Produk ini harus tumbuh menjadi **AI-native local project manager** untuk developer Mac:

- Beads sebagai local issue database.
- Swift app sebagai visual control center.
- Codex sebagai spec writer.
- Claude Code sebagai executor.
- Git sebagai sync/history layer.

Versi awal tidak perlu terlihat indah. Yang penting adalah workflow backend benar:

```text
folder project → bd command → JSON model → issue state → action → reload → prompt agent
```

Jika fondasi ini kuat, UI bisa dibuat cantik belakangan tanpa perlu rewrite backend.

