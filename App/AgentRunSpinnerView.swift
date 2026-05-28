import SwiftUI

/// Animated 3×3 blocks spinner that mirrors the `blocks-wave.svg` animation.
///
/// Blocks shrink from full size to ~15 % in a wave pattern radiating from the
/// top-left corner, staggered by `(row + col) × 0.1 s` per block — identical
/// to the SVG timing. Each block independently oscillates with `repeatForever`.
///
/// Usage:
/// ```swift
/// AgentRunSpinnerView()                       // 22 pt, gold
/// AgentRunSpinnerView(size: 14)               // 14 pt, gold
/// AgentRunSpinnerView(size: 12, color: .white) // custom colour
/// ```
struct AgentRunSpinnerView: View {
    /// Total bounding size of the widget (width = height).
    var size: CGFloat = 22
    /// Block fill colour. Defaults to the app's gold accent.
    var color: Color = WorkstationTheme.accent

    @State private var isAnimating = false

    var body: some View {
        let blockSize = size / 4.2
        let gap       = size / 22.0

        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { col in
                        Rectangle()
                            .fill(color)
                            .frame(width: blockSize, height: blockSize)
                            .scaleEffect(isAnimating ? 0.15 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .delay(Double(row + col) * 0.1)
                                    .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                }
            }
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}
