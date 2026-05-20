import Foundation

public enum BeadsDecodeError: Error, LocalizedError, Sendable {
    case emptyArray

    public var errorDescription: String? {
        switch self {
        case .emptyArray:
            return "Expected one issue but received an empty array."
        }
    }
}

public enum BeadsJSONDecoder {
    public static func decodeIssues(from data: Data) throws -> [BeadIssue] {
        if let issues = try? JSONDecoder().decode([BeadIssue].self, from: data) {
            return issues
        }

        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(IssueListPayload.self, from: data) {
            return payload.issues
        }

        return [try JSONDecoder().decode(BeadIssue.self, from: data)]
    }

    public static func decodeIssue(from data: Data) throws -> BeadIssue {
        if let issue = try? JSONDecoder().decode(BeadIssue.self, from: data) {
            return issue
        }

        if let issues = try? JSONDecoder().decode([BeadIssue].self, from: data) {
            guard let first = issues.first else {
                throw BeadsDecodeError.emptyArray
            }
            return first
        }

        if let payload = try? JSONDecoder().decode(IssueListPayload.self, from: data) {
            guard let first = payload.issues.first else {
                throw BeadsDecodeError.emptyArray
            }
            return first
        }

        return try JSONDecoder().decode(BeadIssue.self, from: data)
    }

    private struct IssueListPayload: Decodable {
        let issues: [BeadIssue]
    }
}
