# Product Requirement Document (PRD)
## Premium Agent Run Timeline & Interactive Approvals

**Product:** Workstation / Beads Kanban macOS App  
**Feature Priority:** Priority 2  
**Status:** Implementation-ready draft  
**Owner:** Workstation App  
**Primary Surface:** Issue Detail Pane + Run Console Drawer  

---

## 1. Executive Summary

### 1.1 Context
Workstation is a backend-first macOS Beads Kanban app where coding agents such as Gemini, Claude, Codex, and Antigravity execute issue work by running shell commands, modifying files, compiling builds, and running test suites.

The app already supports integrated PTY streaming and has recently improved terminal performance through non-blocking background reads, in-memory buffering, throttled UI updates, transcript line-capping, and reduced disk writes during active runs.

However, raw terminal output is still not the ideal user experience for monitoring autonomous coding work. Even when the terminal no longer lags, it remains noisy, visually dense, and difficult to scan. Users should not need to open a raw terminal drawer just to answer an agent approval prompt, understand what step is running, or inspect whether a build failed.

### 1.2 Product Vision
Introduce a premium **Agent Run Timeline & Interactive Approvals** system that transforms raw agent execution into a semantic mission-control experience.

Instead of showing only raw terminal text, Workstation will display a compact, high-signal vertical timeline in the Issue Detail Pane. The timeline summarizes what the agent is doing, which commands ran, which files changed, whether builds/tests passed, and whether user approval is required.

The raw terminal remains available as the audit/debug view, but the default experience becomes clean, visual, actionable, and safe.

### 1.3 One-Sentence Goal
Build a lightweight semantic execution timeline that lets users understand, approve, pause, cancel, and inspect agent runs without opening the raw terminal unless they need full debug detail.

---

## 2. Goals & Non-Goals

### 2.1 Goals

1. **Make agent execution understandable at a glance**  
   Show high-level steps such as Started, Running command, Modified files, Build succeeded, Tests failed, Waiting for approval, and Done.

2. **Reduce raw terminal dependence**  
   Users should be able to monitor most agent runs with the terminal collapsed.

3. **Support interactive approvals safely**  
   Approval cards must be bound to the active run and active prompt, and must prevent stale or risky approvals.

4. **Preserve performance**  
   Timeline parsing must be incremental, off-main-thread where practical, bounded in memory, and must not re-parse the full transcript on every PTY update.

5. **Use multi-signal event detection**  
   Prefer structured hooks, Workstation-owned markers, command lifecycle events, file watchers, and git status before falling back to raw terminal regex.

6. **Remain truthful and debuggable**  
   The timeline is a semantic overlay. The raw transcript remains the source of truth.

7. **Prepare for future multi-agent workflows**  
   The event model should work across Claude, Gemini, Codex, Antigravity, shell scripts, and Workstation-owned tools.

### 2.2 Non-Goals

1. Build a full terminal emulator inside the timeline.
2. Replace the existing raw terminal drawer.
3. Modify the core PTY launching architecture unless required for safe stdin writes.
4. Guarantee perfect parsing of every third-party agent log format.
5. Auto-approve high-risk or critical actions.
6. Persist every low-level event forever.
7. Render massive unbounded event lists in the Issue Detail Pane.

---

## 3. Product Principles

### 3.1 Timeline is Semantic; Terminal is Literal
The timeline summarizes execution state. It does not attempt to render ANSI colors, cursor movement, alternate screens, spinners, progress bars, or REPL UIs.

The raw terminal drawer remains the literal execution view and audit trail.

### 3.2 Structured Signals Beat Regex
The system must prefer high-confidence structured sources over heuristic parsing.

Event priority:

1. Native structured agent hooks or JSON events, when available.
2. Workstation-owned JSON markers emitted by wrappers/scripts.
3. Command lifecycle events from the runner.
4. File-system watcher events and git status snapshots.
5. Terminal regex fallback.
6. Low-confidence heuristics.

### 3.3 Approvals Must Be Safe by Default
Only active, high-confidence approval requests may send input back to a PTY. Unknown or stale prompts must never trigger automatic action.

