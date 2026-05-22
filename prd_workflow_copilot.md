# PRD — Workflow Copilot (Unified Local AI Chat Agent)

**Status**: Draft · Konsultasi
**Owner**: Rapi
**Last updated**: 2026-05-20

---

## 1. Ringkasan

Saat ini fitur Local AI tersebar di banyak entry point berbeda:

- **Simplify Indonesian** — tombol di `IssueDetailView`
- **Close Reason** — generator di `CloseIssueSheet`
- **Backlog Analysis** — action di toolbar
- **Issue Drafting** — preview saat create
- **Prompt Optimization** — di prompt editor
- **Run Summary** — di agent console

Tiap fitur punya sheet sendiri, prompt sendiri, dan tombol sendiri. UX-nya terfragmentasi: user harus tahu fitur ada di mana, dan tidak bisa mengkombinasikan (mis. "summarize lalu draft close reason").

**Workflow Copilot** menyatukan semua interaksi Local AI ke **satu chat agent panel**. User ngobrol natural language; copilot tahu konteks selected issue(s) + workspace state, dan bisa memanggil action yang dulunya berdiri sendiri. **Human tetap approve** sebelum mutasi dieksekusi.

## 2. Tujuan

| Tujuan | Metrik sukses |
|---|---|
| Konsolidasi UI AI ke satu panel | 6+ sheet AI yang ada bisa diakses dari copilot tanpa kehilangan kemampuan |
| Tambah workflow planning (assign+launch multi-issue) | User bisa minta "Assign Claude ke 3 issue ini dan launch" dalam 1 prompt |
| Pertahankan safety net | Tidak ada action AI yang dieksekusi tanpa konfirmasi user |
| Discoverability | New user bisa menemukan semua kemampuan AI dari satu tempat |

**Non-goal sekarang:**
- Replace existing entry point sepenuhnya di rilis pertama (deprecate gradual, bukan big-bang)
- Multi-turn agentic loop yang bikin LLM auto-iterate sampai goal
- Memory antar-sesi (chat history persistensi panjang)
- Tool use beyond yang sudah ada di app (no shell execution, no file edit by AI)

## 3. User Stories

1. **Single-issue translate**: "Saya buka issue X, klik copilot, ketik 'sederhanakan dalam Bahasa Indonesia' → preview muncul → apply ke notes."
2. **Bulk assign + launch**: "Saya pilih 3 issue ready, ketik 'assign Claude dan launch worktree' → copilot return plan → saya centang → apply."
3. **Smart close**: "Saya kerja di issue, ketik 'siap close, summarize dari run terakhir' → copilot draft close reason → saya review → close."
4. **Backlog triage**: "Tanpa selection, ketik 'analyze backlog dan saran prioritas' → copilot return report read-only."
5. **Create new issue from idea**: "Ketik 'create issue: refactor X karena Y' → copilot draft title/description/acceptance → saya review → submit."

## 4. Architecture

### 4.1 Layer

```
App/WorkflowCopilot/         ← UI (chat pane, message bubble, plan preview)
Sources/BeadsWorkspace/WorkflowCopilot/   ← logic
  ├─ WorkflowCopilotStore.swift   (@Observable, conversation state)
  ├─ WorkflowCopilotRouter.swift  (intent → action mapping)
  ├─ WorkflowIntent.swift          (enum of supported intents)
  ├─ WorkflowPlan.swift            (Codable structured plan)
  └─ WorkflowPlanValidator.swift   (pure, no I/O)
Sources/BeadsContract/WorkflowCopilot/    ← shared types
  └─ WorkflowPlan.swift (Codable models)
```

### 4.2 Reuse existing infrastructure

| Existing | Dipakai untuk |
|---|---|
| `LocalAIService.generate` | Single LLM entry point — tetap |
| `LocalAIAction` | Tambah case `.copilotPlan(context:)` + retain existing cases untuk dipanggil oleh router |
| `IssueStore.selectedIssueIDs` | Konteks selected issues |
| `AgentProfileStore.executorProfile(forAssignee:)` | Resolve agent name → profile |
| `AgentLaunchFlowCoordinator` + `GitWorktreeService` | Launch worktree dengan dirty-check |
| `AppViewModel.assignAndLaunchIfExecutor` | Single-action handoff |
| `GitStatusService.statusSummary` | Dirty state context |
| `CreateIssueInput` + `BeadsService.createIssue` | Create issue action |
| `IssueStore.update` + `close` | Mutate actions |

