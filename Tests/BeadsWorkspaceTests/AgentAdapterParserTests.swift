import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("ClaudeStreamParser")
struct ClaudeStreamParserTests {

    @Test("init system event emits a started card")
    func systemInit() {
        let runID = UUID()
        let parser = ClaudeStreamParser(runID: runID)
        let deltas = parser.parse(line: #"{"type":"system","subtype":"init","session_id":"abc"}"#)
        #expect(deltas.count == 1)
        guard case .insert(let event) = deltas[0] else {
            Issue.record("expected insert"); return
        }
        #expect(event.type == .started)
        #expect(event.source == .structuredHook)
        #expect(event.confidence == .high)
    }

    @Test("Read tool_use produces a file card with the filename")
    func readToolUse() {
        let runID = UUID()
        let parser = ClaudeStreamParser(runID: runID)
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/proj/Sources/Foo.swift"}}]}}"#
        let deltas = parser.parse(line: line)
        #expect(deltas.count == 1)
        guard case .insert(let event) = deltas[0] else {
            Issue.record("expected insert"); return
        }
        #expect(event.type == .fileChange)
        #expect(event.title == "Reading Foo.swift")
        #expect(event.relatedFile == "/proj/Sources/Foo.swift")
        #expect(event.status == .working)
    }

    @Test("tool_result preserves the original card title and only flips status")
    func toolResultPreservesTitle() {
        let runID = UUID()
        let parser = ClaudeStreamParser(runID: runID)
        _ = parser.parse(line: #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Edit","input":{"file_path":"/proj/Bar.swift"}}]}}"#)
        let resultLine = #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":false}]}}"#
        let deltas = parser.parse(line: resultLine)
        #expect(deltas.count == 1)
        guard case .update(let stableKey, let event) = deltas[0] else {
            Issue.record("expected update"); return
        }
        #expect(stableKey == "claude-tool-\(runID)-t1")
        // The key hardening: title is NOT clobbered to a generic "Tool completed".
        #expect(event.title == "Editing Bar.swift")
        #expect(event.relatedFile == "/proj/Bar.swift")
        #expect(event.status == .success)
    }

    @Test("tool_result with is_error marks the card as failure")
    func toolResultError() {
        let runID = UUID()
        let parser = ClaudeStreamParser(runID: runID)
        _ = parser.parse(line: #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t9","name":"Bash","input":{"command":"swift test"}}]}}"#)
        let deltas = parser.parse(line: #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t9","is_error":true}]}}"#)
        guard case .update(_, let event) = deltas.first else {
            Issue.record("expected update"); return
        }
        #expect(event.status == .failure)
        #expect(event.title == "$ swift test")
    }

    @Test("result event emits done exactly once")
    func resultDoneOnce() {
        let runID = UUID()
        let parser = ClaudeStreamParser(runID: runID)
        let first = parser.parse(line: #"{"type":"result","subtype":"success","is_error":false}"#)
        #expect(first.count == 1)
        guard case .insert(let event) = first[0] else {
            Issue.record("expected insert"); return
        }
        #expect(event.type == .done)
        #expect(event.status == .success)
        // A subsequent finish() must not double-emit.
        let again = parser.finish(exitCode: 0)
        #expect(again.isEmpty)
    }

    @Test("error result surfaces the reason on the failure card")
    func errorResultDetail() {
        let parser = ClaudeStreamParser(runID: UUID())
        let line = #"{"type":"result","subtype":"success","is_error":true,"result":"Failed to authenticate. API Error: 401 Invalid authentication credentials"}"#
        let deltas = parser.parse(line: line)
        guard case .insert(let event) = deltas.first else {
            Issue.record("expected insert"); return
        }
        #expect(event.title == "Run failed")
        #expect(event.subtitle?.contains("401") == true)
        #expect(event.status == .failure)
    }

    @Test("unknown/garbage lines are ignored, not fatal")
    func garbageIgnored() {
        let parser = ClaudeStreamParser(runID: UUID())
        #expect(parser.parse(line: "not json").isEmpty)
        #expect(parser.parse(line: #"{"type":"unknown_event"}"#).isEmpty)
        #expect(parser.parse(line: "").isEmpty)
    }
}

@Suite("OpenCodeStreamParser")
struct OpenCodeStreamParserTests {

    @Test("completed tool_use part becomes a success card")
    func completedToolUse() {
        let runID = UUID()
        let parser = OpenCodeStreamParser(runID: runID, modelLabel: "kimi-k2.5")
        let line = #"{"type":"tool_use","timestamp":1,"sessionID":"s1","part":{"type":"tool","tool":"read","callID":"x1","state":{"status":"completed","input":{"filePath":"/a/Baz.go"}}}}"#
        let deltas = parser.parse(line: line)
        #expect(deltas.count == 1)
        guard case .insert(let card) = deltas[0] else { Issue.record("expected insert"); return }
        #expect(card.title == "Reading Baz.go")
        #expect(card.relatedFile == "/a/Baz.go")
        #expect(card.status == .success)
        #expect(card.stableKey == "opencode-tool-\(runID)-x1")
    }

    @Test("errored tool_use part becomes a failure card")
    func erroredToolUse() {
        let parser = OpenCodeStreamParser(runID: UUID(), modelLabel: "kimi-k2.5")
        let line = #"{"type":"tool_use","timestamp":1,"sessionID":"s1","part":{"type":"tool","tool":"bash","callID":"x2","state":{"status":"error","input":{"command":"swift test"}}}}"#
        let deltas = parser.parse(line: line)
        guard case .insert(let card) = deltas.first else { Issue.record("expected insert"); return }
        #expect(card.title == "$ swift test")
        #expect(card.status == .failure)
        #expect(card.relatedCommand == "swift test")
    }

    @Test("error event becomes a problem")
    func errorProblem() {
        let parser = OpenCodeStreamParser(runID: UUID(), modelLabel: "glm-5")
        let deltas = parser.parse(line: #"{"type":"error","timestamp":1,"sessionID":"s1","error":{"name":"ProviderError","data":{"message":"boom"}}}"#)
        guard case .appendProblem(let problem) = deltas.first else {
            Issue.record("expected problem"); return
        }
        #expect(problem.message == "boom")
        #expect(problem.severity == .error)
    }

    @Test("text and step events are ignored")
    func textIgnored() {
        let parser = OpenCodeStreamParser(runID: UUID(), modelLabel: "kimi-k2.5")
        #expect(parser.parse(line: #"{"type":"text","timestamp":1,"sessionID":"s1","part":{"type":"text","text":"hi"}}"#).isEmpty)
        #expect(parser.parse(line: #"{"type":"step_start","timestamp":1,"sessionID":"s1","part":{}}"#).isEmpty)
        #expect(parser.parse(line: #"{"type":"step_finish","timestamp":1,"sessionID":"s1","part":{}}"#).isEmpty)
    }
}

@Suite("GeminiTranscriptParser")
struct GeminiTranscriptParserTests {

    @Test("PLANNER_RESPONSE view_file maps to a file card with decoded args")
    func plannerToolCall() {
        let runID = UUID()
        let parser = GeminiTranscriptParser(runID: runID)
        // agy JSON-encodes every arg value, hence the embedded quotes.
        let line = #"{"step_index":5,"type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"view_file","args":{"AbsolutePath":"\"/x/Qux.ts\"","toolAction":"\"Reading Qux.ts\""}}]}"#
        let deltas = writeAndRead(parser: parser, lines: [line])
        guard case .insert(let event) = deltas.first else {
            Issue.record("expected insert"); return
        }
        #expect(event.type == .fileChange)
        #expect(event.title == "Reading Qux.ts")
        #expect(event.relatedFile == "/x/Qux.ts")
        #expect(event.status == .success)
    }

    @Test("run_command card uses the decoded CommandLine")
    func runCommandCard() {
        let parser = GeminiTranscriptParser(runID: UUID())
        let line = #"{"step_index":3,"type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"run_command","args":{"CommandLine":"\"swift test\"","Cwd":"\"/proj\""}}]}"#
        let deltas = writeAndRead(parser: parser, lines: [line])
        guard case .insert(let event) = deltas.first else {
            Issue.record("expected insert"); return
        }
        #expect(event.type == .command)
        #expect(event.title == "$ swift test")
        #expect(event.relatedCommand == "swift test")
    }

    @Test("duplicate step_index with same status is ignored")
    func dedupByStepIndex() {
        let runID = UUID()
        let parser = GeminiTranscriptParser(runID: runID)
        let line = #"{"step_index":1,"type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"run_command","args":{"CommandLine":"\"ls\""}}]}"#
        let first = writeAndRead(parser: parser, lines: [line])
        let second = writeAndRead(parser: parser, lines: [line])
        #expect(first.count == 1)
        #expect(second.isEmpty)
    }

    @Test("RUNNING then DONE re-emits the card as an update, keeping its key")
    func runningToDoneUpdates() {
        let parser = GeminiTranscriptParser(runID: UUID())
        let running = #"{"step_index":2,"type":"PLANNER_RESPONSE","status":"RUNNING","tool_calls":[{"name":"run_command","args":{"CommandLine":"\"make build\""}}]}"#
        let done = #"{"step_index":2,"type":"PLANNER_RESPONSE","status":"DONE","tool_calls":[{"name":"run_command","args":{"CommandLine":"\"make build\""}}]}"#
        let first = writeAndRead(parser: parser, lines: [running])
        guard case .insert(let started) = first.first else {
            Issue.record("expected insert"); return
        }
        #expect(started.status == .working)
        let second = writeAndRead(parser: parser, lines: [done])
        guard case .update(let stableKey, let finished) = second.first else {
            Issue.record("expected update"); return
        }
        #expect(stableKey == started.stableKey)
        #expect(finished.status == .success)
        #expect(finished.sequence == started.sequence)
    }

    @Test("ERROR_MESSAGE becomes a problem")
    func errorMessageProblem() {
        let parser = GeminiTranscriptParser(runID: UUID())
        let line = #"{"step_index":7,"type":"ERROR_MESSAGE","status":"DONE","content":"model quota exceeded"}"#
        let deltas = writeAndRead(parser: parser, lines: [line])
        guard case .appendProblem(let problem) = deltas.first else {
            Issue.record("expected problem"); return
        }
        #expect(problem.message == "model quota exceeded")
    }

    @Test("tool result steps are skipped (tool_calls already made the card)")
    func resultStepsSkipped() {
        let parser = GeminiTranscriptParser(runID: UUID())
        let lines = [
            #"{"step_index":4,"type":"VIEW_FILE","status":"DONE","content":"File Path: `file:///x/A.md`"}"#,
            #"{"step_index":5,"type":"RUN_COMMAND","status":"DONE","content":"The command completed successfully."}"#,
            #"{"step_index":6,"type":"CODE_ACTION","status":"DONE","content":"Created file file:///x/B.md"}"#
        ]
        #expect(writeAndRead(parser: parser, lines: lines).isEmpty)
    }

    /// Helper: writes JSONL lines to a temp file and runs them through readNewEntries.
    private func writeAndRead(parser: GeminiTranscriptParser, lines: [String]) -> [TimelineDelta] {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gemini-test-\(UUID().uuidString).jsonl")
        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        var offset = 0
        return parser.readNewEntries(from: url, byteOffset: &offset)
    }
}

@Suite("LineBuffer")
struct LineBufferTests {

    @Test("splits complete lines and holds partial remainder")
    func partialLines() {
        let buffer = LineBuffer()
        let first = buffer.append(Data(#"{"a":1}"# .utf8))
        #expect(first.isEmpty) // no newline yet
        let second = buffer.append(Data("\n{\"b\":2}".utf8))
        #expect(second == [#"{"a":1}"#])
        #expect(buffer.flush() == #"{"b":2}"#)
    }

    @Test("multiple lines in one chunk")
    func multipleLines() {
        let buffer = LineBuffer()
        let lines = buffer.append(Data("one\ntwo\nthree\n".utf8))
        #expect(lines == ["one", "two", "three"])
        #expect(buffer.flush() == nil)
    }
}