### 3.4 Performance Cannot Regress
The timeline must not reintroduce the lag that terminal line-capping fixed. Parsing, grouping, and publishing must be incremental and bounded.

### 3.5 Raw Transcript Remains the Audit Source
Every semantic event should preserve enough source metadata to inspect the raw terminal or related log excerpt when debugging.

---

## 4. User Experience Overview

### 4.1 Default Compact Timeline
Location: **Issue Detail Pane**, below issue metadata and above longer description/run notes.

Compact mode shows:

- Latest 5 meaningful timeline events.
- Active approval card pinned prominently.
- Current agent status header.
- Quick actions: Pause, Cancel, Raw Log, Open Diff.
- Link/button: View Full Run.

Example:

```text
Claude Agent · Running · 02:14 elapsed
3 files changed · 6 commands · 1 build running

● Loaded issue context
● Created worktree
● Running command: xcodebuild
● Modified files: 3 files
⚠ Approval required: Apply proposed changes?

[Approve] [Reject] [Open Raw Log]
```

### 4.2 Full Timeline View
Location: Drawer, modal, or expanded run detail panel.

Full mode shows:

- Searchable/filterable event tree.
- Event grouping by phase.
- Command cards with duration/exit code/output preview.
- Problems panel.
- Changed files panel.
- Approval history.
- Raw Log tab.

### 4.3 Raw Terminal Drawer
The raw terminal remains available for:

- Debugging parser mistakes.
- Interacting with real terminal prompts.
- Viewing full command output.
- Handling complex REPL/TTY behavior.

---

## 5. Core User Stories

### 5.1 Monitor Agent Progress
As a user, I want to see what the agent is doing without opening the terminal, so I can trust the run and stay focused on the issue.

Acceptance:

- Timeline updates while terminal drawer is collapsed.
- Active event is visually obvious.
- User can open raw log from any run.

### 5.2 Approve an Agent Prompt
As a user, I want to approve or reject a waiting agent prompt from the timeline, so I do not need to scroll the terminal.

Acceptance:

- Approval card appears only for active prompts.
- Approve sends the correct input to the correct active run.
- Stale approval cards are disabled or removed.
- High/critical risk approvals require stronger confirmation.

### 5.3 Understand Build/Test Failures
As a user, I want build/test errors summarized into a Problems panel, so I can quickly understand what failed.

Acceptance:

- Swift compiler errors are extracted with file/line when possible.
- Build/test failures generate failure events.
- User can open raw log for full context.

### 5.4 Inspect Changed Files
As a user, I want to see what files the agent changed, so I can review impact quickly.

Acceptance:

- Timeline detects modified/created/deleted files using file watcher or git status where possible.
- Changed files are grouped and deduplicated.
- User can open diff or file path.

### 5.5 Keep Performance Smooth
As a user, I want long agent output to stay smooth, so the app remains usable during large builds/log streams.

Acceptance:

- 10,000+ lines do not freeze UI.
- Parser does not rebuild full event list repeatedly.
- Compact timeline renders a bounded number of views.

---

## 6. Information Architecture

### 6.1 Primary Surfaces

1. **Issue Detail Pane**  
   Compact timeline, active approval card, current run status.

2. **Run Console Drawer**  
   Full timeline, raw terminal, logs, command output, problems.

3. **Debug Panel**  
   Parser instrumentation and diagnostics.

### 6.2 Navigation

- Compact timeline -> View Full Run.
- Event card -> Expand details.
- Command card -> Show output / Copy command / Rerun where supported.
- Problem card -> Open file / Open raw log around error.
- Approval card -> Approve / Reject / Raw Terminal.

---

## 7. Technical Architecture

### 7.1 High-Level Architecture

```text
PTY Runner
  ↓ raw bytes
TerminalStreamBuffer
  ↓ decoded, sanitized TerminalLine batches
AgentTimelineIngestor
  ↓ event deltas
AgentTimelineStore
  ↓ published compact/full state
IssueDetailTimelineView / RunConsoleTimelineView

Parallel signals:
- Structured agent hooks
- Workstation JSON markers
- Command lifecycle events
- File-system watcher events
- Git status snapshots
```

