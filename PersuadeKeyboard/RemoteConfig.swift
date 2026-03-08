import Foundation
import os

// MARK: - Remote Config Models

struct RemoteConfig: Codable {
    let version: Int
    let updatedAt: String
    let globalConfig: RCGlobalConfig
    let thinkChat: RCThinkChatConfig
    let screenshotReply: RCScreenshotReplyConfig
    let keyboard: RCKeyboardConfig
    let ui: RCUIConfig
    let toneStyles: [RCToneStyle]
}

struct RCGlobalConfig: Codable {
    let defaultModel: String
    let visionModel: String
    let appKillSwitch: Bool
    let maintenanceMessage: String?
    let minimumAppVersion: String
    let rateLimitPerUser: Int
    let rateLimitWindow: String
}

struct RCThinkChatConfig: Codable {
    let model: String
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let systemPrompt: String
    let splitModeInstruction: String
}

struct RCScreenshotReplyConfig: Codable {
    let model: String
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let imageDetail: String
    let channels: RCChannels
}

struct RCChannels: Codable {
    let linkedin: RCChannelConfig
    let whatsapp: RCChannelConfig
    let email: RCChannelConfig
}

struct RCChannelConfig: Codable {
    let systemPrompt: String
    let userPrompt: String
}

struct RCKeyboardConfig: Codable {
    let model: String
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let builtInModes: RCBuiltInModes
}

struct RCBuiltInModes: Codable {
    let reply: RCModeConfig
    let refine: RCModeConfig
}

struct RCModeConfig: Codable {
    let name: String
    let icon: String
    let systemPrompt: String
}

struct RCUIConfig: Codable {
    let appTagline: String
    let thinkEmptyStateTitle: String
    let thinkEmptyStateSubtitle: String
    let quickPrompts: [String]
    let proTipText: String
    let landingBadge: String
    let landingSubtitle: String
    let typewriterWords: [String]
    let featureRows: [RCFeatureRow]
}

struct RCFeatureRow: Codable {
    let icon: String
    let text: String
}

struct RCToneStyle: Codable {
    let id: String
    let label: String
    let description: String
}

// MARK: - Debug Logger (uses os.Logger — visible in Console.app and Xcode)

enum SayThisLog {
    private static let logger = Logger(subsystem: "com.goatedx.persuade", category: "SayThis")

    static func config(_ msg: String) { logger.info("🔧 [Config] \(msg, privacy: .public)") }
    static func api(_ msg: String)    { logger.info("🤖 [API]    \(msg, privacy: .public)") }
    static func warn(_ msg: String)   { logger.warning("⚠️ [WARN]  \(msg, privacy: .public)") }
    static func error(_ msg: String)  { logger.error("❌ [ERROR] \(msg, privacy: .public)") }

    /// Truncates long strings for readable log output
    static func preview(_ text: String, length: Int = 80) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > length else { return trimmed }
        return String(trimmed.prefix(length)) + "…"
    }
}

// MARK: - Remote Config Service

final class RemoteConfigService {
    static let shared = RemoteConfigService()
    private init() {}

    private static let configURL = URL(string: "https://bokcfsexepjshdttndbn.supabase.co/functions/v1/get-config")!
    private static let authToken = "saythis2026"

    /// In-memory reference for UI reads (taglines, feature rows, etc.)
    private var _cached: RemoteConfig?
    var cached: RemoteConfig? { _cached }

    // MARK: - Fire-and-forget fetch (app launch, UI refresh)

    func fetchConfig() {
        fetchConfig { _ in }
    }

    // MARK: - Completion-based fetch (called before every API call)

    func fetchConfig(completion: @escaping (RemoteConfig?) -> Void) {
        SayThisLog.config("Fetching from \(Self.configURL.absoluteString)")

        var request = URLRequest(url: Self.configURL)
        request.setValue("Bearer \(Self.authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // ── Network error ──
            if let error {
                SayThisLog.error("Config fetch network error: \(error.localizedDescription)")
                SayThisLog.warn("Using in-memory fallback: \(self?._cached == nil ? "nil (will use hardcoded defaults)" : "v\(self?._cached?.version ?? -1)")")
                completion(self?._cached)
                return
            }

            // ── HTTP error ──
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                SayThisLog.error("Config fetch HTTP \(http.statusCode): \(body.prefix(200))")
                SayThisLog.warn("Using in-memory fallback: \(self?._cached == nil ? "nil (will use hardcoded defaults)" : "v\(self?._cached?.version ?? -1)")")
                completion(self?._cached)
                return
            }

            // ── No data ──
            guard let data else {
                SayThisLog.error("Config fetch returned no data")
                completion(self?._cached)
                return
            }

            // ── Decode error ──
            guard let config = try? JSONDecoder().decode(RemoteConfig.self, from: data) else {
                let raw = String(data: data, encoding: .utf8) ?? "unreadable"
                SayThisLog.error("Config JSON decode failed. Raw response: \(raw.prefix(300))")
                completion(self?._cached)
                return
            }

            // ── Success ──
            SayThisLog.config("✅ Fetched config v\(config.version) (updated: \(config.updatedAt))")
            SayThisLog.config("ThinkChat model: \(config.thinkChat.model), temp: \(config.thinkChat.temperature)")
            SayThisLog.config("ScreenshotReply model: \(config.screenshotReply.model), temp: \(config.screenshotReply.temperature)")
            SayThisLog.config("Keyboard model: \(config.keyboard.model), temp: \(config.keyboard.temperature)")
            SayThisLog.config("ThinkChat prompt preview: \(SayThisLog.preview(config.thinkChat.systemPrompt))")

            self?._cached = config
            completion(config)
        }.resume()
    }
}
