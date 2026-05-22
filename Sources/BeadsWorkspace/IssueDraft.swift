import Foundation

public enum IssueDraftParseError: LocalizedError, Sendable {
    case emptyResponse
    case unparseableOutput
    case missingTitle

    public var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "The AI returned no draft text."
        case .unparseableOutput:
            return "The AI output could not be parsed into a draft."
        case .missingTitle:
            return "The AI draft is missing a title."
        }
    }
}

public struct IssueDraft: Sendable, Hashable {
    public var title: String
    public var description: String
    public var implementationNotes: String
    public var acceptanceCriteria: String
    public var issueType: String?
    public var priority: Int?
    public var labels: String
    public var splitSuggestions: String
    public var dependencySuggestions: String

    private enum Section: Hashable {
        case title
        case description
        case implementationNotes
        case acceptanceCriteria
        case issueType
        case priority
        case labels
        case splitSuggestions
        case dependencySuggestions
    }

    public init(
        title: String = "",
        description: String = "",
        implementationNotes: String = "",
        acceptanceCriteria: String = "",
        issueType: String? = nil,
        priority: Int? = nil,
        labels: String = "",
        splitSuggestions: String = "",
        dependencySuggestions: String = ""
    ) {
        self.title = title
        self.description = description
        self.implementationNotes = implementationNotes
        self.acceptanceCriteria = acceptanceCriteria
        self.issueType = issueType
        self.priority = priority
        self.labels = labels
        self.splitSuggestions = splitSuggestions
        self.dependencySuggestions = dependencySuggestions
    }

    public static var empty: IssueDraft {
        IssueDraft()
    }

    public static func parse(from rawText: String) throws -> IssueDraft {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IssueDraftParseError.emptyResponse
        }

        if let jsonDraft = try? parseJSONDraft(from: trimmed) {
            return jsonDraft
        }

        if let textDraft = parseLabeledTextDraft(from: trimmed) {
            return textDraft
        }

