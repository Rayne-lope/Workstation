import SwiftUI
#if canImport(BeadsWorkspace)
import BeadsWorkspace
#endif

// MARK: - Live Terminal Drawer

struct LiveTerminalDrawer: View {
    let runID: UUID
    let messages: [AgentRunMessage]
    let isActive: Bool
    let onKillAgent: () -> Void
    let onClearLogs: () -> Void

    @State private var isExpanded: Bool = true
    @State private var autoScroll: Bool = true
    @State private var scrollProxy: ScrollViewProxy? = nil

    // Pull all agent log lines from coalesced messages and strip ANSI escape sequences
    private var logLines: [String] {
        let raw = messages.filter { $0.role == .agent }.map(\.content).joined()
        let stripped = stripANSI(raw)
        return stripped.components(separatedBy: .newlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            drawerHeader

            if isExpanded {
                ZStack(alignment: .bottomTrailing) {
                    terminalScrollView
                    if !autoScroll {
                        resumeScrollBadge
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
            if !logLines.filter({ !$0.isEmpty }).isEmpty {
                Text("\(logLines.filter { !$0.isEmpty }.count) lines")
                    .font(WorkstationTheme.Fonts.body(10, weight: .medium))
                    .foregroundStyle(WorkstationTheme.textSubtle)
                    .monospacedDigit()
            }

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
                    ForEach(Array(logLines.enumerated()), id: \.offset) { idx, line in
                        terminalLine(line, index: idx)
                    }
                    // Invisible anchor at the very bottom
                    Color.clear
                        .frame(height: 1)
                        .id("terminal-bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(Color(hex: "#0A0A0A"))
            .simultaneousGesture(
                DragGesture(minimumDistance: 1).onChanged { _ in
                    autoScroll = false
                }
            )
            .onChange(of: logLines.count) { _, _ in
                if autoScroll {
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
    private func terminalLine(_ line: String, index: Int) -> some View {
        if line.isEmpty {
            Color.clear.frame(height: 4)
        } else {
            Text(line)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(terminalLineColor(line: line, raw: line))
                .lineSpacing(2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Resume Auto-scroll Badge

    private var resumeScrollBadge: some View {
        Button {
            autoScroll = true
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