**No duplication of launch / mutate plumbing.** Copilot hanya orchestrator + UI baru.

### 4.3 Two-tier action model

```
WorkflowPlan
├─ Tier 1: Read-only AI responses
│   ├─ translate / simplify (existing simplifyIssueIndonesian)
│   ├─ summarize_backlog (existing backlogAnalysis)
│   ├─ optimize_prompt (existing promptOptimization)
│   └─ explain_issue (NEW — generic Q&A)
│
└─ Tier 2: Mutating actions (need approval)
    ├─ assign_and_launch (executor: claude/codex/other)
    ├─ assign_only (human)
    ├─ close_with_reason (existing closeReason + close mutation)
    ├─ request_review
    ├─ create_issue (existing issueDrafting + create mutation)
    └─ update_field (notes, description, priority)
```

Tier 1 = LLM call → tampilkan text. Tier 2 = LLM return structured plan → validator → user approve → mutate via existing API.

### 4.4 Intent routing

User input → **Intent classifier**:
1. Cek heuristic (keyword "assign", "launch", "close", "create issue") → langsung route ke handler tipikal
2. Jika tidak match → kirim ke LLM dengan system prompt "decide intent type", LLM return `{intent: "translate" | "plan" | "create" | ...}`
3. Router panggil sub-action sesuai intent

Heuristic dulu supaya hemat token + cepat. LLM hanya untuk ambigu.

## 5. UI/UX

### 5.1 Entry points

**Primary (single new entry):** Tombol "Copilot" di toolbar utama (di samping "New Issue") + keyboard shortcut `⌘K`. Selalu available, terlepas dari selection state.

**Secondary (contextual):**
- Bulk action panel — tombol "Ask Copilot…" saat multi-select
- Issue detail header — tombol kecil ikon sparkles

**Deprecation path (gradual, NOT in v1):**
- v1: Existing buttons (Simplify, Backlog Analysis, dst.) tetap ada
- v2: Tampilkan tooltip "Tersedia juga di Copilot ⌘K"
- v3: Hapus existing buttons setelah usage telemetri menunjukkan copilot diadopsi

### 5.2 Layout

Copilot menggantikan right pane (mode keempat di `DetailPaneMode`: `.copilot`). Width 440 (sama dengan issue detail).

```
┌─────────────────────────────────┐
│ Workflow Copilot              × │
├─────────────────────────────────┤
│ Context: 3 issues selected      │  ← chip strip, kolapsible
│ ├ Workstation-abc · Fix login   │
│ ├ Workstation-def · Add API     │
│ └ Workstation-ghi · Refactor X  │
├─────────────────────────────────┤
│ [conversation scrollback]       │
│                                  │
│ 🧑 Assign Claude ke 3 issue ini │
│                                  │
│ 🤖 Plan: 3 actions               │
│ ☑ Assign Claude → -abc + launch │
│ ☑ Assign Claude → -def + launch │
│ ☐ -ghi blocked by -xyz, skip    │
│ [Apply 2 actions] [Discard]     │
│                                  │
├─────────────────────────────────┤
│ Type a message…              ⏎  │
└─────────────────────────────────┘
```

### 5.3 Message types

| Sender | Tipe | Render |
|---|---|---|
| User | Text | Right-aligned bubble |
| Copilot | Text (Tier 1 result) | Left-aligned bubble, markdown rendering |
| Copilot | Plan (Tier 2) | Card dengan checkbox per action, footer "Apply N" + "Discard" |
| Copilot | Error | Red banner with retry button |
| System | Context update | Muted text ("Selection changed to 5 issues") |

### 5.4 State machine

```
Idle → User types → Sending → 
  ├─ Tier 1: Result rendered → Idle
  └─ Tier 2: Plan rendered → Awaiting Approval
              ├─ User approves → Applying (sequential) → Idle
              ├─ User discards → Idle
              └─ User modifies prompt → Sending (regenerate)
```

## 6. Data Contracts

### 6.1 WorkflowIntent (Swift)

```swift
enum WorkflowIntent: Codable {
    case translate(target: TranslationTarget)
    case summarizeBacklog
    case optimizePrompt(text: String)
    case explainIssue(question: String)
    case planMutations  // returns WorkflowPlan
}
```

