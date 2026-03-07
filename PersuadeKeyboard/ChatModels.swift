import Foundation
import UIKit

// MARK: - Attachment Type
enum AttachmentType: String, Codable {
    case image
    case document
}

// MARK: - Chat Attachment
struct ChatAttachment: Identifiable, Codable {
    let id: UUID
    let type: AttachmentType
    let fileName: String
    let base64Data: String
    let mimeType: String

    init(id: UUID = UUID(), type: AttachmentType, fileName: String, base64Data: String, mimeType: String) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.base64Data = base64Data
        self.mimeType = mimeType
    }

    /// Convenience: create from UIImage
    static func fromImage(_ image: UIImage, quality: CGFloat = 0.6) -> ChatAttachment? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }
        return ChatAttachment(
            type: .image,
            fileName: "image_\(Int(Date().timeIntervalSince1970)).jpg",
            base64Data: data.base64EncodedString(),
            mimeType: "image/jpeg"
        )
    }

    /// Convenience: thumbnail UIImage from base64
    var thumbnail: UIImage? {
        guard type == .image, let data = Data(base64Encoded: base64Data) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Message Role
enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let attachments: [ChatAttachment]
    let timestamp: Date
    /// When split-mode is ON, the AI response is broken into two messages:
    /// a context bubble (isMainReply = false) and the ready-to-send reply
    /// bubble (isMainReply = true) which gets the prominent copy treatment.
    var isMainReply: Bool

    init(id: UUID = UUID(), role: MessageRole, content: String, attachments: [ChatAttachment] = [], timestamp: Date = Date(), isMainReply: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.attachments = attachments
        self.timestamp = timestamp
        self.isMainReply = isMainReply
    }
}

// MARK: - Conversation
struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Chat", messages: [ChatMessage] = [], createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Auto-generate title from first user message
    var displayTitle: String {
        if title != "New Chat" { return title }
        if let firstUserMsg = messages.first(where: { $0.role == .user }) {
            let trimmed = firstUserMsg.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = String(trimmed.prefix(40))
            return prefix.count < trimmed.count ? prefix + "…" : prefix
        }
        return "New Chat"
    }
}
