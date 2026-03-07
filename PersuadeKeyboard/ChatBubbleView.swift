import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    /// Show the bot avatar on this bubble (typically only the last in a consecutive assistant group).
    let showAvatar: Bool
    /// Show a copy icon on this bubble (reply-type messages, or all AI when split is off).
    let showCopy: Bool

    @State private var copied = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // ── Left side ──
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                if showAvatar {
                    // Bot logo avatar
                    Image("persuadeKeyboardLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                } else {
                    // Invisible placeholder so bubbles align
                    Color.clear.frame(width: 26, height: 26)
                }
            }

            // ── Bubble ──
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Attachment previews
                ForEach(message.attachments) { attachment in
                    attachmentPreview(attachment)
                }

                // Message text
                if !message.content.isEmpty {
                    if isUser {
                        Text(message.content)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                    } else {
                        MarkdownTextView(text: message.content)
                    }
                }

                // Timestamp row + optional copy icon
                HStack(spacing: 6) {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.subtext.opacity(0.4))

                    if showCopy {
                        Button {
                            UIPasteboard.general.string = message.content
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(copied ? AppTheme.accent : AppTheme.subtext.opacity(0.35))
                        }
                        .animation(.easeOut(duration: 0.15), value: copied)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isUser ? AppTheme.accent.opacity(0.12) : AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isUser ? AppTheme.accent.opacity(0.2) : Color.white.opacity(0.04),
                        lineWidth: 1
                    )
            )

            // ── Right side ──
            if !isUser { Spacer(minLength: 48) }
        }
    }

    // MARK: - Attachment previews
    @ViewBuilder
    private func attachmentPreview(_ attachment: ChatAttachment) -> some View {
        if attachment.type == .image, let img = attachment.thumbnail {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: 200, maxHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.accent)
                Text(attachment.fileName)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.card2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
