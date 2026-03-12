import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ChatViewModel()

    // Typing indicator
    @State private var typingStarted = false
    @State private var dotPhase: Int = 0
    @State private var blobPulse = false

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            // ── Header ──
            chatHeader

            // ── Messages ──
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if viewModel.messages.isEmpty && !viewModel.isGenerating {
                            emptyState
                        }

                        // ── Status pill ──
                        if !viewModel.messages.isEmpty {
                            statusPill
                                .padding(.bottom, 8)
                        }

                        // ── Message list ──
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

                        // Bottom spacer
                        Color.clear.frame(height: 4).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .animation(.easeOut(duration: 0.25), value: viewModel.messages.count)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                )
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
        .background(AppTheme.bg)
        .overlay {
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

    // MARK: - Header (matches design workspace header)
    private var chatHeader: some View {
        HStack(spacing: 12) {
            // Sidebar toggle with icon container
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showSidebar.toggle()
                }
            } label: {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 1) {
                Text("Think")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.text)
                Text("WORKSPACE MODE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(AppTheme.accent.opacity(0.6))
            }

            Spacer()

            // Split-mode toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.splitMode.toggle()
                }
            } label: {
                Image(systemName: viewModel.splitMode
                      ? "rectangle.split.1x2.fill"
                      : "rectangle.split.1x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.splitMode ? AppTheme.accent : AppTheme.subtext)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.08))
                    .clipShape(Circle())
            }

            // Chat history
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showSidebar.toggle()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.subtext)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.accent.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            AppTheme.glassBackground
                .overlay(
                    Rectangle()
                        .fill(AppTheme.surfaceBorder)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Status Pill
    private var statusPill: some View {
        HStack {
            Spacer()
            Text("Drafting Session \u{2022} Active")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundColor(AppTheme.accent.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                )
            Spacer()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)

            // AI avatar blob
            BlobView(size: 88, interactive: false)

            Text(RemoteConfigService.shared.cached?.ui.thinkEmptyStateTitle ?? "Think")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppTheme.text)

            Text({
                let t = RemoteConfigService.shared.cached?.ui.thinkEmptyStateSubtitle
                return (t?.isEmpty == false ? t : nil) ?? "Your thinking space before you send.\nAsk for help with any message."
            }())
                .font(.system(size: 14))
                .foregroundColor(AppTheme.subtext)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Quick prompts
            VStack(spacing: 8) {
                let configPrompts = RemoteConfigService.shared.cached?.ui.quickPrompts
                let prompts = (configPrompts?.isEmpty == false ? configPrompts : nil) ?? [
                    "How should I respond to this?",
                    "Make this message more polite",
                    "Help me say no professionally"
                ]
                ForEach(prompts, id: \.self) { prompt in
                    quickPrompt(prompt)
                }
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
            .background(AppTheme.accent.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
            )
        }
    }

    // MARK: - Typing Indicator (design: pulsing blob + italic text)
    private var typingIndicator: some View {
        HStack(spacing: 8) {
            // AI avatar blob — fades in/out while drafting
            BlobView(size: 28, interactive: false)
                .frame(width: 28, height: 28)
                .opacity(blobPulse ? 1.0 : 0.35)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: blobPulse)
                .onAppear { blobPulse = true }
                .onDisappear { blobPulse = false }

            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.accent.opacity(0.3))
                Text("Drafting alternatives...")
                    .font(.system(size: 11, weight: .medium))
                    .italic()
                    .foregroundColor(AppTheme.accent.opacity(0.3))
            }

            Spacer()
        }
        .padding(.leading, 4)
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

// MARK: - Camera Picker (UIKit wrapper)
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
