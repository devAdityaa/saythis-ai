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
        HStack(alignment: .bottom, spacing: 10) {
            // ── Left side ──
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                if showAvatar {
                    // AI avatar — mini obsidian sphere (matches onboarding blob)
                    BlobView(size: 28, interactive: false)
                        .frame(width: 32, height: 32)
                } else {
                    // Invisible placeholder so bubbles align
                    Color.clear.frame(width: 32, height: 32)
                }
            }

            // ── Bubble ──
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                // Role label
                if showAvatar || isUser {
                    Text(isUser ? "YOU" : "SAYTHIS AI")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(
                            isUser
                                ? AppTheme.subtext.opacity(0.5)
                                : AppTheme.accent.opacity(0.4)
                        )
                        .padding(.horizontal, 2)
                }

                // Attachment previews
                ForEach(message.attachments) { attachment in
                    attachmentPreview(attachment)
                }

                // Message text
                if !message.content.isEmpty {
                    VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                        if isUser {
                            Text(message.content)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                                .textSelection(.enabled)
                        } else {
                            MarkdownTextView(text: message.content)
                        }

                        // Timestamp + copy
                        HStack(spacing: 6) {
                            Text(message.timestamp, style: .time)
                                .font(.system(size: 9))
                                .foregroundColor(
                                    isUser
                                        ? Color(red: 16/255, green: 34/255, blue: 34/255).opacity(0.5)
                                        : AppTheme.subtext.opacity(0.4)
                                )

                            if showCopy {
                                Button {
                                    UIPasteboard.general.string = message.content
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                } label: {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundColor(
                                            copied
                                                ? AppTheme.accent
                                                : (isUser
                                                    ? Color(red: 16/255, green: 34/255, blue: 34/255).opacity(0.4)
                                                    : AppTheme.subtext.opacity(0.35)
                                                )
                                        )
                                }
                                .animation(.easeOut(duration: 0.15), value: copied)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        isUser
                            ? AppTheme.accent                       // Solid cyan for user
                            : AppTheme.accent.opacity(0.05)        // Subtle tint for AI
                    )
                    .clipShape(
                        isUser
                            ? AnyShape(UnevenRoundedRectangle(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 4               // Flat top-right for user
                              ))
                            : AnyShape(UnevenRoundedRectangle(
                                topLeadingRadius: 4,               // Flat top-left for AI
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 16,
                                topTrailingRadius: 16
                              ))
                    )
                    .overlay(
                        Group {
                            if !isUser {
                                // Subtle border for AI bubbles
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 4,
                                    bottomLeadingRadius: 16,
                                    bottomTrailingRadius: 16,
                                    topTrailingRadius: 16
                                )
                                .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                            }
                        }
                    )
                    .shadow(
                        color: isUser ? AppTheme.accent.opacity(0.2) : .clear,
                        radius: isUser ? 12 : 0,
                        y: isUser ? 4 : 0
                    )
                }
            }

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
                    .foregroundColor(AppTheme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.accent.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
