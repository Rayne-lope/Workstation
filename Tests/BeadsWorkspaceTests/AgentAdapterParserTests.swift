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

    @Test("tool_use then tool_result preserves title and flips status")
    func toolLifecycle() {
        let runID = UUID()
        let parser = OpenCodeStreamParser(runID: runID, modelLabel: "kimi-k2.5")
        let use = parser.parse(line: #"{"type":"tool_use","id":"x1","tool":"read_file","input":{"file_path":"/a/Baz.go"}}"#)
        #expect(use.count == 1)
        guard case .insert(let card) = use[0] else { Issue.record("expected insert"); return }
        #expect(card.title == "Reading Baz.go")

        let done = parser.parse(line: #"{"type":"tool_result","id":"x1","exit_code":0}"#)
        guard case .update(_, let updated) = done.first else { Issue.record("expected update"); return }
        #expect(updated.title == "Reading Baz.go")
        #expect(updated.status == .success)
    }

    @Test("error event becomes a problem")
    func errorProblem() {
        let parser = OpenCodeStreamParser(runID: UUID(), modelLabel: "glm-5")
        let deltas = parser.parse(line: #"{"type":"error","message":"boom"}"#)
        guard case .appendProblem(let problem) = deltas.first else {
            Issue.record("expected problem"); return
        }
        #expect(problem.message == "boom")
        #expect(problem.severity == .error)
    }
}

@Suite("GeminiTranscriptParser")
struct GeminiTranscriptParserTests {

    @Test("PLANNER_RESPONSE tool call maps to a file card")
    func plannerToolCall() {
        let runID = UUID()
        let parser = GeminiTranscriptParser(runID: runID)
        let obj: [String: Any] = [
            "step_index": 5,
            "type": "PLANNER_RESPONSE",
            "tool_calls": [["name": "read_file", "args": ["file_path": "/x/Qux.ts"]]]
        ]
        let line = String(data: try! JSONSerialization.data(withJSONObject: obj), encoding: .utf8)!
        let deltas = writeAndRead(parser: parser, lines: [line])
        guard case .insert(let event) = deltas.first else {
            Issue.record("expected insert"); return
        }
        #expect(event.title == "Reading Qux.ts")
        #expect(event.relatedFile == "/x/Qux.ts")
    }

    @Test("duplicate step_index is ignored")
    func dedupByStepIndex() {
        let runID = UUID()
        let parser = GeminiTranscriptParser(runID: runID)
        let obj: [String: Any] = [
            "step_index": 1,
            "type": "RUN_COMMAND",
            "tool_calls": [["name": "run_command", "args": ["command": "ls"]]]
        ]
        let line = String(data: try! JSONSerialization.data(withJSONObject: obj), encoding: .utf8)!
        let first = writeAndRead(parser: parser, lines: [line])
        let second = writeAndRead(parser: parser, lines: [line])
        #expect(first.count == 1)
        #expect(second.isEmpty)
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
