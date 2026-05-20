import Testing
@testable import BeadsWorkspace

@Suite("BeadsAppError")
struct BeadsAppErrorTests {
    @Test("Each error case exposes user-facing copy and recovery guidance")
    func eachErrorCaseHasMessageAndRecoverySuggestion() {
        let cases: [BeadsAppError] = [
            .bdNotInstalled,
            .invalidProjectFolder,
            .beadsNotInitialized,
            .commandFailed(command: "bd list --json", stderr: "boom", exitCode: 1),
            .jsonDecodeFailed(raw: "{\"id\":\"bd-1\"}"),
            .timeout(command: "bd list --json"),
            .permissionDenied(path: "/tmp/project")
        ]

        for error in cases {
            #expect(!error.userFacingMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!(error.recoverySuggestion ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