### 7.2 Component Responsibilities

#### PTY Runner
Owns process launch, PTY fds, stdin writing, termination, and process lifecycle.

#### TerminalStreamBuffer
Owns:

- Byte decoding.
- Partial UTF-8 handling.
- Partial-line buffering.
- ANSI stripping for Clean mode.
- Line sequence assignment.
- UI-safe batching.

#### AgentTimelineIngestor
Owns:

- Incremental parsing.
- Event generation.
- Marker parsing.
- Regex fallback.
- Approval prompt detection.
- Event confidence assignment.

#### AgentTimelineStore
Owns:

- Event deduplication.
- Stable event identity.
- Grouping/folding.
- Compact/full state projection.
- Active approval state.
- Memory retention.

#### Timeline Views
Own:

- Visual rendering.
- Micro-animations.
- User actions.
- Approval controls.
- Raw log / diff navigation.

---

## 8. Source of Truth & Confidence Contract

The timeline is not the canonical execution log. It is a semantic overlay generated from multiple signals.

### 8.1 Raw Transcript
The raw transcript is the immutable audit trail for debugging. It should be persisted at process completion as already designed by the terminal optimization work.

### 8.2 Timeline Event Confidence
Every event must include:

- Source.
- Confidence.
- Stable key.
- Optional raw excerpt or raw location reference.

### 8.3 Confidence Rules

- High-confidence events may power actions and status changes.
- Medium-confidence events may be displayed and grouped.
- Low-confidence events must be display-only and visually treated as inferred.
- Regex and heuristic events should not trigger destructive or approval actions without confirmation from a stronger signal.

---

## 9. Data Models

### 9.1 Timeline Event Types

```swift
public enum TimelineEventType: String, Codable, Sendable {
    case started
    case phase
    case command
    case commandOutput
    case fileChange
    case build
    case test
    case problem
    case needsApproval
    case approvalResolved
    case paused
    case cancelled
    case done
}
```

### 9.2 Timeline Event Status

```swift
public enum TimelineEventStatus: String, Codable, Sendable {
    case queued
    case working
    case success
    case warning
    case failure
    case info
    case stale
}
```

### 9.3 Timeline Event Source

```swift
public enum TimelineEventSource: String, Codable, Sendable {
    case structuredHook
    case workstationMarker
    case commandLifecycle
    case fileWatcher
    case gitStatus
    case terminalRegex
    case heuristic
}
```

### 9.4 Timeline Event Confidence

```swift
public enum TimelineEventConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
}
```

### 9.5 Terminal Line

The parser should ingest logical lines, not arbitrary transcript string offsets.

```swift
public struct TerminalLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let runID: UUID
    public let sequence: Int64
    public let text: String
    public let timestamp: Date
    public let rawByteRangeStart: Int?
    public let rawByteRangeEnd: Int?
}
```

### 9.6 Agent Timeline Event

```swift
public struct AgentTimelineEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let sequence: Int64
    public let type: TimelineEventType
    public let title: String
    public let subtitle: String?
    public let timestamp: Date
    public var status: TimelineEventStatus
    public let source: TimelineEventSource
    public let confidence: TimelineEventConfidence
    public var rawExcerpt: String?
    public var rawLineStart: Int64?
    public var rawLineEnd: Int64?
    public var relatedFile: String?
    public var relatedCommand: String?
}
```

### 9.7 Command Run

```swift
public struct TimelineCommandRun: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let command: String
    public let workingDirectory: String?
    public let startedAt: Date
    public var endedAt: Date?
    public var exitCode: Int32?
    public var outputPreview: String?
    public var outputLineCount: Int
    public var status: TimelineEventStatus
}
```

### 9.8 Problem

