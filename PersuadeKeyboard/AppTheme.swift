import SwiftUI

// MARK: - Shared theme used across the entire app
enum AppTheme {
    // Core palette
    static let bg       = Color(red: 9/255,   green: 14/255,  blue: 23/255)
    static let card     = Color(red: 18/255,  green: 30/255,  blue: 46/255)
    static let card2    = Color(red: 14/255,  green: 24/255,  blue: 38/255)
    static let accent   = Color(red: 0/255,   green: 200/255, blue: 200/255)
    static let text     = Color.white
    static let subtext  = Color(white: 0.72)
    static let danger   = Color.red

    // Gradient used on the blob / glow
    static let blobGradient = LinearGradient(
        colors: [
            Color(red: 0/255, green: 180/255, blue: 220/255),
            Color(red: 30/255, green: 80/255, blue: 180/255),
            Color(red: 60/255, green: 40/255, blue: 160/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [accent, Color(red: 0/255, green: 160/255, blue: 200/255)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
