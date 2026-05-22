import Foundation
import Testing
@testable import BeadsWorkspace

@Suite("TerminalLauncher")
struct TerminalLauncherTests {

    @Test("makeCDCommand returns correct cd with single-quoted path")
    func makeCDCommand() throws {
        let url = URL(fileURLWithPath: "/Users/me/project")
        let cd = try TerminalLauncher.makeCDCommand(projectURL: url)
        #expect(cd == "cd '/Users/me/project'")
    }

    @Test("makeCDCommand escapes single quotes in path")
    func makeCDCommandWithSingleQuotes() throws {
        let url = URL(fileURLWithPath: "/Users/me/it's a project")
        let cd = try TerminalLauncher.makeCDCommand(projectURL: url)
        #expect(cd == "cd '/Users/me/it'\\''s a project'")
    }

    @Test("makeCDCommand throws when path is empty")
    func makeCDCommandThrowsOnEmptyPath() {
        // A file URL with no path components has an empty path
        let url = URL(string: "file:")!
        #expect(url.path.isEmpty)
        #expect(throws: TerminalLauncher.LaunchError.self) {
            try TerminalLauncher.makeCDCommand(projectURL: url)
        }
    }

    @Test("terminalScript wraps command in AppleScript tell block")
    func terminalScriptStructure() {
        let script = TerminalLauncher.terminalScript(command: "echo hello")
        #expect(script.contains("tell application \"Terminal\""))
        #expect(script.contains("activate"))
        #expect(script.contains("do script \"echo hello\""))
        #expect(script.contains("end tell"))
    }

    @Test("escapeForAppleScript escapes double quotes only")
    func escapeForAppleScriptEscapesQuotes() {
        let escaped = TerminalLauncher.escapeForAppleScript("say \"hi\"")
        #expect(escaped == "say \\\"hi\\\"")
    }

    @Test("escapeForAppleScript preserves shell backslash escapes")
    func escapeForAppleScriptPreservesShellEscapes() {
        // Shell command already contains \" (escaped quotes)
        let escaped = TerminalLauncher.escapeForAppleScript("echo \"Fix \\\"bug\\\"\"")
        // AppleScript should only escape the outer double quotes,
        // leaving the inner \" intact so the shell receives proper escapes.
        #expect(escaped == "echo \\\"Fix \\\\\"bug\\\\\"\\\"")
    }

    @Test("quoteForShell wraps path in single quotes")
    func quoteForShellBasic() {
        let quoted = TerminalLauncher.quoteForShell("/Users/me/project")
        #expect(quoted == "'/Users/me/project'")
    }

    @Test("quoteForShell escapes embedded single quotes")
    func quoteForShellEscapesSingleQuotes() {
        let quoted = TerminalLauncher.quoteForShell("/Users/me/it's here")
        #expect(quoted == "'/Users/me/it'\\''s here'")
    }

    @Test("terminalScript handles commands with newlines")
    func terminalScriptWithNewlines() {
        let script = TerminalLauncher.terminalScript(command: "line1\nline2")
        #expect(script.contains("do script \"line1\nline2\""))
    }
}
