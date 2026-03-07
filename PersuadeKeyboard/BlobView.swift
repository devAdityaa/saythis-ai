import SwiftUI

// MARK: - Glowing Orb (matches GlowingOrb.tsx reference exactly)
struct BlobView: View {
    var size: CGFloat = 260

    // Single toggle drives all repeating animations via explicit .animation() modifiers
    @State private var animating = false
    @State private var ripples: [Ripple] = []

    // Reference colors from GlowingOrb.tsx
    private let cyan300   = Color(red: 165/255, green: 243/255, blue: 252/255)  // #a5f3fc
    private let cyan500   = Color(red: 6/255,   green: 182/255, blue: 212/255)  // #06b6d4
    private let cyan600   = Color(red: 8/255,   green: 145/255, blue: 178/255)  // #0891b2
    private let indigo500 = Color(red: 99/255,  green: 102/255, blue: 241/255)  // #6366f1
    private let violet300 = Color(red: 196/255, green: 181/255, blue: 253/255)  // #c4b5fd

    struct Ripple: Identifiable {
        let id = UUID()
        var scale: CGFloat = 0.5
        var opacity: Double = 0.6
    }

    var body: some View {
        ZStack {
            // ─── Layer 1: Outer pulsing glow ───
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            cyan500.opacity(0.25),
                            indigo500.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.35,
                        endRadius: size * 0.95
                    )
                )
                .frame(width: size * 2.0, height: size * 2.0)
                .scaleEffect(animating ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animating)

            // ─── Layer 2: Ripple effects on tap ───
            ForEach(ripples) { ripple in
                Circle()
                    .stroke(cyan300.opacity(ripple.opacity), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(ripple.scale)
            }

            // ─── Layer 3: Main sphere body ───
            Circle()
                .fill(
                    RadialGradient(
                        colors: [cyan300, cyan500, cyan600, indigo500],
                        center: UnitPoint(x: 0.3, y: 0.25),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: cyan500.opacity(0.35), radius: 40, x: 0, y: 0)
                .shadow(color: indigo500.opacity(0.15), radius: 60, x: 0, y: 0)

            // ─── Layer 4: Inner conic swirl (rotating) ───
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.0)
                        ],
                        center: .center
                    )
                )
                .frame(width: size * 0.92, height: size * 0.92)
                .rotationEffect(.degrees(animating ? 360 : 0))
                .animation(.linear(duration: 8.0).repeatForever(autoreverses: false), value: animating)
                .clipShape(Circle())

            // ─── Layer 5: Sparkle 4-point star ───
            FourPointedStar()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.30, height: size * 0.30)
                .rotationEffect(.degrees(animating ? 90 : 0))
                .scaleEffect(animating ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animating)

            // ─── Layer 6: Top-left highlight (pulsing) ───
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.22
                    )
                )
                .frame(width: size * 0.55, height: size * 0.4)
                .offset(x: -size * 0.12, y: -size * 0.17)
                .opacity(animating ? 0.6 : 0.4)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animating)

            // ─── Layer 7: Sharp highlight (static) ───
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.15),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.12
                    )
                )
                .frame(width: size * 0.3, height: size * 0.2)
                .offset(x: -size * 0.1, y: -size * 0.2)

            // ─── Layer 8: Bottom violet reflection ───
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [violet300.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.18
                    )
                )
                .frame(width: size * 0.5, height: size * 0.2)
                .offset(y: size * 0.28)
        }
        .contentShape(Circle())
        .onTapGesture { spawnRipple() }
        .onAppear { animating = true }
    }

    private func spawnRipple() {
        let ripple = Ripple()
        ripples.append(ripple)
        let rippleID = ripple.id

        withAnimation(.easeOut(duration: 0.8)) {
            if let idx = ripples.firstIndex(where: { $0.id == rippleID }) {
                ripples[idx].scale = 1.8
                ripples[idx].opacity = 0.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            ripples.removeAll { $0.id == rippleID }
        }
    }
}

