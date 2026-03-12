import SwiftUI
import PhotosUI
import Observation

@Observable
final class ChatViewModel {
    // ─── Conversation state ───
    var currentConversation: Conversation?
    var messages: [ChatMessage] { currentConversation?.messages ?? [] }

    // ─── Input state ───
    var inputText: String = ""
    var pendingAttachments: [ChatAttachment] = []
    var selectedPhotoItem: PhotosPickerItem?

    // ─── UI state ───
    var isGenerating: Bool = false
    var errorMessage: String?
    var showSidebar: Bool = false
    var showPhotoPicker: Bool = false
    var showDocumentPicker: Bool = false
    var showCamera: Bool = false

    // ─── Contextual quick-action chips (hidden until first AI response) ───
    var contextualChips: [String] = []

    // ─── Split-mode toggle ───
    // When ON: each AI response is split into a context bubble + a main-reply
    // bubble so the user can copy just the reply without surrounding text.
    // Persisted per-user in UserDefaults.standard.
    var splitMode: Bool = false {
        didSet {
            UserDefaults.standard.set(splitMode, forKey: Self.splitModeKey)
        }
    }

    private static var splitModeKey: String {
        let email = UserScopedStorage.currentUserEmail ?? ""
        return email.isEmpty ? "chat_split_mode" : "chat_split_mode|\(email)"
    }

    // ─── Dependencies ───
    let store: ConversationStore
    private let api = ChatAPIService.shared

    init(store: ConversationStore = ConversationStore()) {
        self.store = store
        self.splitMode = UserDefaults.standard.bool(forKey: Self.splitModeKey)
    }

    // MARK: - Conversation Management

    func startNewChat() {
        let conv = store.create()
        currentConversation = conv
        inputText = ""
        pendingAttachments = []
        errorMessage = nil
    }

    func loadConversation(_ conversation: Conversation) {
        currentConversation = conversation
        showSidebar = false
        inputText = ""
        pendingAttachments = []
        errorMessage = nil
    }

    func deleteConversation(_ conversation: Conversation) {
        store.delete(conversation)
        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        // Create user message
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            attachments: pendingAttachments
        )

        // Create conversation if needed
        if currentConversation == nil {
            startNewChat()
        }

        // Append user message
        currentConversation?.messages.append(userMessage)
        currentConversation?.updatedAt = Date()
        if let conv = currentConversation { store.save(conv) }

        // Clear input
        inputText = ""
        pendingAttachments = []
        errorMessage = nil
        isGenerating = true
        contextualChips = []

