import SwiftUI

// MARK: - Shared theme — Premium dark-teal design system
enum AppTheme {
    // ── Core palette (from design: #13ecec primary, #102222 bg-dark) ──
    static let bg       = Color(red: 16/255, green: 34/255,  blue: 34/255)   // #102222
    static let card     = Color(red: 19/255, green: 236/255, blue: 236/255).opacity(0.05)  // primary/5
    static let card2    = Color(red: 19/255, green: 236/255, blue: 236/255).opacity(0.03)  // subtle variant
    static let accent   = Color(red: 19/255, green: 236/255, blue: 236/255)  // #13ecec
    static let text     = Color(red: 241/255, green: 245/255, blue: 249/255) // slate-100
    static let subtext  = Color(red: 148/255, green: 163/255, blue: 184/255) // slate-400
    static let danger   = Color.red

    // ── Surface colors ──
    static let surface       = Color(red: 19/255, green: 236/255, blue: 236/255).opacity(0.05)
    static let surfaceBorder = Color(red: 19/255, green: 236/255, blue: 236/255).opacity(0.10)

    // ── Glass / blur panel ──
    static let glassBackground = Color(red: 16/255, green: 34/255, blue: 34/255).opacity(0.80)

    // ── Gradients ──
    static let blobGradient = LinearGradient(
        colors: [
            Color(red: 42/255, green: 74/255, blue: 74/255),   // #2a4a4a
            Color(red: 16/255, green: 34/255, blue: 34/255)    // #102222
        ],
        startPoint: UnitPoint(x: 0.3, y: 0.3),
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accent, accent.opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