### 6.2 WorkflowPlan (JSON contract dengan LLM)

```json
{
  "summary": "Assign Claude to 3 ready issues, defer 1 blocked",
  "actions": [
    {
      "id": "uuid-1",
      "kind": "assign_and_launch",
      "issue_id": "Workstation-abc",
      "agent": "claude",
      "use_worktree": true,
      "reason": "Ready, no blockers"
    },
    {
      "id": "uuid-2",
      "kind": "close_with_reason",
      "issue_id": "Workstation-def",
      "draft_reason": "Implemented bulk assign in IssueCardView ...",
      "reason": "Completed per latest run"
    },
    {
      "id": "uuid-3",
      "kind": "create_issue",
      "title": "Refactor X",
      "description": "Why this exists ...",
      "issue_type": "chore",
      "priority": 3,
      "reason": "User requested"
    },
    {
      "id": "uuid-4",
      "kind": "skip",
      "issue_id": "Workstation-ghi",
      "reason": "Blocked by Workstation-xyz which is open"
    }
  ],
  "warnings": ["Working tree dirty — worktree mode recommended"]
}
```

### 6.3 Validator output

Per-action annotation tanpa mutate plan:

```swift
struct ValidatedAction {
    let action: ProposedAction
    let status: ValidationStatus  // .executable | .warning(reason) | .blocked(reason)
    let defaultApproved: Bool      // checkbox initial state
}
```

## 7. Prompt Engineering

### 7.1 System prompt (shared)

```
You are the Workflow Copilot for the Beads Kanban app.
You help the user plan and execute issue workflows.
NEVER fabricate issue IDs — only reference IDs in the provided context.
NEVER auto-execute. Return suggestions only.
Output JSON matching the WorkflowPlan schema, no prose.
```

### 7.2 Context envelope

Dikirim tiap turn (compact, deterministik):

```
== Selected Issues (N) ==
- Workstation-abc · "Fix login" · status: ready · priority: P1 · blocked_by: [] · assignee: -
  description: ...

== Workspace State ==
- working_tree: dirty (3 files)
- branch: master
- available_agents: claude, codex, other

== User Request ==
{user prompt verbatim}
```

Cap: ~4k tokens. Truncate dengan urutan: keep selected issue full → ringkas blockers → drop labels/dependents.

### 7.3 Per-intent prompts

Tier 1 intents pakai `LocalAIAction` existing (jangan duplikasi prompt). Tier 2 = satu prompt utama "produce WorkflowPlan JSON".

## 8. Safety & Validation

### 8.1 Hard rules (validator enforce)

| Rule | Action |
|---|---|
| `issue_id` tidak ada di store | Drop action |
| `agent` tidak resolve | Drop |
| Issue closed | Drop mutate actions |
| Action di issue blocked + tipe = assign_and_launch | Default OFF + warning |
| Dirty tree + use_worktree=false | Default OFF + auto-suggest worktree |
| Duplikat action untuk issue+kind sama | Keep first |
| Total action > 10 | Truncate + warning |

### 8.2 Re-validation before apply

Plan bisa stale (user lain edit issue, atau status berubah). Sebelum apply, **re-run validator**. Action yang baru jadi blocked → otomatis un-check + tampilkan banner "Plan re-validated, 1 action removed".

### 8.3 Apply loop semantics

- **Sequential**, bukan paralel (karena dirty-git sheet bisa muncul)
- Setiap action pakai existing API (`assignAndLaunchIfExecutor`, `store.update`, `service.createIssue`, dst.)
- Kalau action gagal di tengah → stop, tampilkan partial result + tombol "Retry remaining"
- Log audit ke `AgentRunHistoryStore` dengan kind baru `.copilotApply` (audit trail)

## 9. Failure Modes

| Failure | Handling |
|---|---|
| LLM return non-JSON | Show raw response as Tier 1 text + banner "Could not parse plan" |
| LLM return action dengan issue_id tidak ada | Validator drop + log warning di plan |
| Ollama unreachable | Error bubble dengan "Test Connection" button (existing LocalAIConnectionTester) |
| User submit selama plan masih awaiting approval | Confirm dialog "Discard pending plan?" |
| Action apply gagal | Stop, show error, keep checked state untuk retry |

## 10. Phased Implementation

**Fase 0 — Foundation (di issue tracker terpisah)**
- Define `WorkflowPlan`, `WorkflowIntent` di Contract
- Tambah `LocalAIAction.copilotPlan(context:)`
- Codable parser + tests

