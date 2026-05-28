import SwiftUI

struct CelebrationParticle: Identifiable, Sendable {
    let id = UUID()
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var size: Double
    var color: Color
    var opacity: Double
    var rotation: Double
    var rotationSpeed: Double
    var shape: ParticleShape
    var lifetime: Double
    var age: Double = 0.0
}

enum ParticleShape: Sendable, CaseIterable {
    case circle
    case diamond
    case star
    case rectangle
}

struct ParticleCelebrationView: View {
    let triggerID: UUID
    
    @State private var particles: [CelebrationParticle] = []
    @State private var lastTriggerID: UUID? = nil
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    // Update and draw active particles
                    updateParticles()
                    
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.x - particle.size / 2,
                            y: particle.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )
                        
                        var innerContext = context
                        innerContext.translateBy(x: particle.x, y: particle.y)
                        innerContext.rotate(by: Angle(degrees: particle.rotation))
                        innerContext.translateBy(x: -particle.x, y: -particle.y)
                        
                        let drawRect = CGRect(
                            x: particle.x - particle.size / 2,
                            y: particle.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )
                        
                        switch particle.shape {
                        case .circle:
                            innerContext.fill(
                                Path(ellipseIn: drawRect),
                                with: .color(particle.color.opacity(particle.opacity))
                            )
                        case .rectangle:
                            innerContext.fill(
                                Path(roundedRect: drawRect, cornerRadius: 1),
                                with: .color(particle.color.opacity(particle.opacity))
                            )
                        case .diamond:
                            drawDiamond(in: innerContext, rect: drawRect, color: particle.color, opacity: particle.opacity)
                        case .star:
                            drawStar(in: innerContext, rect: drawRect, color: particle.color, opacity: particle.opacity)
                        }
                    }
                }
            }
            .onChange(of: triggerID) { _, newID in
                if newID != lastTriggerID {
                    lastTriggerID = newID
                    spawnCelebration(in: geometry.size)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    private func updateParticles() {
        guard !particles.isEmpty else { return }
        
        let gravity = 0.32
        let drag = 0.982
        
        var updated: [CelebrationParticle] = []
        for var p in particles {
            p.age += 0.016
            if p.age < p.lifetime {
                p.vy += gravity
                p.vx *= drag
                p.vy *= drag
                p.x += p.vx
                p.y += p.vy
                p.rotation += p.rotationSpeed
                p.opacity = max(0, 1.0 - (p.age / p.lifetime))
                updated.append(p)
            }
        }
        particles = updated
    }
    
    private func spawnCelebration(in size: CGSize) {
        var newParticles: [CelebrationParticle] = []
        
        let goldColors = [
            Color(hex: "ECC864"), // Primary Warm Gold Accent
            Color(hex: "F5D980"), // Hover Gold Accent
            Color(hex: "FFF5CE"), // Champagne Light Gold
            Color.white,          // Shiny Highlights
            Color(hex: "86EFAC")  // Success Green (subtle touch)
        ]
        
        // Spawn 45 particles from the left cannon (bottom-left corner)
        for _ in 0..<45 {
            let color = goldColors.randomElement() ?? Color(hex: "ECC864")
            let sizeVal = Double.random(in: 6...12)
            let angle = Double.random(in: -72.0 ... -40.0) * .pi / 180.0
            let speed = Double.random(in: 14...24)
            let vx = speed * cos(angle)
            let vy = speed * sin(angle)
            let shape = ParticleShape.allCases.randomElement() ?? .circle
            let lifetime = Double.random(in: 1.8...3.2)
            
            newParticles.append(
                CelebrationParticle(
                    x: 0,
                    y: size.height,
                    vx: vx,
                    vy: vy,
                    size: sizeVal,
                    color: color,
                    opacity: 1.0,
                    rotation: Double.random(in: 0...360),
                    rotationSpeed: Double.random(in: -8...8),
                    shape: shape,
                    lifetime: lifetime
                )
            )
        }
        
        // Spawn 45 particles from the right cannon (bottom-right corner)
        for _ in 0..<45 {
            let color = goldColors.randomElement() ?? Color(hex: "ECC864")
            let sizeVal = Double.random(in: 6...12)
            let angle = Double.random(in: -140.0 ... -108.0) * .pi / 180.0
            let speed = Double.random(in: 14...24)
            let vx = speed * cos(angle)
            let vy = speed * sin(angle)
            let shape = ParticleShape.allCases.randomElement() ?? .circle
            let lifetime = Double.random(in: 1.8...3.2)
            
            newParticles.append(
                CelebrationParticle(
                    x: size.width,
                    y: size.height,
                    vx: vx,
                    vy: vy,
                    size: sizeVal,
                    color: color,
                    opacity: 1.0,
                    rotation: Double.random(in: 0...360),
                    rotationSpeed: Double.random(in: -8...8),
                    shape: shape,
                    lifetime: lifetime
                )
            )
        }
        
        particles.append(contentsOf: newParticles)
    }
    
    private func drawDiamond(in context: GraphicsContext, rect: CGRect, color: Color, opacity: Double) {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(opacity)))
    }
    
    private func drawStar(in context: GraphicsContext, rect: CGRect, color: Color, opacity: Double) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = 5
        let outerRadius = rect.width / 2
        let innerRadius = outerRadius * 0.4
        
        var path = Path()
        var angle = -Double.pi / 2
        let angleIncrement = Double.pi / Double(points)
        
        for i in 0..<(points * 2) {
            let r = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + CGFloat(cos(angle)) * r
            let y = center.y + CGFloat(sin(angle)) * r
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            angle += angleIncrement
        }
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(opacity)))
    }
}
