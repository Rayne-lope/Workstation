import Foundation
import AppKit
import SwiftUI

public enum MarkdownTextRenderer {
    public enum Mode {
        case detail
        case preview
        case copilot
    }

    public enum TableAlignment: String, Codable, Equatable, Hashable {
        case left
        case center
        case right
    }

    public enum MessageContentBlock: Equatable, Hashable {
        case text(String)
        case table(headers: [String], alignments: [TableAlignment], rows: [[String]])
    }

    public static func parseContentBlocks(from text: String) -> [MessageContentBlock] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [MessageContentBlock] = []
        
        var currentTextLines: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Check if a table starts at line `i` (header) and `i+1` is separator
            if i + 1 < lines.count {
                let nextLine = lines[i + 1]
                if isSeparatorLine(nextLine) && hasPipes(line) {
                    let headerCols = parseColumns(from: line)
                    let sepCols = parseColumns(from: nextLine)
                    
                    if !headerCols.isEmpty && headerCols.count == sepCols.count {
                        // Flush accumulated text block
                        if !currentTextLines.isEmpty {
                            blocks.append(.text(currentTextLines.joined(separator: "\n")))
                            currentTextLines.removeAll()
                        }
                        
                        // Parse alignments
                        let alignments = sepCols.map { parseAlignment(from: $0) }
                        
                        // Parse data rows
                        var dataRows: [[String]] = []
                        var j = i + 2
                        while j < lines.count {
                            let dataLine = lines[j]
                            if hasPipes(dataLine) {
                                var cells = parseColumns(from: dataLine)
                                if cells.count < headerCols.count {
                                    cells.append(contentsOf: Array(repeating: "", count: headerCols.count - cells.count))
                                } else if cells.count > headerCols.count {
                                    cells = Array(cells.prefix(headerCols.count))
                                }
                                dataRows.append(cells)
                                j += 1
                            } else {
                                break
                            }
                        }
                        
                        // Append table block
                        blocks.append(.table(headers: headerCols, alignments: alignments, rows: dataRows))
                        
                        // Advance past header, separator, and data rows
                        i = j
                        continue
                    }
                }
            }
            
            currentTextLines.append(line)
            i += 1
        }
        
        // Flush remaining text
        if !currentTextLines.isEmpty {
            blocks.append(.text(currentTextLines.joined(separator: "\n")))
        }
        
        return blocks
    }
    
    private static func isSeparatorLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Must contain at least one pipe and at least one dash or colon
        guard trimmed.contains("|") && (trimmed.contains("-") || trimmed.contains(":")) else { return false }
        
        let allowed = CharacterSet(charactersIn: "|-:\t ")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
    
    private static func hasPipes(_ line: String) -> Bool {
        return line.contains("|")
    }
    
    private static func parseColumns(from line: String) -> [String] {
        var cells = line.components(separatedBy: "|")
        
        // Trim outer empty elements if they represent leading/trailing boundary pipes
        if line.hasPrefix("|") && !cells.isEmpty {
            cells.removeFirst()
        }
        if line.hasSuffix("|") && !cells.isEmpty {
            cells.removeLast()
        }
        
        return cells.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private static func parseAlignment(from column: String) -> TableAlignment {
        let trimmed = column.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLeft = trimmed.hasPrefix(":")
        let hasRight = trimmed.hasSuffix(":")
        if hasLeft && hasRight {
            return .center
        } else if hasRight {
            return .right
        } else {
            return .left
        }
    }

    public static func attributedString(from raw: String, mode: Mode) -> AttributedString? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let parsed: AttributedString
        if mode == .copilot {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            parsed = (try? AttributedString(markdown: raw, options: options)) ?? AttributedString(raw)
        } else {
            parsed = (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
        }

        switch mode {
        case .detail:
            return parsed
        case .preview:
            return parsed.strippingBlockPresentationIntents()
        case .copilot:
            return applyCopilotStyling(parsed)
        }
    }

    /// Apply dark theme styling for copilot chat bubbles.
    /// Uses DM Sans for body text, preserves bold/italic/strikethrough.
    private static func applyCopilotStyling(_ text: AttributedString) -> AttributedString {
        var result = text

        // Base font: DM Sans 13pt
        let baseFont = NSFont(name: "DM Sans", size: 13) ?? NSFont.systemFont(ofSize: 13)
        let boldFont = NSFont(name: "DM Sans", size: 13)?.bold() ?? NSFont.boldSystemFont(ofSize: 13)
        let italicFont = NSFont(name: "DM Sans-Italic", size: 13) ?? NSFont.systemFont(ofSize: 13).italic()

        // Apply base attributes to all runs that don't have custom styling
        for run in result.runs {
            let hasFont = run.font != nil
            let intent = run.inlinePresentationIntent
            let isStrong = intent?.contains(.stronglyEmphasized) ?? false
            let isEmphasis = intent?.contains(.emphasized) ?? false

            if !hasFont && !isStrong && !isEmphasis {
                result[run.range].font = baseFont
                result[run.range].foregroundColor = NSColor.labelColor
            }

            // Bold for strong emphasis
            if isStrong {
                result[run.range].font = boldFont
            }

            // Italic for emphasis
            if isEmphasis {
                result[run.range].font = italicFont
            }
        }

        return result
    }

    /// Render markdown text for copilot assistant bubbles using SwiftUI Text.
    /// Falls back to plain text if markdown parsing fails.
    public static func copilotText(for raw: String) -> Text {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Text("")
        }

        // Use AttributedString for markdown rendering, then convert to SwiftUI Text
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let attributed = try? AttributedString(markdown: trimmed, options: options) {
            return Text(attributed)
        }

        // Fallback to plain text
        return Text(trimmed)
    }
}

private extension AttributedString {
    func strippingBlockPresentationIntents() -> AttributedString {
        var copy = self
        for run in runs where run.presentationIntent != nil {
            copy[run.range].presentationIntent = nil
        }
        return copy
    }
}

private extension NSFont {
    func bold() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.bold)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }

    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}


