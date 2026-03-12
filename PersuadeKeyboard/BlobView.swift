import SwiftUI

// MARK: - Obsidian Sphere (matches design: dark gradient sphere with inner teal glow + waveform)
struct BlobView: View {
    var size: CGFloat = 192
    var interactive: Bool = true

    @State private var animating = false
    @State private var ripples: [Ripple] = []

    struct Ripple: Identifiable {
        let id = UUID()
        var scale: CGFloat = 0.5
        var opacity: Double = 0.6
    }

    /// Show decorative rings, outer glow, and waveform only at larger sizes
    private var showDecorations: Bool { size >= 48 }
    private var waveScale: CGFloat { size / 192 }

    var body: some View {
        ZStack {
            if showDecorations {
                // ─── Decorative ring 2 (outermost) ───
                Circle()
                    .stroke(AppTheme.accent.opacity(0.05), lineWidth: 1)
                    .frame(width: size * 1.50, height: size * 1.50)

                // ─── Decorative ring 1 ───
                Circle()
                    .stroke(AppTheme.accent.opacity(0.08), lineWidth: 1)
                    .frame(width: size * 1.25, height: size * 1.25)

                // ─── AI Pulse glow (radial gradient behind sphere) ───
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.accent.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.9
                        )
                    )
                    .frame(width: size * 1.8, height: size * 1.8)
                    .scaleEffect(animating ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animating)
            }

            // ─── Ripple effects (only when interactive) ───
            if interactive {
                ForEach(ripples) { ripple in
                    Circle()
                        .stroke(AppTheme.accent.opacity(ripple.opacity), lineWidth: 1.5)
                        .frame(width: size, height: size)
                        .scaleEffect(ripple.scale)
                }
            }

            // ─── Main obsidian sphere ───
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 42/255, green: 74/255, blue: 74/255),  // #2a4a4a
                            Color(red: 16/255, green: 34/255, blue: 34/255)   // #102222
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(showDecorations ? 0.5 : 0.0), radius: showDecorations ? 25 : 0, y: showDecorations ? 10 : 0)
                .overlay(
                    // Inner teal glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    AppTheme.accent.opacity(0.20),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.35
                            )
                        )
                        .opacity(animating ? 0.8 : 0.5)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animating)
                )

            // ─── AI Waveform bars (scaled to sphere size) ───
            if showDecorations {
                HStack(spacing: 3 * waveScale) {
                    waveBar(height: 16 * waveScale, opacity: 0.4)
                    waveBar(height: 32 * waveScale, opacity: 0.6)
                    waveBar(height: 24 * waveScale, opacity: 1.0)
                    waveBar(height: 40 * waveScale, opacity: 0.6)
                    waveBar(height: 20 * waveScale, opacity: 0.4)
                }
                .scaleEffect(animating ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animating)
            }
        }
        .allowsHitTesting(interactive)
        .contentShape(Circle())
        .onTapGesture {
            if interactive { spawnRipple() }
        }
        .onAppear {
            animating = true
            if interactive { startAutoRipple() }
        }
    }

    private func waveBar(height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(AppTheme.accent.opacity(opacity))
            .frame(width: max(2, 4 * waveScale), height: height)
    }

    private func startAutoRipple() {
        Task { @MainActor in
            // Initial delay before first auto-ripple
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            while !Task.isCancelled {
                spawnRipple()
                // Interval between auto-ripples (3.5s)
                try? await Task.sleep(nanoseconds: 3_500_000_000)
            }
        }
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
                .fill(AppTheme.accent.opacity(0.08))
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.accent.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

// MARK: - Ambient Background (subtle pulsing glow — optimized)
struct AmbientBackground: View {
    @State private var animating = false

    var body: some View {
        ZStack {
            // Top-left teal glow
            Circle()
                .fill(AppTheme.accent.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -80, y: -120)
                .scaleEffect(animating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: animating)

            // Bottom-right teal glow
            Circle()
                .fill(AppTheme.accent.opacity(0.05))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 80, y: 200)
                .scaleEffect(animating ? 1.0 : 1.1)
                .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: animating)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .drawingGroup()
        .onAppear { animating = true }
    }
}

// MARK: - Floating Particles (premium subtle shimmer — reduced count for performance)
struct FloatingParticles: View {
    @State private var phase1 = false
    @State private var phase2 = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Group A — slow drift
                particle(x: w * 0.12, y: h * 0.18, size: 2.2, baseOpacity: 0.25, driftY: -18, phase: phase1)
                particle(x: w * 0.88, y: h * 0.32, size: 2.8, baseOpacity: 0.18, driftY: -14, phase: phase1)
                particle(x: w * 0.35, y: h * 0.72, size: 1.8, baseOpacity: 0.28, driftY: -20, phase: phase1)
                particle(x: w * 0.62, y: h * 0.55, size: 2.5, baseOpacity: 0.20, driftY: -16, phase: phase1)

                // Group B — offset timing
                particle(x: w * 0.50, y: h * 0.15, size: 2.4, baseOpacity: 0.22, driftY: -16, phase: phase2)
                particle(x: w * 0.08, y: h * 0.60, size: 1.6, baseOpacity: 0.26, driftY: -18, phase: phase2)
                particle(x: w * 0.78, y: h * 0.85, size: 2.0, baseOpacity: 0.20, driftY: -22, phase: phase2)
                particle(x: w * 0.42, y: h * 0.90, size: 2.6, baseOpacity: 0.18, driftY: -20, phase: phase2)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .drawingGroup()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                phase1 = true
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true).delay(1)) {
                phase2 = true
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

// MARK: - 4-Pointed Star Shape (kept for potential reuse)
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

#Preview {
    ZStack {
        AppTheme.bg.ignoresSafeArea()
        AmbientBackground()
        FloatingParticles()
        BlobView(size: 192)
    }
}