// MARK: - 4-Pointed Star Shape (SVG-accurate sparkle)
struct FourPointedStar: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * 0.22

        var path = Path()

        let tips: [(CGFloat, CGFloat)] = [
            (cx, cy - outerR),
            (cx + outerR, cy),
            (cx, cy + outerR),
            (cx - outerR, cy)
        ]

        let inners: [(CGFloat, CGFloat)] = [
            (cx + innerR, cy - innerR),
            (cx + innerR, cy + innerR),
            (cx - innerR, cy + innerR),
            (cx - innerR, cy - innerR)
        ]

        path.move(to: CGPoint(x: tips[0].0, y: tips[0].1))

        for i in 0..<4 {
            let inner = inners[i]
            let nextTip = tips[(i + 1) % 4]

            path.addQuadCurve(
                to: CGPoint(x: inner.0, y: inner.1),
                control: CGPoint(x: tips[i].0 + (inner.0 - tips[i].0) * 0.1,
                                 y: tips[i].1 + (inner.1 - tips[i].1) * 0.1)
            )
            path.addQuadCurve(
                to: CGPoint(x: nextTip.0, y: nextTip.1),
                control: CGPoint(x: inner.0 + (nextTip.0 - inner.0) * 0.1,
                                 y: inner.1 + (nextTip.1 - inner.1) * 0.1)
            )
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Small badge pill
struct BadgePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(AppTheme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.accent.opacity(0.12))
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Ambient Background (reusable — pulsing blurred circles)
struct AmbientBackground: View {
    @State private var animating = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Circle 1: cyan, top-right
                Circle()
                    .fill(AppTheme.accent.opacity(0.10))
                    .frame(width: 256, height: 256)
                    .blur(radius: 70)
                    .scaleEffect(animating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true), value: animating)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.12)

                // Circle 2: blue, bottom-left
                Circle()
                    .fill(Color(red: 59/255, green: 130/255, blue: 246/255).opacity(0.08))
                    .frame(width: 192, height: 192)
                    .blur(radius: 60)
                    .scaleEffect(animating ? 1.0 : 1.1)
                    .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: animating)
                    .position(x: geo.size.width * 0.18, y: geo.size.height * 0.82)

                // Circle 3: accent/violet, center-left — adds depth
                Circle()
                    .fill(Color(red: 99/255, green: 102/255, blue: 241/255).opacity(0.06))
                    .frame(width: 160, height: 160)
                    .blur(radius: 55)
                    .scaleEffect(animating ? 1.15 : 0.95)
                    .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: animating)
                    .position(x: geo.size.width * 0.35, y: geo.size.height * 0.45)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { animating = true }
    }
}

// MARK: - Floating Particles (premium subtle shimmer)
struct FloatingParticles: View {
    // Use separate phase toggles so each particle group drifts independently
    @State private var phase1 = false
    @State private var phase2 = false
    @State private var phase3 = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Canvas { context, _ in
                // Canvas just draws the background — actual particles are SwiftUI circles
                // below so they can animate with SwiftUI's animation system.
            }
            .allowsHitTesting(false)

            // Group A — slow upward drift, 6 particles
            particle(x: w * 0.12, y: h * 0.18, size: 2.2, baseOpacity: 0.30, driftY: -18, phase: phase1)
            particle(x: w * 0.88, y: h * 0.32, size: 2.8, baseOpacity: 0.22, driftY: -14, phase: phase1)
            particle(x: w * 0.35, y: h * 0.72, size: 1.8, baseOpacity: 0.35, driftY: -20, phase: phase1)
            particle(x: w * 0.62, y: h * 0.55, size: 2.5, baseOpacity: 0.25, driftY: -16, phase: phase1)
            particle(x: w * 0.78, y: h * 0.85, size: 2.0, baseOpacity: 0.28, driftY: -22, phase: phase1)
            particle(x: w * 0.25, y: h * 0.42, size: 3.0, baseOpacity: 0.18, driftY: -12, phase: phase1)

            // Group B — offset timing
            particle(x: w * 0.50, y: h * 0.15, size: 2.4, baseOpacity: 0.26, driftY: -16, phase: phase2)
            particle(x: w * 0.08, y: h * 0.60, size: 1.6, baseOpacity: 0.32, driftY: -18, phase: phase2)
            particle(x: w * 0.92, y: h * 0.70, size: 2.0, baseOpacity: 0.20, driftY: -14, phase: phase2)
            particle(x: w * 0.42, y: h * 0.90, size: 2.6, baseOpacity: 0.24, driftY: -20, phase: phase2)
            particle(x: w * 0.70, y: h * 0.25, size: 1.8, baseOpacity: 0.30, driftY: -15, phase: phase2)

            // Group C — slowest
            particle(x: w * 0.18, y: h * 0.88, size: 2.2, baseOpacity: 0.22, driftY: -12, phase: phase3)
            particle(x: w * 0.55, y: h * 0.38, size: 3.2, baseOpacity: 0.16, driftY: -10, phase: phase3)
            particle(x: w * 0.82, y: h * 0.50, size: 1.5, baseOpacity: 0.34, driftY: -18, phase: phase3)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                phase1 = true
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true).delay(1)) {
                phase2 = true
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(2)) {
                phase3 = true
            }
        }
    }

    @ViewBuilder
    private func particle(x: CGFloat, y: CGFloat, size: CGFloat,
                          baseOpacity: Double, driftY: CGFloat, phase: Bool) -> some View {
        Circle()
            .fill(AppTheme.accent)
            .frame(width: size, height: size)
            .opacity(phase ? baseOpacity : baseOpacity * 0.3)
            .position(x: x, y: y + (phase ? driftY : 0))
    }
}

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        AmbientBackground()
        FloatingParticles()
        BlobView(size: 220)
    }
}
