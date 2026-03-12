import SwiftUI

struct ChatSidebarView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──
            HStack {
                Text("Chats")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.text)
                Spacer()
                Button {
                    viewModel.startNewChat()
                    viewModel.showSidebar = false
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 60)
            .padding(.bottom, 18)

            Rectangle()
                .fill(AppTheme.surfaceBorder)
                .frame(height: 1)

            // ── Conversation list ──
            if viewModel.store.conversations.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.subtext.opacity(0.2))
                    Text("No conversations yet")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.subtext.opacity(0.5))
                    Text("Start a new chat to begin")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.subtext.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.store.conversations) { conversation in
                            conversationRow(conversation)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(AppTheme.bg)
        .ignoresSafeArea(edges: .vertical)
    }

    // MARK: - Conversation row
    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            viewModel.loadConversation(conversation)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(isActive(conversation) ? AppTheme.accent.opacity(0.15) : AppTheme.accent.opacity(0.05))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 13))
                            .foregroundColor(isActive(conversation) ? AppTheme.accent : AppTheme.subtext.opacity(0.5))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.displayTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isActive(conversation) ? AppTheme.text : AppTheme.subtext)
                        .lineLimit(1)

                    Text(relativeTime(conversation.updatedAt))
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.subtext.opacity(0.45))
                }

                Spacer()

                if conversation.messages.count > 0 {
                    Text("\(conversation.messages.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(AppTheme.subtext.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.accent.opacity(0.05))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isActive(conversation) ? AppTheme.accent.opacity(0.06) : Color.clear
            )
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func isActive(_ conversation: Conversation) -> Bool {
        viewModel.currentConversation?.id == conversation.id
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