        throw IssueDraftParseError.unparseableOutput
    }

    public func createInput() -> CreateIssueInput {
        CreateIssueInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: Self.trimmedOrNil(description),
            designNotes: Self.trimmedOrNil(implementationNotes),
            issueType: normalizedIssueType(),
            priority: priority,
            acceptanceCriteria: Self.trimmedOrNil(acceptanceCriteria),
            labels: labelsList()
        )
    }

    public var labelsListText: String {
        labels
    }

    public var splitSuggestionsText: String {
        splitSuggestions
    }

    public var dependencySuggestionsText: String {
        dependencySuggestions
    }

    public func labelsList() -> [String]? {
        let parsed = labels
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parsed.isEmpty ? nil : parsed
    }

    public func normalizedIssueType() -> String? {
        let trimmed = issueType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !trimmed.isEmpty else { return nil }
        switch trimmed {
        case "enhancement", "feat":
            return "feature"
        case "dec", "adr":
            return "decision"
        case "task", "bug", "feature", "epic", "chore", "decision":
            return trimmed
        default:
            return nil
        }
    }

    public var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedImplementationNotes: String {
        implementationNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedAcceptanceCriteria: String {
        acceptanceCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseJSONDraft(from rawText: String) throws -> IssueDraft {
        guard let jsonObject = try extractJSONObject(from: rawText) else {
            throw IssueDraftParseError.unparseableOutput
        }
        guard let draft = draft(fromJSONObject: jsonObject) else {
            throw IssueDraftParseError.unparseableOutput
        }
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IssueDraftParseError.missingTitle
        }
        return draft
    }

    private static func extractJSONObject(from rawText: String) throws -> [String: Any]? {
        let candidates = jsonCandidates(from: rawText)
        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return object
            }
        }
        return nil
    }

    private static func jsonCandidates(from rawText: String) -> [String] {
        var candidates: [String] = []
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        candidates.append(trimmed)

        if let fenced = fencedJSONBlock(from: trimmed) {
            candidates.append(fenced)
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            let slice = String(trimmed[start...end])
            candidates.append(slice)
        }

        return candidates
    }

    private static func fencedJSONBlock(from rawText: String) -> String? {
        guard let fenceRange = rawText.range(of: "```") else { return nil }
        let remainder = rawText[fenceRange.upperBound...]
        guard let closingFence = remainder.range(of: "```") else { return nil }
        return String(remainder[..<closingFence.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func draft(fromJSONObject object: [String: Any]) -> IssueDraft? {
        let title = stringValue(
            object,
            keys: ["title", "issue_title", "issueTitle"]
        ) ?? ""
        let description = stringValue(
            object,
            keys: ["description", "summary", "issue_description", "issueDescription"]
        ) ?? ""
        let implementationNotes = stringValue(
            object,
            keys: ["implementation_notes", "implementationNotes", "design", "notes"]
        ) ?? ""
        let acceptanceCriteria = stringArrayValue(
            object,
            keys: ["acceptance_criteria", "acceptanceCriteria"]
        )
        .joined(separator: "\n")
        let labels = stringArrayValue(object, keys: ["labels"])
            .joined(separator: ", ")
        let splitSuggestions = stringArrayValue(
            object,
            keys: ["split_suggestions", "splitSuggestions"]
        )
        .joined(separator: "\n")
        let dependencySuggestions = stringArrayValue(
            object,
            keys: ["dependency_suggestions", "dependencySuggestions"]
        )
        .joined(separator: "\n")

        let rawType = stringValue(object, keys: ["issue_type", "issueType"])
        let issueType = rawType?.trimmingCharacters(in: .whitespacesAndNewlines)

        let priority = intValue(object, keys: ["priority"])

        return IssueDraft(
            title: title,
            description: description,
            implementationNotes: implementationNotes,
            acceptanceCriteria: acceptanceCriteria,
            issueType: issueType,
            priority: priority,
            labels: labels,
            splitSuggestions: splitSuggestions,
            dependencySuggestions: dependencySuggestions
        )
    }

    private static func parseLabeledTextDraft(from rawText: String) -> IssueDraft? {
        let title: String? = nil
        var currentSection: Section?
        var buffers: [Section: [String]] = [:]
        let lines = rawText.components(separatedBy: .newlines)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let (section, inlineValue) = parseSectionHeader(line) {
                currentSection = section
                if let inlineValue, !inlineValue.isEmpty {
                    buffers[section, default: []].append(inlineValue)
                }
                continue
            }

            guard let currentSection else {
                continue
            }
            buffers[currentSection, default: []].append(cleanSectionLine(line))
        }

        let explicitTitle = buffers[.title, default: []]
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = !explicitTitle.isEmpty ? explicitTitle : title
        guard let resolvedTitle, !resolvedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let description = buffers[Section.description, default: []].joined(separator: "\n")
        let implementationNotes = buffers[Section.implementationNotes, default: []].joined(separator: "\n")
        let acceptanceCriteria = buffers[Section.acceptanceCriteria, default: []].joined(separator: "\n")
        let labels = buffers[Section.labels, default: []].joined(separator: ", ")
        let splitSuggestions = buffers[Section.splitSuggestions, default: []].joined(separator: "\n")
        let dependencySuggestions = buffers[Section.dependencySuggestions, default: []].joined(separator: "\n")

        let issueType = normalizeIssueType(from: buffers[Section.issueType, default: []].first)
        let priority = parsePriority(from: buffers[Section.priority, default: []].first)

        return IssueDraft(
            title: resolvedTitle,
            description: description,
            implementationNotes: implementationNotes,
            acceptanceCriteria: acceptanceCriteria,
            issueType: issueType,
            priority: priority,
            labels: labels,
            splitSuggestions: splitSuggestions,
            dependencySuggestions: dependencySuggestions
        )
    }

    private static func parseSectionHeader(_ line: String) -> (section: Section, inlineValue: String?)? {
        let cleaned = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "##", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let lower = cleaned.lowercased()
        let sections: [(prefix: String, section: Section)] = [
            ("title:", Section.title),
            ("description:", Section.description),
            ("implementation notes:", Section.implementationNotes),
            ("implementation:", Section.implementationNotes),
            ("notes:", Section.implementationNotes),
            ("acceptance criteria:", Section.acceptanceCriteria),
            ("criteria:", Section.acceptanceCriteria),
            ("issue type:", Section.issueType),
            ("type:", Section.issueType),
            ("priority:", Section.priority),
            ("labels:", Section.labels),
            ("split suggestions:", Section.splitSuggestions),
            ("split:", Section.splitSuggestions),
            ("dependency suggestions:", Section.dependencySuggestions),
            ("dependencies:", Section.dependencySuggestions)
        ]

        for item in sections {
            if lower.hasPrefix(item.prefix) {
                let value = cleaned.dropFirst(item.prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                return (item.section, value.isEmpty ? nil : value)
            }
        }
        return nil
    }

    private static func cleanSectionLine(_ line: String) -> String {
        line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-•*"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stringValue(_ object: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = object[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func stringArrayValue(_ object: [String: Any], keys: [String]) -> [String] {
        for key in keys {
            if let strings = object[key] as? [String] {
                return strings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
            if let string = object[key] as? String {
                let items = string
                    .components(separatedBy: .newlines)
                    .flatMap { $0.components(separatedBy: ",") }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                if !items.isEmpty { return items }
            }
        }
        return []
    }

    private static func intValue(_ object: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = object[key] as? Int {
                return value
            }
            if let value = object[key] as? NSNumber {
                return value.intValue
            }
            if let value = object[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if let intValue = Int(trimmed) {
                    return intValue
                }
            }
        }
        return nil
    }

    private static func normalizeIssueType(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
        case "enhancement", "feat":
            return "feature"
        case "dec", "adr":
            return "decision"
        case "task", "bug", "feature", "epic", "chore", "decision":
            return trimmed
        default:
            return nil
        }
    }

    private static func parsePriority(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let intValue = Int(trimmed), (0...4).contains(intValue) {
            return intValue
        }
        switch trimmed {
        case "p0", "must", "critical": return 0
        case "p1", "important": return 1
        case "p2", "high": return 2
        case "p3", "medium": return 3
        case "p4", "low", "backlog": return 4
        default: return nil
        }
    }
}