```swift
public enum ProblemSeverity: String, Codable, Sendable {
    case notice
    case warning
    case error
}

public struct AgentRunProblem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let severity: ProblemSeverity
    public let message: String
    public let filePath: String?
    public let line: Int?
    public let column: Int?
    public let source: TimelineEventSource
    public let confidence: TimelineEventConfidence
    public let rawLine: Int64?
}
```

### 9.9 Approval Request

```swift
public enum ApprovalRiskLevel: String, Codable, Sendable {
    case low
    case medium
    case high
    case critical
}

public enum ApprovalState: String, Codable, Sendable {
    case active
    case responding
    case accepted
    case rejected
    case expired
    case stale
    case failedToSend
}

public struct AgentApprovalRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stableKey: String
    public let runID: UUID
    public let promptHash: String
    public let prompt: String
    public let proposedInput: String
    public let rejectInput: String
    public let riskLevel: ApprovalRiskLevel
    public let commandPreview: String?
    public let filePreview: [String]
    public let createdAt: Date
    public var expiresAt: Date?
    public var state: ApprovalState
}
```

---

## 10. Incremental Ingestion Contract

### 10.1 Parser Input
The parser must receive `TerminalLine` batches with monotonically increasing sequence numbers.

It must not parse the full transcript string on every update.

### 10.2 Parser State
The ingestor maintains per-run state:

```text
lastProcessedLineSequence
activeCommandRun
activePhase
activeApprovalRequest
recentContextWindow
seenStableKeys
```

### 10.3 Partial Input Handling
TerminalStreamBuffer is responsible for:

- Decoding bytes safely.
- Preserving incomplete UTF-8 sequences until complete.
- Preserving partial lines until newline or flush boundary.
- Stripping ANSI in Clean mode before regex matching.
- Normalizing carriage-return progress lines.

### 10.4 Event Delta Output
The ingestor emits event deltas:

```swift
public enum TimelineDelta: Sendable {
    case insert(AgentTimelineEvent)
    case update(stableKey: String, AgentTimelineEvent)
    case appendProblem(AgentRunProblem)
    case updateApproval(AgentApprovalRequest?)
    case group(stableKey: String)
}
```

### 10.5 Performance Targets

- Parser work per batch: target under 4 ms.
- Timeline store diff application: target under 2 ms.
- UI update frequency: coalesced, no per-byte/per-line publish storm.
- Compact timeline render count: latest 5 events plus active card.
- Full timeline default render count: latest 100 grouped events; older events folded.

---

## 11. Workstation Marker Format

### 11.1 Why Markers Exist
Terminal regex is fragile. Workstation-owned scripts and wrappers should emit structured markers for high-confidence events.

### 11.2 Preferred Marker Format
Use JSON line markers:

```text
::workstation-json::{"type":"group","title":"Build","runID":"..."}
::workstation-json::{"type":"command","command":"xcodebuild ...","cwd":"..."}
::workstation-json::{"type":"error","file":"Sources/App.swift","line":42,"column":17,"message":"Cannot find symbol"}
::workstation-json::{"type":"endgroup","title":"Build"}
```

### 11.3 Marker Rules

- Valid markers are high-confidence.
- Malformed markers are ignored by the timeline parser and preserved in Raw Log.
- Clean mode may hide valid markers after parsing.
- Raw mode must show original output.
- Marker payloads must be size-limited.
- Marker payloads must be parsed defensively.

### 11.4 Initial Marker Types

```swift
public enum WorkstationMarkerType: String, Codable, Sendable {
    case group
    case endgroup
    case command
    case commandEnd
    case fileChanged
    case problem
    case approval
    case buildProgress
    case testSummary
    case done
}
```

---

## 12. Event Detection Rules

### 12.1 Started
Sources:

- Process lifecycle.
- Structured hook.
- Workstation marker.
- First terminal line fallback.

Output:

- `Agent started`
- Agent name if known.
- Worktree path if known.

### 12.2 Command
Sources:

- Workstation marker.
- Command lifecycle.
- Terminal regex fallback.

Regex fallback examples:

```text
^\$\s+(.+)$
^>\s+(.+)$
Executing command:\s*(.+)$
CommandLine:\s*(.+)$
```

