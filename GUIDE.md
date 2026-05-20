# Panduan Kerja — Beads Kanban

Panduan singkat untuk siapapun (manusia atau AI agent) yang mau ngerjain
task di proyek ini. Baca **sekali**, lalu pakai sebagai referensi.

> Source of truth task tracking di proyek ini adalah `bd` (Beads).
> **JANGAN** pakai TodoWrite, markdown TODO, atau MEMORY.md untuk tracking.

---

## 1. Konsep Inti — 30 detik

- Setiap pekerjaan = satu **issue** dengan ID format `Workstation-xxx`.
- Issue punya **status** yang berpindah-pindah seiring kerja jalan.
- Issue punya **assignee** (siapa yang ngerjain) dan **labels** (tag).
- File `.beads/issues.jsonl` adalah export pasif — **jangan** edit manual.
  Semua perubahan via `bd` command.

### Status Lifecycle (PENTING — ini yang sering kelewat)

```
open → in_progress → [review] → closed
        ↓
     blocked  (kalau ada dependency belum selesai)
```

Aturan transisi:

| Dari → Ke | Cara | Kapan |
|-----------|------|-------|
| `open` → `in_progress` | `bd update <id> --claim` | Mulai ngerjain |
| `in_progress` → **`review`** | `bd update <id> --add-label human` | **Selesai coding, butuh review manusia** |
| `review` → `closed` | `bd close <id> --reason="..."` | Manusia approve hasilnya |
| any → `blocked` | otomatis dari `bd dep add` | Ada dependency belum done |

> **AI agent (Claude/Codex) TIDAK boleh langsung `bd close`.**
> Workflow yang benar: kerjain → flag `human` → tunggu user close.
> Ini convention proyek — supaya manusia tetap punya kontrol final.

---

## 2. Flow Lengkap — Contoh Konkret

Skenario: Manusia minta feature baru, dikerjain agent, lalu ditutup.

### Step 1 — Manusia bikin issue

```bash
bd create \
  --title="Tambah dark mode toggle di settings" \
  --description="Why: user request agar bisa ganti tema manual.
What: tombol di PreferencesSheet yang toggle .light/.dark.
Out of scope: tema custom selain dark/light." \
  --type=feature \
  --priority=2
```

Output: `✓ Created issue: Workstation-abc — ...`

### Step 2 — Agent cari kerjaan

```bash
bd ready                    # list issue yang siap dikerjain
bd show Workstation-abc     # baca detail lengkap
```

### Step 3 — Agent claim & set assignee

```bash
bd update Workstation-abc --claim --assignee=claude
# atau --assignee=codex
```

`--claim` set status ke `in_progress` + assignee otomatis ke `$USER`.
Pakai `--assignee=claude` / `--assignee=codex` / `--assignee=other`
supaya icon brand muncul di kanban app (sparkles gold untuk Claude,
chevrons biru untuk Codex, cpu ungu untuk AI lain seperti Gemini/GPT).

### Step 4 — Agent kerjain

Coding, testing, dll. Selama kerja:

- `bd show <id>` — review konteks lagi.
- `bd update <id> --notes="progress: X selesai, Y in flight"` — log
  progress (opsional, untuk hand-off ke sesi berikut).

### Step 5 — Selesai → flag review (BUKAN close)

```bash
bd update Workstation-abc \
  --add-label human \
  --notes="Implemented dark mode toggle. swift test 170/170 hijau,
xcodebuild SUCCEEDED. PreferencesSheet baru di App/, AppPreferences
extended dengan colorScheme. Manual smoke pending."
```

Issue sekarang masuk **Review** column di kanban app. **Stop di sini.**
Tunggu manusia.

### Step 6 — Manusia review & close

```bash
bd close Workstation-abc --reason="Verified manually. Looks good, merged."
```

---

## 3. Cheat Sheet Command

### Cari & lihat

```bash
bd ready                           # issue siap dikerjain (no blockers)
bd list --status=open              # semua open
bd list --status=in_progress       # yang lagi dikerjain
bd list --status=review            # yang nunggu manusia
bd blocked                         # yang ke-block
bd show <id>                       # detail lengkap satu issue
bd search "<keyword>"              # cari by teks
bd stats                           # angka ringkas open/closed/blocked
```

### Bikin & ubah

```bash
bd create --title="..." --description="..." --type=task --priority=2
bd update <id> --claim                      # claim + in_progress
bd update <id> --assignee=claude            # set assignee
bd update <id> --add-label human            # flag for review
bd update <id> --remove-label human         # un-flag
bd update <id> --status=open                # rollback ke open
bd update <id> --notes="..."                # tambah catatan
bd update <id> --title="..." --description="..."   # edit field
bd close <id> --reason="..."                # tutup (manusia saja!)
bd close <id1> <id2> ...                    # tutup banyak sekaligus
```

> ⚠️ **JANGAN PAKAI `bd edit`** — buka $EDITOR (vim/nano) yang nge-block
> agent. Selalu pakai `bd update <id> --field=value`.

### Dependency

```bash
bd dep add <issue> <depends-on>    # issue depends-on harus selesai dulu
bd dep remove <issue> <depends-on>
bd blocked                         # lihat siapa yang ke-block
```

bd otomatis detect cycle, jadi `A blocks B, B blocks A` bakal di-reject.

