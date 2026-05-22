import Foundation
import Testing
@testable import BeadsWorkspace

@MainActor
@Suite("CopilotTranscriptStore")
struct CopilotTranscriptStoreTests {
    
    private func makeStore() -> (CopilotTranscriptStore, URL) {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("copilot-transcript-tests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = baseURL.appendingPathComponent("copilot-transcripts.json")
        let store = CopilotTranscriptStore(fileURL: fileURL)
        return (store, fileURL)
    }

    @Test("save and load transcripts per issue ID")
    func saveAndLoadTranscripts() {
        let (store, fileURL) = makeStore()
        let issueID = "Workstation-90v"
        
        let m1 = CopilotConversationMessage(role: .user, text: "How do I resize a panel?")
        let m2 = CopilotConversationMessage(role: .assistant, text: "Drag the panel border.")
        
        store.save(messages: [m1, m2], forIssueID: issueID)
        
        #expect(store.messages(forIssueID: issueID).count == 2)
        #expect(store.messages(forIssueID: issueID)[0].text == "How do I resize a panel?")
        #expect(store.messages(forIssueID: issueID)[1].text == "Drag the panel border.")
        
        // Reload from file system
        let reloaded = CopilotTranscriptStore(fileURL: fileURL)
        #expect(reloaded.messages(forIssueID: issueID).count == 2)
        #expect(reloaded.messages(forIssueID: issueID)[0].text == "How do I resize a panel?")
        #expect(reloaded.messages(forIssueID: issueID)[1].text == "Drag the panel border.")
    }

    @Test("clear transcripts for a single issue ID")
    func clearTranscriptsForIssue() {
        let (store, _) = makeStore()
        let issueA = "Issue-A"
        let issueB = "Issue-B"
        
        store.save(messages: [CopilotConversationMessage(role: .user, text: "A")], forIssueID: issueA)
        store.save(messages: [CopilotConversationMessage(role: .user, text: "B")], forIssueID: issueB)
        
        store.clear(forIssueID: issueA)
        
        #expect(store.messages(forIssueID: issueA).isEmpty)
        #expect(store.messages(forIssueID: issueB).count == 1)
    }

    @Test("clearAll transcripts")
    func clearAllTranscripts() {
        let (store, _) = makeStore()
        let issueA = "Issue-A"
        let issueB = "Issue-B"
        
        store.save(messages: [CopilotConversationMessage(role: .user, text: "A")], forIssueID: issueA)
        store.save(messages: [CopilotConversationMessage(role: .user, text: "B")], forIssueID: issueB)
        
        store.clearAll()
        
        #expect(store.messages(forIssueID: issueA).isEmpty)
        #expect(store.messages(forIssueID: issueB).isEmpty)
    }
}
