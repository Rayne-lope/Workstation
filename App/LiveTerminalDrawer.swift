import SwiftUI
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

// MARK: - Live Terminal Drawer

struct UITerminalLine: Identifiable, Equatable {
    let id: Int
    let text: String
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct LiveTerminalDrawer: View {
    let runID: UUID
    let messages: [AgentRunMessage]
    let isActive: Bool
    let onKillAgent: () -> Void
    let onClearLogs: () -> Void

    @State private var isExpanded: Bool = true
    @State private var autoScroll: Bool = true
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    @State private var lineWrap: Bool = true
    @State private var scrollViewHeight: CGFloat = 240
    @State private var lastProgrammaticScrollTime: Date = Date.distantPast

    @State private var terminalInput: String = ""
    @FocusState private var isInputFocused: Bool

    private struct ParsedTerminalData {
        let allLinesCount: Int
        let visibleLines: [UITerminalLine]
    }

    private var parsedData: ParsedTerminalData {
        let raw = messages.filter { $0.role == .agent }.map(\.content).joined()
        let stripped = stripANSI(raw)
        let lines = stripped.components(separatedBy: .newlines)
        
        let mapped = lines.enumerated().map { UITerminalLine(id: $0.offset, text: $0.element) }
        let totalCount = mapped.filter { !$0.text.isEmpty }.count
        let visible = Array(mapped.suffix(300))
        
        return ParsedTerminalData(allLinesCount: totalCount, visibleLines: visible)
    }

    var body: some View {
        VStack(spacing: 0) {
            drawerHeader

            if isExpanded {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomTrailing) {
                        terminalScrollView
                        if !autoScroll {
                            resumeScrollBadge
                        }
                    }
                    .frame(height: isActive ? 204 : 240)
                    
                    if isActive {
                        terminalInputBar
                    }
                }
                .frame(height: 240)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(hex: "#0A0A0A"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WorkstationTheme.Radius.large, style: .continuous)
                .stroke(isActive ? WorkstationTheme.accent.opacity(0.3) : WorkstationTheme.borderSoft, lineWidth: 1)
        )
    }

    // MARK: - Header