**Fase 1 — MVP: read-only + single mutate**
- Chat pane UI (`DetailPaneMode.copilot`)
- Entry ⌘K + toolbar button
- Intent routing untuk: translate, summarize_backlog, explain_issue (Tier 1)
- Tier 2 dengan **assign_and_launch only** (most-requested use case)
- Validator + apply loop sequential

**Fase 2 — Expand mutating actions**
- Tambah create_issue, close_with_reason, request_review, update_field
- Re-validation before apply
- Audit ke AgentRunHistoryStore

**Fase 3 — UX polish**
- Conversation scrollback dengan timestamp
- Regenerate plan button
- "Why?" tooltip per action (LLM explanation)
- Streaming response (text bubble cuma — plan tetap full JSON)

**Fase 4 — Gradual deprecation existing buttons**
- Tooltip "Available in Copilot ⌘K" di tombol AI existing
- Telemetri usage
- Hapus tombol existing setelah confirmed usage shift

## 11. Open Questions

1. **Multi-turn chat depth.** Apakah copilot perlu ingat turn sebelumnya dalam sesi yang sama? Awalnya: **ya**, last 5 messages, in-memory only.
2. **LLM tier per intent.** Tier 1 sederhana (translate) → fast model. Tier 2 plan → strong model. Override per-intent oke?
3. **Should copilot create dependencies (`bd dep add`)?** Tier 2 action `add_blocker` sudah ada di existing flow. Tambahkan ke v2.
4. **Inline preview vs side pane?** Saat ini side pane menggantikan issue detail. Apakah perlu modal/inline alternatif? Defer ke v2.

## 12. Yang TIDAK Boleh

- **Auto-apply** tanpa human approval — never
- **Shell command execution** by AI — never
- **Cross-workspace** planning — defer
- **Persistensi chat** ke disk — defer (privacy)
- **Memory antar sesi tentang user preference** — defer (gunakan `bd remember` yang sudah ada untuk codebase-level memory, bukan per-user)

## 13. Critical Files (untuk implementasi nanti)

| File | Type | Purpose |
|---|---|---|
| `Sources/BeadsContract/WorkflowCopilot/WorkflowPlan.swift` | NEW | Codable models |
| `Sources/BeadsContract/WorkflowCopilot/WorkflowIntent.swift` | NEW | Intent enum |
| `Sources/BeadsWorkspace/WorkflowCopilot/WorkflowCopilotStore.swift` | NEW | @Observable state |
| `Sources/BeadsWorkspace/WorkflowCopilot/WorkflowCopilotRouter.swift` | NEW | Intent dispatcher |
| `Sources/BeadsWorkspace/WorkflowCopilot/WorkflowPlanValidator.swift` | NEW | Pure validator |
| `Sources/BeadsWorkspace/LocalAIAction.swift` | MODIFY | Tambah `.copilotPlan` case |
| `App/WorkflowCopilot/WorkflowCopilotPane.swift` | NEW | Chat UI root |
| `App/WorkflowCopilot/CopilotMessageBubble.swift` | NEW | Message rendering |
| `App/WorkflowCopilot/CopilotPlanCard.swift` | NEW | Plan with checkboxes |
| `App/AppViewModel.swift` | MODIFY | Wire copilot store + apply loop |
| `App/IssueRightPane.swift` | MODIFY | Tambah `.copilot` mode |
| `App/BoardView.swift` | MODIFY | ⌘K entry + toolbar button |
| `project.yml` | MODIFY | Register new App/WorkflowCopilot/ folder |

## 14. Verification (untuk acceptance nanti)

- [ ] `swift test` exit 0, target 280+ tests dengan tambahan copilot tests
- [ ] `./run-app build` exit 0
- [ ] Smoke: pilih 3 issue → ⌘K → "assign claude" → plan muncul → apply → 3 worktree terbuka
- [ ] Smoke: tanpa selection → "summarize backlog" → text bubble muncul
- [ ] Smoke: dirty tree → "assign claude" → warning chip muncul + default off
- [ ] Smoke: plan stale (close issue di terminal lain) → apply → re-validation drop action

---

**Catatan**: PRD ini dokumen hidup. Sebelum mulai implementasi, review section 11 (open questions) dan konfirmasi scope MVP (section 10 Fase 1).
