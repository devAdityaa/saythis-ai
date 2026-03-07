import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()

    // Typing indicator — guard flag + phase
    @State private var typingStarted = false
    @State private var dotPhase: Int = 0

    var body: some View {
        @Bindable var vm = viewModel

        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ──
                chatTopBar

                // ── Messages ──
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            if viewModel.messages.isEmpty && !viewModel.isGenerating {
                                emptyState
                            }

                            // ── Message list with grouping logic ──
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in

                                let isLastInAssistantGroup: Bool = {
                                    guard message.role == .assistant else { return false }
                                    let next = index + 1
                                    if next >= viewModel.messages.count { return true }
                                    return viewModel.messages[next].role != .assistant
                                }()

                                let shouldShowCopy: Bool = {
                                    guard message.role == .assistant else { return false }
                                    if !viewModel.splitMode { return true }
                                    return message.isMainReply
                                }()

                                ChatBubbleView(
                                    message: message,
                                    showAvatar: isLastInAssistantGroup,
                                    showCopy: shouldShowCopy
                                )
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            // Typing indicator
                            if viewModel.isGenerating {
                                typingIndicator
                                    .id("typing")
                                    .transition(.opacity)
                            }

                            // Error
                            if let error = viewModel.errorMessage {
                                errorBanner(error)
                            }

                            // Bottom spacer for scroll
                            Color.clear.frame(height: 4).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .animation(.easeOut(duration: 0.25), value: viewModel.messages.count)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isGenerating) { _, generating in
                        if generating {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }

                // ── Input bar ──
                ChatInputBar(viewModel: viewModel)
            }

            // ── Sidebar overlay ──
            if viewModel.showSidebar {
                ZStack(alignment: .leading) {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.showSidebar = false
                            }
                        }

                    ChatSidebarView(viewModel: viewModel)
                        .frame(width: 285)
                        .transition(.move(edge: .leading))
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.showSidebar)
            }
        }
        .navigationBarHidden(true)
        .photosPicker(
            isPresented: $vm.showPhotoPicker,
            selection: $vm.selectedPhotoItem,
            matching: .images
        )
        .onChange(of: viewModel.selectedPhotoItem) { _, newItem in
            viewModel.handlePhotoPickerItem(newItem)
        }
        .fullScreenCover(isPresented: $vm.showCamera) {
            ChatCameraPickerView { image in
                if let image { viewModel.addImageAttachment(from: image) }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $vm.showDocumentPicker) {
            DocumentPickerView { url in
                viewModel.addDocumentAttachment(url: url)
            }
        }
        .onAppear {
            guard !typingStarted else { return }
            typingStarted = true
            startTypingAnimation()
        }
    }

    // MARK: - Top Bar
    private var chatTopBar: some View {
        HStack(spacing: 12) {
            // Sidebar toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showSidebar.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.card)
                    .clipShape(Circle())
            }

            // Title
            VStack(alignment: .leading, spacing: 1) {
                Text("Think")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.accent)
                if let conv = viewModel.currentConversation, conv.messages.count > 0 {
                    Text(conv.displayTitle)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.subtext)
                        .lineLimit(1)
                }
            }

            Spacer()

            // ── Split-mode toggle — compact circle, no text ──
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.splitMode.toggle()
                }
            } label: {
                Image(systemName: viewModel.splitMode
                      ? "rectangle.split.1x2.fill"
                      : "rectangle.split.1x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.splitMode ? AppTheme.accent : AppTheme.subtext.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(
                        viewModel.splitMode
                            ? AppTheme.accent.opacity(0.10)
                            : AppTheme.card
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                viewModel.splitMode ? AppTheme.accent.opacity(0.25) : Color.clear,
                                lineWidth: 1
                            )
                    )
            }

            // New chat
            Button {
                viewModel.startNewChat()
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.1))
                    .clipShape(Circle())
            }

            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.subtext)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.card)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppTheme.bg)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 80)

            // Use the app logo
            Image("persuadeKeyboardLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .shadow(color: AppTheme.accent.opacity(0.25), radius: 16, y: 4)

            Text("Think")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Your thinking space before you send.\nAsk for help with any message.")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.subtext)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Quick prompts
            VStack(spacing: 8) {
                quickPrompt("How should I respond to this?")
                quickPrompt("Make this message more polite")
                quickPrompt("Help me say no professionally")
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func quickPrompt(_ text: String) -> some View {
        Button {
            viewModel.inputText = text
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.accent)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.subtext)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
    }

    // MARK: - Typing Indicator (3 animated dots — contained)
    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Bot logo avatar
            Image("persuadeKeyboardLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 26, height: 26)
                .clipShape(Circle())

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppTheme.accent.opacity(dotPhase == i ? 0.9 : 0.35))
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotPhase == i ? 1.25 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.45), value: dotPhase)

            Spacer()
        }
    }

    private func startTypingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
    }

    // MARK: - Error banner
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13))
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.red.opacity(0.9))
            Spacer()
            Button {
                viewModel.errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Camera Picker (UIKit wrapper — same pattern as AnalyzeView)
struct ChatCameraPickerView: UIViewControllerRepresentable {
    let onPick: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ChatCameraPickerView
        init(_ parent: ChatCameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            parent.onPick(image)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onPick(nil)
            parent.dismiss()
        }
    }
}

// MARK: - Document Picker (UIKit wrapper)
struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf, .text, .plainText, .image, .png, .jpeg
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        init(_ parent: DocumentPickerView) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onPick(url)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ChatView()
}
