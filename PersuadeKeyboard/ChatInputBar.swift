import SwiftUI
import PhotosUI

struct ChatInputBar: View {
    @Bindable var viewModel: ChatViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Thin separator
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)

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
                .background(AppTheme.card2.opacity(0.5))
            }

            // Input row
            HStack(alignment: .bottom, spacing: 10) {
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
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(AppTheme.accent.opacity(0.8))
                }

                // Text field
                TextField("Type a message…", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )

                // Send button
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundColor(viewModel.canSend ? AppTheme.accent : AppTheme.subtext.opacity(0.25))
                }
                .disabled(!viewModel.canSend)
                .animation(.easeOut(duration: 0.15), value: viewModel.canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.bg)
        }
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
                .background(AppTheme.card)
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
