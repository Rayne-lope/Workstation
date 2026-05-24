import Foundation

public final class FallbackRuleRegistry: Sendable {
    public static let defaultInstruction = "The previous command was denied by the user, but this is not a request to stop the task. Skip that command and continue with a safe fallback. Do not retry the denied command unless the user explicitly asks."
    
    public static func instruction(for commandPreview: String?) -> String {
        guard let command = commandPreview?.trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty else {
            return defaultInstruction
        }
        
        let lower = command.lowercased()
        
        // 1. git push origin --delete
        if lower.contains("git push") && lower.contains("--delete") {
            return "Remote branch deletion was rejected. Do not retry. Continue local housekeeping, record that remote cleanup was skipped, run verification, and commit local changes if needed."
        }
        
        // 2. git push
        if lower.contains("git push") {
            return "Remote push was rejected. Prepare local commit and tell the user manual push is needed."
        }
        
        // 3. rm / destructive delete
        if lower.contains("rm ") || lower.contains("rm\t") {
            return "Delete was rejected. Do not retry. Continue with non-destructive cleanup or report what would have been removed."
        }
        
        // 4. sudo / secrets / outside workspace
        if lower.contains("sudo") || lower.contains("env ") || lower.contains("export ") {
            return "Critical command rejected. Stop only if task cannot safely continue; otherwise explain required manual action."
        }
        
        return defaultInstruction
    }
}