        // Call API
        let isSplit = splitMode
        api.sendMessage(messages: currentConversation!.messages, splitMode: isSplit) { [weak self] result in
            guard let self else { return }
            self.isGenerating = false

            switch result {
            case .success(let reply):
                // Parse AI-generated chips from response
                let (cleanReply, aiChips) = Self.parseChipsFromResponse(reply)

                if isSplit {
                    // Parse [CONTEXT] + multiple [REPLY] markers into separate bubbles
                    let (context, replies) = Self.parseSplitReply(cleanReply)
                    if let ctx = context, !ctx.isEmpty {
                        self.currentConversation?.messages.append(
                            ChatMessage(role: .assistant, content: ctx, isMainReply: false)
                        )
                    }
                    for replyText in replies {
                        self.currentConversation?.messages.append(
                            ChatMessage(role: .assistant, content: replyText, isMainReply: true)
                        )
                    }
                } else {
                    self.currentConversation?.messages.append(
                        ChatMessage(role: .assistant, content: cleanReply)
                    )
                }
                self.currentConversation?.updatedAt = Date()
                if let conv = self.currentConversation { self.store.save(conv) }

                // Use AI-generated chips if available, otherwise fall back to local heuristic
                if !aiChips.isEmpty {
                    self.contextualChips = aiChips
                } else {
                    self.generateContextualChips(userMessage: text, aiResponse: cleanReply)
                }

            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Split-reply parser
    /// Splits the AI response on **multiple** [REPLY] markers.
    /// Returns (contextText, [replyTexts]). Falls back to (nil, [fullText])
    /// when no marker is found so the feature degrades gracefully.
    static func parseSplitReply(_ text: String) -> (context: String?, replies: [String]) {
        let parts = text.components(separatedBy: "[REPLY]")
        guard parts.count > 1 else {
            // No [REPLY] marker — treat the whole response as a single reply
            return (nil, [text.trimmingCharacters(in: .whitespacesAndNewlines)])
        }

        // First element is everything before the first [REPLY] (the context)
        let rawContext = parts[0]
            .replacingOccurrences(of: "[CONTEXT]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remaining elements are individual reply options
        let replies = parts.dropFirst().compactMap { part -> String? in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return (rawContext.isEmpty ? nil : rawContext,
                replies.isEmpty ? [text.trimmingCharacters(in: .whitespacesAndNewlines)] : replies)
    }

    // MARK: - Attachment Handling

    func addImageAttachment(from image: UIImage) {
        guard let attachment = ChatAttachment.fromImage(image) else { return }
        pendingAttachments.append(attachment)
    }

    func addDocumentAttachment(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }

        let mimeType = mimeTypeForURL(url)
        let attachment = ChatAttachment(
            type: .document,
            fileName: url.lastPathComponent,
            base64Data: data.base64EncodedString(),
            mimeType: mimeType
        )
        pendingAttachments.append(attachment)
    }

    func removeAttachment(_ attachment: ChatAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }

    func handlePhotoPickerItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        item.loadTransferable(type: Data.self) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let data) = result, let data, let image = UIImage(data: data) {
                    self?.addImageAttachment(from: image)
                }
            }
        }
    }

    // MARK: - Helpers

    private func mimeTypeForURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":  return "application/pdf"
        case "txt":  return "text/plain"
        case "png":  return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "doc":  return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "csv":  return "text/csv"
        default:     return "application/octet-stream"
        }
    }

    // MARK: - Parse AI-generated chips from response
    /// Extracts `[CHIPS] a | b | c` from the end of the AI response.
    /// Returns the clean text (without the chips line) and parsed chip labels.
    static func parseChipsFromResponse(_ text: String) -> (cleanText: String, chips: [String]) {
        let lines = text.components(separatedBy: "\n")
        // Search from the end for a [CHIPS] line
        for i in stride(from: lines.count - 1, through: max(0, lines.count - 5), by: -1) {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[CHIPS]") {
                let raw = line.replacingOccurrences(of: "[CHIPS]", with: "").trimmingCharacters(in: .whitespaces)
                let chips = raw.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                let cleanLines = Array(lines[0..<i])
                let cleanText = cleanLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                return (cleanText, Array(chips.prefix(3)))
            }
        }
        return (text, [])
    }

    // MARK: - Contextual chip generation (local fallback)
    private func generateContextualChips(userMessage: String, aiResponse: String) {
        let lower = userMessage.lowercased()
        var chips: [String] = []

        // Intent-based suggestions
        if lower.contains("no") || lower.contains("decline") || lower.contains("refuse") || lower.contains("reject") {
            chips.append("Make it firmer")
        }
        if lower.contains("sorry") || lower.contains("apologize") || lower.contains("apology") {
            chips.append("Sound more sincere")
        }
        if lower.contains("email") || lower.contains("professional") || lower.contains("formal") || lower.contains("work") {
            chips.append("More formal")
        }
        if aiResponse.count > 250 || lower.contains("shorter") || lower.contains("brief") || lower.contains("concise") {
            chips.append("Make it shorter")
        }
        if lower.contains("assertive") || lower.contains("confident") || lower.contains("bold") {
            chips.append("More assertive")
        }
        if lower.contains("polite") || lower.contains("kind") || lower.contains("gentle") {
            chips.append("More polite")
        }
        if lower.contains("urgent") || lower.contains("deadline") || lower.contains("asap") {
            chips.append("Add urgency")
        }

        // Pad to 3 with smart defaults
        let defaults = ["Rephrase this", "Make it shorter", "More assertive", "More casual", "Add detail", "Simpler words"]
        for d in defaults where chips.count < 3 {
            if !chips.contains(d) { chips.append(d) }
        }

        contextualChips = Array(chips.prefix(3))
    }

    var canSend: Bool {
        !isGenerating &&
        (!inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty)
    }
}