Command card tracks:

- command text
- cwd
- start time
- end time
- exit code
- output preview
- line count

### 12.3 File Change
Preferred sources:

- File watcher.
- Git status snapshot.
- Workstation marker.

Fallback examples:

```text
Created file file://...
modified:\s+(.+)
Changes made to:\s+(.+)
```

Grouping:

- Consecutive changes collapse into `Modified files (X)`.
- Full list appears in expanded view.

### 12.4 Build
Triggers:

```text
xcodebuild
swift build
** BUILD SUCCEEDED **
** BUILD FAILED **
CompileSwift
Ld
CodeSign
ProcessInfoPlistFile
```

Timeline output:

- `Building Workstation`
- stage subtitle such as `Compiling Swift`, `Linking`, `Code signing`
- final success/failure

### 12.5 Test
Triggers:

```text
swift test
xcodebuild test
Test Suite ... passed
Test Suite ... failed
Executed N tests
N tests passed
N tests failed
```

Timeline output:

- `Running tests`
- summary counts where possible

### 12.6 Problem
Patterns:

```text
error:
fatal error:
warning:
BUILD FAILED
Command failed
command not found
Permission denied
No such file or directory
path.swift:42:17: error: message
```

Problem extraction should attempt:

- file path
- line
- column
- severity
- message

### 12.7 Approval Prompt
Approval detection must be conservative.

Prompt patterns:

```text
[y/N]
[Y/n]
(y/n)
Do you want to continue?
Confirm
Approve
Proceed?
Allow
Deny
persetujuan
lanjutkan
setuju
```

An approval card is created only when:

- run is active
- prompt appears near the active output tail
- no active command has already exited past the prompt
- prompt is distinct from previous prompt hash
- risk classification is available or defaults safely

### 12.8 Done
Sources:

- Process exit code 0.
- Workstation marker.
- Agent-specific completion line.

Examples:

```text
completed the session
Closed Workstation-
BUILD SUCCEEDED
exit 0
```

---

## 13. Approval Safety Contract

### 13.1 Approval Binding
Every approval request must be bound to:

- runID
- promptHash
- createdAt timestamp
- optional active command stableKey

Before sending input, the UI must validate that the approval is still active.

### 13.2 Approval Invalidation
Approval is invalidated only when one of these happens:

1. Process exits.
2. runID changes.
3. Prompt hash changes.
4. User responds.
5. Timeout expires.
6. New distinct prompt is detected.
7. Command lifecycle confirms the process moved beyond the prompt.

New output alone must not automatically invalidate an approval, because some CLIs print spinners, warnings, or carriage-return updates while still waiting.

### 13.3 Approval Send Flow

```text
User clicks Approve
  ↓
Validate active runID + promptHash
  ↓
Set approval state = responding
  ↓
PTYProcessRegistry.writeInput(runID, proposedInput)
  ↓
If write succeeds: state = accepted until output confirms progress
If write fails: state = failedToSend and show Raw Terminal fallback
```

### 13.4 Approval Card UX
Low/Medium risk:

```text
[Approve] [Reject] [Raw Log]
```

High risk:

```text
[View Details]
[Approve Once - disabled until details viewed]
[Reject]
[Raw Terminal]
```

Critical risk:

```text
Type APPROVE to confirm
or complete manually in Raw Terminal
```

---

## 14. Risk Policy

### 14.1 Low Risk
Read-only actions:

- pwd
- ls
- cat
- rg
- grep
- git status
- git diff
- reading files inside workspace

### 14.2 Medium Risk
Workspace-local operations:

- editing files inside current workspace
- creating files inside current workspace
- local build/test commands
- formatting/linting files

### 14.3 High Risk
Potentially destructive or externally impactful operations:

- rm
- mv directories
- chmod/chown
- package install
- network calls
- git commit
- git push
- modifying config or secrets files

### 14.4 Critical Risk
Critical operations:

- sudo
- deleting worktrees
- destructive actions outside workspace
- accessing ~/.ssh
- accessing keychain
- reading credential/token stores
- touching `.env` values or secret files

