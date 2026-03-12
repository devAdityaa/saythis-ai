import SwiftUI
import PhotosUI

struct ChatInputBar: View {
    @Bindable var viewModel: ChatViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Thin separator
            Rectangle()
                .fill(AppTheme.surfaceBorder)
                .frame(height: 1)

            // Pending attachment strip
            if !viewModel.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.pendingAttachments) { attachment in
                            attachmentChip(attachment)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(AppTheme.accent.opacity(0.03))
            }

            // ── Contextual quick-action chips — only after first AI response ──
            if !viewModel.contextualChips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.contextualChips, id: \.self) { chip in
                            quickActionChip(icon: chipIcon(for: chip), label: chip)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeOut(duration: 0.3), value: viewModel.contextualChips)
            }

            // ── Input row ──
            HStack(alignment: .center, spacing: 8) {
                // Attachment menu
                Menu {
                    Button {
                        viewModel.showPhotoPicker = true
                    } label: {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        viewModel.showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }

                    Button {
                        viewModel.showDocumentPicker = true
                    } label: {
                        Label("Document", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22))
                        .foregroundColor(AppTheme.accent.opacity(0.5))
                        .frame(width: 32, height: 32)
                }

                // Text field
                TextField("Refine my thought...", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.text)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .tint(AppTheme.accent)

                // Send button
                Button {
                    isFocused = false
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                        .frame(width: 32, height: 32)
                        .background(
                            viewModel.canSend
                                ? AppTheme.accent
                                : AppTheme.subtext.opacity(0.15)
                        )
                        .clipShape(Circle())
                        .shadow(
                            color: viewModel.canSend
                                ? AppTheme.accent.opacity(0.3)
                                : .clear,
                            radius: 6, y: 2
                        )
                }
                .disabled(!viewModel.canSend)
                .animation(.easeOut(duration: 0.15), value: viewModel.canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.accent.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Quick action chip
    private func quickActionChip(icon: String, label: String) -> some View {
        Button {
            viewModel.inputText = label
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.accent)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.text)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.accent.opacity(0.05))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(AppTheme.accent.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chip icon helper
    private func chipIcon(for chip: String) -> String {
        let lower = chip.lowercased()
        if lower.contains("shorter") || lower.contains("brief") || lower.contains("concise") { return "text.badge.minus" }
        if lower.contains("assertive") || lower.contains("firm") || lower.contains("bold") { return "bolt.fill" }
        if lower.contains("formal") || lower.contains("professional") { return "briefcase" }
        if lower.contains("polite") || lower.contains("kind") { return "heart" }
        if lower.contains("casual") { return "bubble.left" }
        if lower.contains("rephrase") || lower.contains("rewrite") { return "arrow.triangle.2.circlepath" }
        if lower.contains("sincere") || lower.contains("say no") { return "hand.raised" }
        if lower.contains("detail") || lower.contains("longer") { return "text.badge.plus" }
        if lower.contains("urgent") { return "exclamationmark.circle" }
        if lower.contains("simple") || lower.contains("simpler") { return "textformat.size" }
        return "wand.and.stars"
    }

    // MARK: - Attachment chip with remove button
    @ViewBuilder
    private func attachmentChip(_ attachment: ChatAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            if attachment.type == .image, let img = attachment.thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.accent)
                    Text(attachment.fileName)
                        .font(.system(size: 8))
                        .foregroundColor(AppTheme.subtext)
                        .lineLimit(1)
                }
                .frame(width: 56, height: 56)
                .background(AppTheme.accent.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Remove button
            Button {
                viewModel.removeAttachment(attachment)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white, Color.black.opacity(0.65))
            }
            .offset(x: 6, y: -6)
        }
    }
}
