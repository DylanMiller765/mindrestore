import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false

    let colors: [Color] = [
        .red, .blue, .green, .yellow, .orange, .pink, .purple,
        Color(red: 0.18, green: 0.49, blue: 0.20), .cyan, .mint
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size.width, height: p.size.height)
                        .rotationEffect(.degrees(isAnimating ? p.finalRotation : 0))
                        .offset(
                            x: isAnimating ? p.finalX : geo.size.width / 2 - 20 + CGFloat.random(in: -20...20),
                            y: isAnimating ? p.finalY : -20
                        )
                        .opacity(isAnimating ? 0 : 1)
                }
            }
            .onAppear {
                particles = generateParticles(in: geo.size)
                withAnimation(.easeOut(duration: 3.0)) {
                    isAnimating = true
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles(in size: CGSize) -> [ConfettiParticle] {
        (0..<60).map { i in
            ConfettiParticle(
                id: i,
                color: colors[i % colors.count],
                size: CGSize(
                    width: CGFloat.random(in: 4...10),
                    height: CGFloat.random(in: 6...14)
                ),
                finalX: CGFloat.random(in: -size.width/2...size.width/2),
                finalY: CGFloat.random(in: size.height * 0.3...size.height * 1.2),
                finalRotation: Double.random(in: -720...720)
            )
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    let color: Color
    let size: CGSize
    let finalX: CGFloat
    let finalY: CGFloat
    let finalRotation: Double
}