### 14.5 Default Rule
Unknown actions must never default to low risk. Unknown commands default to medium or high depending on workspace boundary and command shape.

---

## 15. Privacy & Secret Redaction

Before storing or displaying `rawExcerpt`, `commandPreview`, `prompt`, or timeline subtitles, the system must apply redaction.

### 15.1 Redact

- API keys.
- Bearer tokens.
- Environment variable values.
- `.env` values.
- SSH keys.
- Access tokens.
- Home directory paths where not needed.

### 15.2 Display Policy

- Compact timeline should avoid full sensitive paths.
- Raw log remains available but should not be copied into timeline summaries without redaction.
- Approval cards for secret-related prompts should default to high or critical risk.

---

## 16. UI/UX Specification

### 16.1 Agent Status Header

Compact header:

```text
Claude Agent
Running · 02:14 elapsed · 3 files changed · 6 commands
```

States:

- Idle
- Starting
- Running
- Waiting for approval
- Paused
- Cancelling
- Failed
- Completed

### 16.2 Timeline Node Visuals

- Connector line: 1.5pt `WorkstationTheme.borderSoft`.
- Working node: pulsing accent ring.
- Success node: soft green checkmark.
- Warning node: amber warning circle.
- Failure node: subtle red alert triangle.
- Info/file node: neutral slate document icon.

### 16.3 Command Card

Collapsed:

```text
$ xcodebuild -project Workstation.xcodeproj
Running · 00:14
```

Completed:

```text
$ xcodebuild -project Workstation.xcodeproj
exit 0 · 21.4s · 1,284 lines folded
```

Actions:

- Show output.
- Copy command.
- Copy output preview.
- Open raw log around command.
- Rerun command where safe and supported.

### 16.4 Problems Panel

Displays:

```text
Problems Detected
1. Sources/App.swift:42:17
   Cannot find 'foo' in scope

2. Build failed
   xcodebuild exited with code 65
```

Actions:

- Open file.
- Copy problem.
- Open raw log around problem.

### 16.5 Changed Files Panel

Displays:

```text
Changed Files
M Sources/TerminalBuffer.swift
M Sources/RunConsoleView.swift
A Sources/AgentRunTimeline.swift
```

Actions:

- Open file.
- View diff.
- Revert file where supported.

### 16.6 Approval Card

```text
Approval Required
Agent is waiting for permission to proceed.
Prompt: Apply proposed implementation plan? [y/N]
Risk: Medium

[Approve] [Reject] [Raw Log]
```

High risk variant:

```text
High-Risk Approval Required
Command may modify files or perform external operations.

[View Details]
[Approve Once] [Reject] [Raw Terminal]
```

### 16.7 Motion Rules

- Use subtle micro-animation only for active node and active approval card.
- Respect reduced motion accessibility settings.
- Avoid continuous heavy animations in long lists.

---

## 17. Grouping & Retention

### 17.1 Grouping Rules

- Consecutive compile lines -> one Build event.
- Consecutive file changes -> one File Changes event.
- Consecutive warnings/errors -> Problems group.
- Repeated identical errors -> deduplicate.
- Long command output -> folded output preview.

### 17.2 Retention Rules

- Compact timeline: latest 5 meaningful events plus active approval.
- Full timeline: latest 100 grouped events by default.
- In-memory semantic event cap: 1,000 events per run.
- Older low-level events fold into summary nodes.
- Raw full transcript remains separate.

---

## 18. Agent Adapter Strategy

### 18.1 Base Universal Parser
Handles:

- commands
- exit codes
- build/test patterns
- compiler errors
- common prompts
- git status output

### 18.2 Agent-Specific Adapters
Adapters can add rules without changing the core parser.

Examples:

- Claude adapter: approval prompts, planning sections, tool-use summaries.
- Gemini adapter: plan/apply/test sections.
- Codex adapter: sandbox/approval wording and command execution lines.
- Antigravity adapter: Workstation-specific markdown actions or markers.

