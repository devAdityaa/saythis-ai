import Foundation

// MARK: - Generation Mode Model

struct GenerationMode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String              // SF Symbol name
    var baseSystemPrompt: String  // Internal prompt (not shown/editable for built-ins)
    var userInstructions: String  // User's extra instructions, appended to base prompt
    var inputSource: InputSource
    var isBuiltIn: Bool           // Reply & Refine cannot be deleted

    enum InputSource: String, Codable {
        case clipboard  // reads UIPasteboard (Reply)
        case textField  // reads textDocumentProxy (Refine)
    }

    /// Combined prompt sent to AI
    var effectiveSystemPrompt: String {
        let extra = userInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extra.isEmpty else { return baseSystemPrompt }
        return baseSystemPrompt + "\n\nAdditional instructions from user:\n" + extra
    }
}

// MARK: - Built-in Defaults

extension GenerationMode {

    static var defaultReply: GenerationMode {
        GenerationMode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Reply",
            icon: "arrowshape.turn.up.left.fill",
            baseSystemPrompt: """
You are a reply suggestion assistant for any conversation. The user will provide a message they received. Generate exactly 3 short, natural reply suggestions. Each reply should take a different angle — vary the tone and approach. Return ONLY a valid JSON array of exactly 3 strings with no other text, no labels, no explanations. Example format: ["Reply one.", "Reply two.", "Reply three."]
""",
            userInstructions: "",
            inputSource: .clipboard,
            isBuiltIn: true
        )
    }

    static var defaultRefine: GenerationMode {
        GenerationMode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Refine",
            icon: "sparkle.magnifyingglass",
            baseSystemPrompt: """
You are a message improvement assistant. The user will provide a message they have drafted. Generate exactly 3 improved versions of their message — each clearer, more professional, and impactful while preserving the core intent and meaning. Vary the approach slightly across the 3 versions. Return ONLY a valid JSON array of exactly 3 strings with no other text, no labels, no explanations. Example format: ["Improved version one.", "Improved version two.", "Improved version three."]
""",
            userInstructions: "",
            inputSource: .textField,
            isBuiltIn: true
        )
    }

    static var defaultModes: [GenerationMode] { [defaultReply, defaultRefine] }
}

// MARK: - Mode Store

enum GenerationModeStore {

    private static let appGroupID = "group.com.goatedx.persuade"
    private static let modesBaseKey = "keyboard_generation_modes"
    private static let legacyPromptBaseKey = "custom_system_prompt"

    // ── Scoped key helpers (mirrors UserScopedStorage) ──

    private static var currentUserEmail: String? {
        UserDefaults(suiteName: appGroupID)?.string(forKey: "user_email")
    }

    private static func scopedKey(_ base: String) -> String {
        guard let email = currentUserEmail, !email.isEmpty else { return base }
        return "\(base)|\(email)"
    }

    // ── Load ──

    static func loadModes() -> [GenerationMode] {
        let key = scopedKey(modesBaseKey)
        let ud = UserDefaults(suiteName: appGroupID)

        if let data = ud?.data(forKey: key),
           var modes = try? JSONDecoder().decode([GenerationMode].self, from: data),
           !modes.isEmpty {
            // One-time cleanup: remove old default prompt that was incorrectly
            // migrated into built-in modes' userInstructions
            var didClean = false
            for i in modes.indices where modes[i].isBuiltIn {
                let ui = modes[i].userInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
                if ui.contains("Generate exactly 3 short, natural reply suggestions")
                    && ui.contains("Return ONLY a JSON array") {
                    modes[i].userInstructions = ""
                    didClean = true
                }
            }
            if didClean { saveModes(modes) }
            return ensureBuiltInsPresent(in: modes)
        }

        // First launch — migrate legacy custom prompt if any, then create defaults
        let defaults = GenerationMode.defaultModes
        var migrated = defaults
        let legacyKey = scopedKey(legacyPromptBaseKey)
        if let legacy = ud?.string(forKey: legacyKey),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Only migrate if user actually wrote custom instructions
            // (skip if it's the old default prompt)
            let trimmed = legacy.trimmingCharacters(in: .whitespacesAndNewlines)
            let isOldDefault = trimmed.contains("Generate exactly 3 short, natural reply suggestions")
                && trimmed.contains("Return ONLY a JSON array")
            if !isOldDefault {
                migrated[0].userInstructions = legacy
            }
        }
        saveModes(migrated)
        return migrated
    }

    // ── Save ──

    static func saveModes(_ modes: [GenerationMode]) {
        let key = scopedKey(modesBaseKey)
        guard let data = try? JSONEncoder().encode(modes) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: key)
        UserDefaults.standard.set(data, forKey: key)
    }

    // ── Ensure built-in modes always exist (in case of data corruption) ──

    private static func ensureBuiltInsPresent(in modes: [GenerationMode]) -> [GenerationMode] {
        var result = modes
        let replyID = GenerationMode.defaultReply.id
        let refineID = GenerationMode.defaultRefine.id
        if !result.contains(where: { $0.id == replyID }) {
            result.insert(GenerationMode.defaultReply, at: 0)
        }
        if !result.contains(where: { $0.id == refineID }) {
            let insertAt = min(1, result.count)
            result.insert(GenerationMode.defaultRefine, at: insertAt)
        }
        return result
    }
}