### Memori antar-sesi

```bash
bd remember "insight penting"      # simpan catatan persistent
bd memories <keyword>              # cari catatan
```

Pakai ini untuk knowledge yang lintas-sesi (konvensi proyek, gotcha,
keputusan arsitektur). Jangan bikin file MEMORY.md.

---

## 4. Convention Proyek (yang gampang kelewat)

### Priority

| Value | Label | Kapan |
|-------|-------|-------|
| `0` / `P0` | Must / Critical | Production down, security |
| `1` / `P1` | Important | Blocker untuk milestone |
| `2` / `P2` | High | Default untuk feature normal |
| `3` / `P3` | Medium | Nice-to-have |
| `4` / `P4` | Backlog | Suatu hari |

Pakai angka, **bukan** "high"/"medium"/"low".

### Type

`task`, `bug`, `feature`, `epic`, `chore`. Pilih yang paling deskriptif.

### Assignee Convention

- `claude` → icon **sparkles** gold (Claude AI)
- `codex` → icon **chevrons** biru (OpenAI Codex)
- `other` / `gemini` / `gpt` / `llm` / `bot` → icon **cpu** ungu (AI lain di luar Claude/Codex)
- Apapun lainnya (`rayne`, `rayne-lope`, dll.) → text initials (manusia)

Resolver match token case-insensitive substring, jadi `Claude`,
`claude-code`, `anthropic` semua valid untuk kind Claude. Begitu juga
`Gemini` atau `agent` → kind Other (ungu).

### Description Style

```
Why: <alasan kenapa issue ini ada — masalah / kebutuhan>
What:
- <poin konkret apa yang harus dilakukan>
- <poin lain>
Out of scope:
- <yang sengaja tidak dikerjain biar fokus>
```

Ini bukan wajib, tapi bikin issue jauh lebih clear untuk dikerjain orang
lain (atau agent) tanpa nanya balik.

---

## 5. Sebelum Bilang "Selesai"

Checklist mandatory untuk AI agent setelah implementasi:

```
[ ] swift test                     — minimal hijau, kalau ada test relevan
[ ] swift build / ./run-app build  — pastikan compile clean
[ ] bd update <id> --add-label human --notes="..."
[ ] (JANGAN bd close — biar manusia)
```

Checklist untuk manusia setelah review:

```
[ ] bd close <id> --reason="..."
[ ] (kalau ada follow-up) bd create issue baru, jangan reopen
```

---

## 6. Common Pitfalls

| Salah | Benar | Kenapa |
|-------|-------|--------|
| `bd close` setelah agent selesai | `bd update --add-label human` | Manusia harus review dulu |
| `--assignee="Claude Code Executor"` | `--assignee=claude` | Token pendek lebih ergonomis, resolver pinter |
| `bd edit <id>` | `bd update <id> --field=value` | edit buka vim, block agent |
| Edit `.beads/issues.jsonl` manual | `bd update` | File itu export pasif |
| `bd create` tanpa description | Selalu kasih Why + What | Issue tanpa konteks = nanya balik |
| Bikin file MEMORY.md / TODO.md | `bd remember` / `bd create` | Fragmen, gampang lost |
| Lupa pindahin ke review | `--add-label human` setelah selesai | Kanban macet di "In Progress" |

---

## 7. Recovery Quick Reference

| Masalah | Solusi |
|---------|--------|
| Sesi habis di tengah jalan | `bd prime` lalu `bd list --status=in_progress` |
| Lupa apa yang dikerjain | `bd show <id>` baca notes & description |
| Issue salah di-close | `bd update <id> --status=open` |
| Mau batalin claim | `bd update <id> --status=open --assignee=""` |
| Cycle detected | `bd show <id>` lalu `bd dep remove` salah satu edge |
| Ngerasa stuck / butuh diskusi | `bd human <id>` flag untuk human decision |

---

## 8. Untuk AI Agent Khusus

Saat dipanggil untuk ngerjain task di proyek ini:

1. **`bd prime`** dulu di awal sesi (auto-load context).
2. **Baca issue lengkap** sebelum coding: `bd show <id>`.
3. **Claim** dengan assignee yang benar: `bd update <id> --claim --assignee=claude` (atau codex).
4. Coding + testing. Pakai test framework yang ada (`swift test`).
5. **Selesai → flag review**, BUKAN close:
   ```bash
   bd update <id> --add-label human --notes="<ringkasan apa yang dilakukan, hasil test>"
   ```
6. Hand-off: kasih manusia ringkasan singkat (1-2 kalimat) di chat.

Yang **TIDAK boleh** dilakukan AI agent tanpa izin eksplisit:
- `bd close` — itu hak manusia.
- `git push` ke main — kecuali user minta.
- `bd dep add/remove` di issue yang bukan kerjaannya.
- Edit `bd` config (`bd config set ...`).

---

## 9. Referensi Cepat

- **Project**: macOS native SwiftUI app yang wrap `bd` CLI.
- **Build**: `swift build` (CLI test) / `./run-app build` (app bundle).
- **Test**: `swift test` — target hijau penuh.
- **Style guide**: `references/workstations_style_guide.md` (Craftboard
  dark productivity theme, gold accent).
- **UI komponen**: `App/` (SwiftUI), `Sources/BeadsWorkspace/` (logic).