### 18.3 Adapter Contract

```swift
public protocol AgentTimelineAdapter: Sendable {
    var agentIdentifier: String { get }
    func ingest(line: TerminalLine, context: AgentTimelineContext) -> [TimelineDelta]
}
```

Adapters must not directly mutate UI state.

---

## 19. Implementation Plan

### Phase 1: Data Models & Store

Deliverables:

- `TerminalLine`
- `AgentTimelineEvent`
- `TimelineCommandRun`
- `AgentRunProblem`
- `AgentApprovalRequest`
- `AgentTimelineStore`
- stable key + dedup logic

Acceptance:

- Store can apply insert/update deltas without duplicates.
- Compact projection returns latest 5 meaningful events.

### Phase 2: TerminalLine Ingestion

Deliverables:

- TerminalStreamBuffer emits line batches.
- Partial-line and partial-UTF-8 safe handling.
- ANSI stripping for Clean mode.
- Sequence number tracking.

Acceptance:

- Parser receives complete logical lines.
- No full transcript parsing per update.

### Phase 3: Base Parser

Deliverables:

- command parser
- build/test parser
- problem parser
- approval prompt parser
- done/exit parser

Acceptance:

- Fixtures generate expected event deltas.
- No duplicate events across repeated flushes.

### Phase 4: Workstation JSON Markers

Deliverables:

- marker parser
- marker emitter helpers for run-app/Beads CLI where appropriate
- marker hiding in Clean mode

Acceptance:

- Valid markers produce high-confidence events.
- Malformed markers do not crash parser.

### Phase 5: Compact Timeline UI

Deliverables:

- `AgentRunTimelineCompactView`
- status header
- latest event list
- active approval card
- Raw Log action

Acceptance:

- Issue Detail Pane remains smooth.
- Timeline updates while terminal is collapsed.

### Phase 6: Interactive Approvals

Deliverables:

- approval state machine
- risk classification
- write input flow
- high/critical risk confirmation UI

Acceptance:

- Approval sends input only to active run.
- Stale prompt cannot be approved.
- Write failures display fallback.

### Phase 7: Full Run View

Deliverables:

- searchable full timeline
- command cards
- problems panel
- changed files panel
- raw log tab

Acceptance:

- User can inspect any major event.
- Raw log remains one click away.

### Phase 8: File/Git Verification

Deliverables:

- file watcher integration
- git status snapshot integration
- changed files grouping

Acceptance:

- File changes are verified where possible.
- Terminal-only file change events are lower confidence.

### Phase 9: Instrumentation & Hardening

Deliverables:

- parser timing metrics
- event count metrics
- approval lifecycle logs
- debug panel fields
- redaction tests

Acceptance:

- Parser batch time visible in debug panel.
- No UI stutter on long logs.

---

## 20. Test Plan

### 20.1 Fixture Matrix

Required saved fixtures:

1. Claude approval prompt.
2. Gemini plan + file edit + command execution.
3. Codex sandbox/approval output.
4. Antigravity/Workstation issue closure output.
5. xcodebuild success.
6. xcodebuild failure with Swift compiler error.
7. swift test success.
8. swift test failure.
9. git status changed files.
10. npm install noisy output.
11. ANSI-colored output.
12. Carriage-return progress output.
13. Malformed UTF-8 chunk.
14. Chunk split mid-line.
15. Chunk split mid-ANSI sequence.
16. Indonesian approval prompt.
17. Duplicate flush of same lines.
18. Long 10,000+ line transcript.
19. Secret-looking token in output.
20. High-risk command prompt.

### 20.2 Unit Tests

- Marker parsing.
- Regex fallback parsing.
- Stable key generation.
- Deduplication.
- Approval prompt detection.
- Approval invalidation.
- Risk classification.
- Redaction.

### 20.3 Integration Tests

- Launch agent run.
- Receive PTY output.
- Generate timeline events.
- Display compact timeline.
- Approve prompt through PTY input.
- Confirm raw terminal continues correctly.

### 20.4 Performance Tests

