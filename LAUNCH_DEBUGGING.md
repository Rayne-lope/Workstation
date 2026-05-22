# Terminal Launch & Agent Claiming Resiliency Guide

This document preserves the context, architectural decisions, and debugging history of two critical bugs resolved in the Beads Kanban App agent launching infrastructure. Future AI agents working on this codebase **MUST** read and adhere to the guidelines documented here to prevent regression.

---

## 1. Silent Terminal Launch Failure (AppleScript & macOS Security)

### The Problem
When clicking **Run Agent** or **Run in Worktree**, the app recorded the state as `Terminal Opened` in the activity/console panels, but **no Terminal window actually opened**. This occurred due to two distinct silent failures:
1. **Asynchronous Process Swallowing**: The app used `Process.run()` to execute `osascript` asynchronously. If the AppleScript compilation or execution failed (e.g. syntax errors), the error was swallowed silently.
2. **AppleScript Quote & Backslash Escaping**: AppleScript string literals require backslashes and double quotes to be escaped. If a shell command already contained escapes (e.g., `\"`), they were corrupted during the naive AppleScript escaping step, triggering syntax error `-2741` in `osascript`.
3. **macOS Automation Sandbox Restrictions**: Modern macOS blocks apps from controlling Terminal.app via AppleScript/osascript unless the host app specifies `NSAppleEventsUsageDescription` in its `Info.plist`.

### The Solution

#### A. Capturing `osascript` Errors Robustly
We updated [TerminalLauncher.swift](file:///Users/apple/Programming/Projects/Personal/Workstation/Sources/BeadsWorkspace/TerminalLauncher.swift) to execute synchronously, capture `standardError` using a `Pipe`, and inspect the process exit code:

```swift
private static func run(appleScript: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", appleScript]
    
    let errorPipe = Pipe()
    process.standardError = errorPipe
    
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        throw LaunchError.launchFailed(error.localizedDescription)
    }
    
    if process.terminationStatus != 0 {
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorString = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        throw LaunchError.launchFailed("osascript failed with exit code \(process.terminationStatus): \(errorString)")
    }
}
```

#### B. Robust Double-Escaping (Backslash First)
In AppleScript, backslashes (`\`) must be escaped to `\\` **before** double-quotes (`"`) are escaped to `\"`. This preserves nested quotes and backslashes in shell commands so that they arrive intact in Terminal.app:

```swift
static func escapeForAppleScript(_ string: String) -> String {
    string.replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"")
}
```

> [!NOTE]
> This ensures that a command like `echo "Fix \"bug\""` gets translated to AppleScript as `"echo \\\"Fix \\\\\\\"bug\\\\\\\"\\\""`, allowing the shell in Terminal to receive the original `echo "Fix \"bug\""` command with perfectly preserved inner quotes.

#### C. macOS App Entitlements & Permissions
We added `INFOPLIST_KEY_NSAppleEventsUsageDescription` to [project.yml](file:///Users/apple/Programming/Projects/Personal/Workstation/project.yml) to trigger the native macOS automation dialog:

```yaml
INFOPLIST_KEY_NSAppleEventsUsageDescription: "This application needs permission to control Terminal to run local agent tasks."
```

---

## 2. Agent Claiming Deadlock

### The Problem
When switching an issue's assignment between different agents (e.g., from `claude` to `gemini`) and relaunching, the launch would fail silently.
* **Beads CLI Claim Behavior**: `bd update <id> --claim` is extremely strict. If an issue is already claimed or in the `in_progress` status by the same/different assignee, the CLI throws an error (e.g. `Error claiming: issue already claimed by X`).
* **Original Flow Coordinator Block**: The app's `prepareLaunchSession` did not tolerate claim failures; it would return `nil` and abort the launch if `claim` failed for any issue whose status was not already `"in_progress"`. Even when the assignee already matched, the launch was blocked in an infinite loop.

### The Solution
We implemented a highly resilient, fail-soft claim strategy in [AgentLaunchFlowCoordinator.swift](file:///Users/apple/Programming/Projects/Personal/Workstation/Sources/BeadsWorkspace/AgentLaunchFlowCoordinator.swift) that prevents database synchronization failures or strict CLI claims from blocking the main developer action:

```swift
if profile.shouldClaimIssue {
    guard let issueStore else { return nil }
    let claimed = await issueStore.claim(id: issue.id, assignee: profile.claimAssigneeToken)
    if !claimed {
        // If claim fails, it could be because the issue is already claimed or in_progress.
        // If already assigned to the correct agent, we can safely proceed.
        if issue.assignee == profile.claimAssigneeToken {
            if issue.status != "in_progress" {
                await issueStore.update(
                    id: issue.id,
                    UpdateIssueInput(status: "in_progress")
                )
            }
        } else if issue.status == "in_progress" || issue.status == "open" || issue.status == "ready" {
            // Fall back to a plain update of assignee and status.
            // Only set status to in_progress if it is not already in_progress.
            let statusUpdate = issue.status == "in_progress" ? nil : "in_progress"
            await issueStore.update(
                id: issue.id,
                UpdateIssueInput(
                    status: statusUpdate,
                    assignee: profile.claimAssigneeToken
                )
            )
            
            // If the plain update also fails and the original status was not in_progress,
            // return nil to respect the strict failure behavior expected by tests.
            if issueStore.errorMessage != nil && issue.status != "in_progress" {
                return nil
            }
        } else {
            return nil
        }
    }
    if clearHumanReviewLabel {
        guard await issueStore.clearHumanReview(id: issue.id) else {
            return nil
        }
    }
}
```

---

## 3. Best Practices for Future Work
* **Always run AppleScript with synchronous exit codes**: Never run `osascript` in a completely fire-and-forget asynchronous process without checking the error stream. Always capture exit codes.
* **Keep Database Updates Fail-Soft**: App workflow states should be tolerant. If a metadata update on `bd` fails but the issue is already assigned correctly, do not halt the user's workflow.
* **Verify with Quality Gates**: Before completing your work session, run quality gates from the active workspace directory:
  ```bash
  swift test
  xcodebuild -project Workstation.xcodeproj -scheme Workstation -configuration Debug build
  ```
