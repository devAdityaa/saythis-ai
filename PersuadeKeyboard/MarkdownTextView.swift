import SwiftUI

/// Renders markdown text from AI responses with proper styling
struct MarkdownTextView: View {
    let text: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.text.opacity(0.92))
                .lineSpacing(4)
                .textSelection(.enabled)
                .tint(AppTheme.accent)
        } else {
            // Fallback: plain text
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.text.opacity(0.92))
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
}