- 10,000+ lines under sustained streaming.
- 1,000 semantic events grouped/folded.
- High-frequency output bursts.
- Long lines.
- ANSI-heavy output.

Targets:

- Parser batch under 4 ms average.
- Store delta application under 2 ms average.
- No unbounded event rendering.
- No main-thread transcript parsing.

---

## 21. Acceptance Criteria

1. Timeline updates while raw terminal drawer is collapsed.
2. Issue Detail Pane shows latest 5 meaningful events and current agent state.
3. Raw transcript remains accessible and unchanged as audit trail.
4. Parser ingests incremental `TerminalLine` batches, not full transcript strings.
5. Repeated flushes do not duplicate timeline events.
6. Approval card appears only for active prompts.
7. Approval button validates runID and promptHash before sending input.
8. Stale approvals are disabled or removed.
9. High-risk approvals require expanded detail view.
10. Critical-risk approvals require typed confirmation or Raw Terminal handoff.
11. Build/test failures are grouped into Problems.
12. File changes are grouped and verified by watcher/git where possible.
13. ANSI/control sequences do not leak into Clean timeline mode.
14. Parser tolerates malformed UTF-8, partial lines, and split chunks.
15. Timeline remains smooth with 10,000+ lines of raw output.
16. Secrets are redacted from timeline summaries and command previews.
17. Low-confidence heuristic events are display-only.
18. Workstation JSON markers produce high-confidence events.
19. Malformed markers do not crash parser.
20. User can always open Raw Log from the timeline.

---

## 22. Failure Modes & Mitigations

### 22.1 Parser Misclassifies Output
Mitigation:

- Mark regex events as medium/low confidence.
- Keep raw log available.
- Prefer structured signals.

### 22.2 Approval Card Becomes Stale
Mitigation:

- Bind to runID and promptHash.
- Use explicit approval state machine.
- Validate before write.

### 22.3 User Approves Wrong Run
Mitigation:

- Run-bound PTY input API.
- Active run validation.
- Disable controls for terminated or inactive runs.

### 22.4 Timeline Leaks Secrets
Mitigation:

- Redact before display/storage.
- Treat secret-related commands as high/critical risk.

### 22.5 Timeline Reintroduces Lag
Mitigation:

- Incremental line ingestion.
- Bounded render lists.
- Event grouping.
- Off-main-thread parsing where possible.

### 22.6 Third-Party Agent Format Changes
Mitigation:

- Structured hooks/markers first.
- Adapter architecture.
- Regex fallback only.
- Raw transcript remains source of truth.

---

## 23. Open Questions

1. Should the compact timeline appear for all issues or only the selected issue with an active run?
2. Should approval cards be pinned top or bottom of the Issue Detail Pane?
3. Should high-risk approvals require viewing diff, viewing command details, or both?
4. Should final timeline summaries be persisted alongside transcript files?
5. Should Workstation JSON markers be hidden from raw terminal output or only from Clean mode?
6. Should the file watcher run for every active run or only when agent execution starts?
7. Should the user be able to disable timeline inference and use only markers/hooks?

---

## 24. MVP Definition

The MVP is considered complete when:

1. Active agent run shows compact timeline in Issue Detail Pane.
2. Timeline displays Started, Command, Build/Test, Problem, File Change, Approval, Done events.
3. Parser uses incremental `TerminalLine` batches.
4. Approval card can send `y\n` or `n\n` safely to the active PTY run.
5. Approval validation prevents stale or wrong-run input.
6. Raw terminal remains available.
7. Build/test errors are summarized.
8. 10,000-line logs do not degrade UI responsiveness.

---

## 25. Future Enhancements

1. Real terminal emulator mode using a dedicated terminal component.
2. Multi-agent tabs and concurrent run comparison.
3. Session replay timeline.
4. AI-generated run summary after completion.
5. Automatic PR/commit summary generation.
6. Diff review directly inside timeline.
7. Restart from failed step.
8. Agent run analytics.
9. Notification when approval is waiting.
10. Policy editor for approval risk rules.

