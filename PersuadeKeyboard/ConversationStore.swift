import Foundation
import Observation

@Observable
final class ConversationStore {
    private(set) var conversations: [Conversation] = []

    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Directory (user-scoped)
    //
    // Path: ~/Documents/PersuadeChats/<user_folder>/
    // The folder name is derived from the signed-in user's email so conversations
    // from different accounts are never mixed on the same device.

    private var directory: URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs
            .appendingPathComponent("PersuadeChats", isDirectory: true)
            .appendingPathComponent(UserScopedStorage.userDirectoryName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// The old flat directory used before per-user scoping was added.
    private var legacyDirectory: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PersuadeChats", isDirectory: true)
    }

    // MARK: - Init

    init() {
        migrateFromLegacyDirectoryIfNeeded()
        loadAll()
    }

    // MARK: - Load all conversations for the current user

    func loadAll() {
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "json" }) else {
            conversations = []
            return
        }

        var loaded: [Conversation] = []
        for file in files {
            if let data = try? Data(contentsOf: file),
               let conv = try? decoder.decode(Conversation.self, from: data) {
                loaded.append(conv)
            }
        }
        conversations = loaded.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Call after a new user signs in so the store reloads from their own directory.
    func reloadForCurrentUser() {
        conversations = []
        loadAll()
    }

    /// Clears the in-memory list on sign-out (files stay on disk for next login).
    func clearForSignOut() {
        conversations = []
    }

    // MARK: - Save

    func save(_ conversation: Conversation) {
        let url = fileURL(for: conversation.id)
        if let data = try? encoder.encode(conversation) {
            try? data.write(to: url, options: .atomic)
        }
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx] = conversation
        } else {
            conversations.insert(conversation, at: 0)
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Delete

    func delete(_ conversation: Conversation) {
        let url = fileURL(for: conversation.id)
        try? fm.removeItem(at: url)
        conversations.removeAll { $0.id == conversation.id }
    }

    // MARK: - Create

    @discardableResult
    func create() -> Conversation {
        let conv = Conversation()
        save(conv)
        return conv
    }

    // MARK: - Helpers

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    // MARK: - One-time migration from the legacy flat directory
    //
    // Before scoping was added, JSON files lived directly in ~/Documents/PersuadeChats/.
    // On first launch after an update, move any loose files into the current user's
    // subfolder so their chat history is preserved.

    private func migrateFromLegacyDirectoryIfNeeded() {
        guard fm.fileExists(atPath: legacyDirectory.path) else { return }

        let legacyFiles = (try? fm.contentsOfDirectory(
            at: legacyDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return !isDir && url.pathExtension == "json"
        }) ?? []

        guard !legacyFiles.isEmpty else { return }

        for file in legacyFiles {
            let dest = directory.appendingPathComponent(file.lastPathComponent)
            if !fm.fileExists(atPath: dest.path) {
                try? fm.moveItem(at: file, to: dest)
            } else {
                try? fm.removeItem(at: file)
            }
        }
    }
}