    private var drawerHeader: some View {
        HStack(spacing: 10) {
            // Status indicator
            HStack(spacing: 6) {
                if isActive {
                    PulsingDot()
                } else {
                    Circle()
                        .fill(WorkstationTheme.textSubtle)
                        .frame(width: 6, height: 6)
                }
                Text(isActive ? "Terminal · Live" : "Terminal · Inactive")
                    .font(WorkstationTheme.Fonts.body(11, weight: .semibold))
                    .foregroundStyle(isActive ? WorkstationTheme.accent : WorkstationTheme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Spacer()

            // Line count
            let totalCount = parsedData.allLinesCount
            if totalCount > 0 {
                Text("\(totalCount) lines")
                    .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .monospacedDigit()
            }

            // Line wrap toggle
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    lineWrap.toggle()
                }
            } label: {
                Label(lineWrap ? "Wrap Off" : "Wrap On", systemImage: lineWrap ? "text.alignleft" : "text.justify.left")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(lineWrap ? WorkstationTheme.accent : WorkstationTheme.textSubtle)
            }
            .buttonStyle(TerminalHeaderButtonStyle())
            .help(lineWrap ? "Disable line wrapping" : "Enable line wrapping")

            // Copy button
            Button {
                copyLogsToClipboard()
            } label: {
                Label("Copy Logs", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(TerminalHeaderButtonStyle())
            .help("Copy clean logs to clipboard")

            // Clear button
            Button {
                onClearLogs()
            } label: {
                Label("Clear", systemImage: "trash")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(TerminalHeaderButtonStyle())
            .help("Clear logs")

            // Kill / Stop button (only when active)
            if isActive {
                Button {
                    onKillAgent()
                } label: {
                    Label("Kill Agent", systemImage: "stop.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(TerminalKillButtonStyle())
                .help("Send SIGINT to agent process group")
            }

            // Collapse toggle
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WorkstationTheme.textMuted)
            }
            .buttonStyle(.plain)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(hex: "#0D0D0D"))
    }

    // MARK: - Terminal Scroll View

    private var terminalScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(parsedData.visibleLines) { line in
                        terminalLine(line)
                    }
                    // Invisible anchor at the very bottom
                    Color.clear
                        .frame(height: 1)
                        .id("terminal-bottom")
                        .background(
                            GeometryReader { bottomGeo in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: bottomGeo.frame(in: .named("terminal-scroll")).maxY
                                    )
                            }
                        )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .coordinateSpace(name: "terminal-scroll")
            .background(Color(hex: "#0A0A0A"))
            .background(
                GeometryReader { scrollGeo in
                    Color.clear
                        .onAppear {
                            self.scrollViewHeight = scrollGeo.size.height
                        }
                        .onChange(of: scrollGeo.size.height) { _, newHeight in
                            self.scrollViewHeight = newHeight
                        }
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { maxY in
                // Ignore scroll offset changes that occur within 300ms of a programmatic scroll to prevent layout/animation noise from disabling auto-scroll.
                guard Date().timeIntervalSince(lastProgrammaticScrollTime) > 0.3 else { return }
                
                if maxY > scrollViewHeight + 25 {
                    if autoScroll {
                        autoScroll = false
                    }
                } else if maxY <= scrollViewHeight + 5 {
                    if !autoScroll {
                        autoScroll = true
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 1).onChanged { _ in
                    autoScroll = false
                }
            )
            .onTapGesture {
                isInputFocused = true
            }
            .onChange(of: parsedData.visibleLines.last?.id) { _, _ in
                if autoScroll {
                    lastProgrammaticScrollTime = Date()
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo("terminal-bottom", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
                proxy.scrollTo("terminal-bottom", anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func terminalLine(_ line: UITerminalLine) -> some View {
        if line.text.isEmpty {
            Color.clear.frame(height: 4)
        } else {
            Text(line.text)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(terminalLineColor(line: line.text, raw: line.text))
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(lineWrap ? nil : 1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Resume Auto-scroll Badge

    private var resumeScrollBadge: some View {
        Button {
            autoScroll = true
            lastProgrammaticScrollTime = Date()
            withAnimation(.easeOut(duration: 0.15)) {
                scrollProxy?.scrollTo("terminal-bottom", anchor: .bottom)
            }
        } label: {
            Label("↓ Auto-scroll", systemImage: "arrow.down")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(WorkstationTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(hex: "#1A1A1A").opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(WorkstationTheme.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 10)
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
    }

    // MARK: - Interactive Inputs

    private var terminalInputBar: some View {
        HStack(spacing: 8) {
            Text(">")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(WorkstationTheme.accent)
            
            TextField("Type response (e.g. y/n, option #) or command...", text: $terminalInput)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .textFieldStyle(.plain)
                .foregroundStyle(WorkstationTheme.textPrimary)
                .focused($isInputFocused)
                .onSubmit {
                    sendInput()
                }
            
            if !terminalInput.isEmpty {
                Button {
                    sendInput()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(WorkstationTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: "#080808"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkstationTheme.borderSoft)
                .frame(height: 1)
        }
    }

    private func sendInput() {
        let textToSend = terminalInput
        guard !textToSend.isEmpty else { return }
        terminalInput = ""
        
        #if canImport(BeadsWorkspace)
        PTYProcessRegistry.shared.writeInput(for: runID, text: textToSend + "\n")
        #endif
    }

    private func copyLogsToClipboard() {
        let raw = messages.filter { $0.role == .agent }.map(\.content).joined()
        let stripped = stripANSI(raw)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(stripped, forType: .string)
    }

    // MARK: - Helpers

    /// Minimal ANSI escape code stripper
    private func stripANSI(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        while i < input.endIndex {
            if input[i] == "\u{1B}" {
                // Skip until final byte (letter in range 0x40–0x7E)
                i = input.index(after: i)
                if i < input.endIndex && input[i] == "[" {
                    i = input.index(after: i)
                    while i < input.endIndex {
                        let c = input[i]
                        i = input.index(after: i)
                        if c.asciiValue.map({ $0 >= 0x40 && $0 <= 0x7E }) == true { break }
                    }
                } else {
                    // Other escape sequences — skip one char
                    if i < input.endIndex { i = input.index(after: i) }
                }
            } else {
                result.append(input[i])
                i = input.index(after: i)
            }
        }
        return result
    }

    /// Heuristic color coding for terminal lines
    private func terminalLineColor(line: String, raw: String) -> Color {
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("fatal") || lower.contains("failed") {
            return Color(hex: "#F87171") // red
        } else if lower.contains("warning") || lower.contains("warn") {
            return Color(hex: "#FB923C") // orange
        } else if lower.contains("✓") || lower.contains("success") || lower.contains("passed") || lower.contains("done") {
            return Color(hex: "#86EFAC") // green
        } else if line.hasPrefix("$") || line.hasPrefix(">") {
            return Color(hex: "#ECC864") // gold — shell prompt
        } else {
            return Color(hex: "#C8C4BC") // warm off-white
        }
    }
}

// MARK: - Pulsing Status Dot

private struct PulsingDot: View {
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(WorkstationTheme.accent.opacity(0.3))
                .frame(width: 10, height: 10)
                .scaleEffect(scale)
            Circle()
                .fill(WorkstationTheme.accent)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                scale = 1.6
            }
        }
    }
}

// MARK: - Button Styles

private struct TerminalHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? WorkstationTheme.textSecondary : WorkstationTheme.textSubtle)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
    }
}

private struct TerminalKillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(Color(hex: "#F87171"))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color(hex: "#F87171").opacity(configuration.isPressed ? 0.25 : 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(hex: "#F87171").opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

