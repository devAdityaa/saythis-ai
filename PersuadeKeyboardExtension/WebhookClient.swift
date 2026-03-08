import Foundation
import os

private let kbLogger = Logger(subsystem: "com.goatedx.persuade.keyboard", category: "SayThisKB")

// MARK: - API Key Storage
//
// The keyboard extension is a separate process and reads the global internal
// API key written to the App Group by GlobalConfig.seedKeyToAppGroup() on launch.
enum APIKeyStore {
    static let appGroupID = "group.com.goatedx.persuade"

    static var currentUserEmail: String? {
        UserDefaults(suiteName: appGroupID)?.string(forKey: "user_email")
    }

    static func scopedKey(_ base: String) -> String {
        guard let email = currentUserEmail, !email.isEmpty else { return base }
        return "\(base)|\(email)"
    }

    /// Global internal key — shared across all accounts, written by the main app on launch.
    static var apiKey: String? {
        if let gd = UserDefaults(suiteName: appGroupID),
           let k = gd.string(forKey: "global_openai_api_key"), !k.isEmpty { return k }
        return nil
    }
}

// MARK: - Generation Mode (mirror of main app's GenerationMode)
// Replicated here since the keyboard extension is a separate process.

struct KBGenerationMode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var baseSystemPrompt: String
    var userInstructions: String
    var inputSource: KBInputSource
    var isBuiltIn: Bool

    enum KBInputSource: String, Codable {
        case clipboard
        case textField
    }

    var effectiveSystemPrompt: String {
        let extra = userInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extra.isEmpty else { return baseSystemPrompt }
        return baseSystemPrompt + "\n\nAdditional instructions from user:\n" + extra
    }
}

// MARK: - Mode Store (keyboard extension side)

enum KBModeStore {
    private static let modesBaseKey = "keyboard_generation_modes"

    static func loadModes() -> [KBGenerationMode] {
        let key = APIKeyStore.scopedKey(modesBaseKey)
        let ud = UserDefaults(suiteName: APIKeyStore.appGroupID)

        if let data = ud?.data(forKey: key),
           let modes = try? JSONDecoder().decode([KBGenerationMode].self, from: data),
           !modes.isEmpty {
            return modes
        }

        // Fall back to built-in defaults if nothing stored yet
        return KBModeStore.builtInDefaults()
    }

    private static let fallbackReplyPrompt = "You are a reply suggestion assistant for any conversation. The user will provide a message they received. Generate exactly 3 short, natural reply suggestions. Each reply should take a different angle — vary the tone and approach. Return ONLY a valid JSON array of exactly 3 strings with no other text, no labels, no explanations. Example format: [\"Reply one.\", \"Reply two.\", \"Reply three.\"]"

    private static let fallbackRefinePrompt = "You are a message improvement assistant. The user will provide a message they have drafted. Generate exactly 3 improved versions of their message — each clearer, more professional, and impactful while preserving the core intent and meaning. Vary the approach slightly across the 3 versions. Return ONLY a valid JSON array of exactly 3 strings with no other text, no labels, no explanations. Example format: [\"Improved version one.\", \"Improved version two.\", \"Improved version three.\"]"

    static func builtInDefaults() -> [KBGenerationMode] {
        let rc = KBConfigFetcher.keyboard?.builtInModes
        return [
            KBGenerationMode(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: rc?.reply.name ?? "Reply",
                icon: rc?.reply.icon ?? "arrowshape.turn.up.left.fill",
                baseSystemPrompt: rc?.reply.systemPrompt ?? fallbackReplyPrompt,
                userInstructions: "",
                inputSource: .clipboard,
                isBuiltIn: true
            ),
            KBGenerationMode(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: rc?.refine.name ?? "Refine",
                icon: rc?.refine.icon ?? "sparkle.magnifyingglass",
                baseSystemPrompt: rc?.refine.systemPrompt ?? fallbackRefinePrompt,
                userInstructions: "",
                inputSource: .textField,
                isBuiltIn: true
            )
        ]
    }
}

// MARK: - Remote Config Fetcher (keyboard extension side)
// Fetches fresh config from API before every OpenAI call.
// Only decodes the keyboard section to keep it lightweight.

fileprivate struct KBRemoteConfig: Codable {
    let keyboard: KBKeyboardSection?
}

fileprivate struct KBKeyboardSection: Codable {
    let model: String
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let builtInModes: KBBuiltInModesSection
}

fileprivate struct KBBuiltInModesSection: Codable {
    let reply: KBModeSection
    let refine: KBModeSection
}

fileprivate struct KBModeSection: Codable {
    let name: String
    let icon: String
    let systemPrompt: String
}

fileprivate enum KBConfigFetcher {
    private static let configURL = URL(string: "https://bokcfsexepjshdttndbn.supabase.co/functions/v1/get-config")!
    private static let authToken = "saythis2026"

    /// In-memory cache for UI reads (mode names/icons)
    static var lastFetched: KBRemoteConfig?

    /// Convenience: keyboard section from last fetch
    static var keyboard: KBKeyboardSection? { lastFetched?.keyboard }

    /// Fetch fresh config. Returns keyboard config (or nil) via completion.
    static func fetch(completion: @escaping (KBKeyboardSection?) -> Void) {
        kbLogger.info("🔧 [KB Config] Fetching from control panel…")
        var request = URLRequest(url: configURL)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                kbLogger.error("❌ [KB Config] Network error: \(error.localizedDescription, privacy: .public)")
                let fallbackState = lastFetched == nil ? "nil (hardcoded defaults)" : "last fetched"
                kbLogger.warning("⚠️ [KB Config] Using in-memory fallback: \(fallbackState, privacy: .public)")
                completion(lastFetched?.keyboard)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no body"
                kbLogger.error("❌ [KB Config] HTTP \(http.statusCode): \(body.prefix(200), privacy: .public)")
                let fallbackState = lastFetched == nil ? "nil (hardcoded defaults)" : "last fetched"
                kbLogger.warning("⚠️ [KB Config] Using in-memory fallback: \(fallbackState, privacy: .public)")
                completion(lastFetched?.keyboard)
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let config = try? JSONDecoder().decode(KBRemoteConfig.self, from: data)
            else {
                let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? "no data"
                kbLogger.error("❌ [KB Config] Decode failed. Raw: \(raw.prefix(300), privacy: .public)")
                completion(lastFetched?.keyboard)
                return
            }

            let kb = config.keyboard
            kbLogger.info("🔧 [KB Config] ✅ Fetched — model=\(kb?.model ?? "nil", privacy: .public)  temp=\(kb?.temperature ?? -1)  maxTokens=\(kb?.maxTokens ?? -1)")
            if let reply = kb?.builtInModes.reply {
                let preview = String(reply.systemPrompt.prefix(80))
                kbLogger.info("🔧 [KB Config]   replyPrompt preview: \(preview, privacy: .public)…")
            }

            lastFetched = config
            completion(config.keyboard)
        }.resume()
    }
}

// MARK: - Errors

enum OpenAIError: LocalizedError {
    case noAPIKey
    case emptyInput
    case invalidResponse
    case httpError(Int, String)
    case network(Error)
    case decodingError
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "AI service unavailable. Try reopening the SayThis app."
        case .emptyInput:
            return "Nothing to generate from. Copy a message or type first."
        case .invalidResponse:
            return "Invalid response from OpenAI."
        case .httpError(let code, let msg):
            return "API error (\(code)): \(msg)"
        case .network(let err):
            return "Network: \(err.localizedDescription)"
        case .decodingError:
            return "Could not parse AI response."
        case .rateLimited:
            return "Rate limited. Wait a moment and retry."
        }
    }
}

// MARK: - OpenAI Response Models

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}

private struct ErrorBody: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

// MARK: - Client

final class OpenAIClient {

    static let shared = OpenAIClient()
    private init() {}

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func generateReplies(
        from input: String,
        systemPrompt: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(OpenAIError.emptyInput)); return
        }
        guard let apiKey = APIKeyStore.apiKey, !apiKey.isEmpty else {
            completion(.failure(OpenAIError.noAPIKey)); return
        }

        // Fetch fresh config before every API call
        kbLogger.info("🤖 [KB API] generateReplies() — fetching config…")
        KBConfigFetcher.fetch { [weak self] kbConfig in
            guard let self else { return }

            if let kbConfig {
                kbLogger.info("🤖 [KB API] ✅ Using REMOTE config for keyboard")
                kbLogger.info("🤖 [KB API]   model=\(kbConfig.model, privacy: .public)  temp=\(kbConfig.temperature)  maxTokens=\(kbConfig.maxTokens)")
                let promptPreview = String(systemPrompt.prefix(80))
                kbLogger.info("🤖 [KB API]   systemPrompt preview: \(promptPreview, privacy: .public)…")
            } else {
                kbLogger.warning("⚠️ [KB API] Config unavailable — keyboard using HARDCODED fallback defaults")
                kbLogger.warning("⚠️ [KB API]   model=gpt-4.1-mini (default)  temp=0.8  maxTokens=600")
            }

            var request = URLRequest(url: self.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "model": kbConfig?.model ?? "gpt-4.1-mini",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user",   "content": trimmed]
                ],
                "temperature": kbConfig?.temperature ?? 0.8,
                "max_tokens": kbConfig?.maxTokens ?? 600,
                "top_p": kbConfig?.topP ?? 1.0
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            kbLogger.info("🤖 [KB API] Sending request to OpenAI…")
            self.session.dataTask(with: request) { data, response, error in
                if let error {
                    kbLogger.error("❌ [KB API] Network error: \(error.localizedDescription, privacy: .public)")
                    completion(.failure(OpenAIError.network(error))); return
                }
                guard let data, let http = response as? HTTPURLResponse else {
                    kbLogger.error("❌ [KB API] No data or non-HTTP response")
                    completion(.failure(OpenAIError.invalidResponse)); return
                }

                kbLogger.info("🤖 [KB API] OpenAI HTTP \(http.statusCode), body: \(data.count) bytes")

                guard http.statusCode == 200 else {
                    if http.statusCode == 429 {
                        kbLogger.warning("⚠️ [KB API] Rate limited (429)")
                        completion(.failure(OpenAIError.rateLimited)); return
                    }
                    if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                        kbLogger.error("❌ [KB API] API error: \(body.error.message, privacy: .public)")
                        completion(.failure(OpenAIError.httpError(http.statusCode, body.error.message)))
                    } else {
                        kbLogger.error("❌ [KB API] HTTP error \(http.statusCode)")
                        completion(.failure(OpenAIError.httpError(http.statusCode, "Unknown error")))
                    }
                    return
                }

                do {
                    let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
                    guard let content = chat.choices.first?.message.content else {
                        kbLogger.error("❌ [KB API] Decoded response but no content in choices")
                        completion(.failure(OpenAIError.invalidResponse)); return
                    }

                    let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Try JSON array first
                    if let jsonData = raw.data(using: .utf8),
                       let replies = try? JSONDecoder().decode([String].self, from: jsonData),
                       !replies.isEmpty {
                        kbLogger.info("🤖 [KB API] ✅ Parsed \(replies.count) replies via JSON array")
                        completion(.success(replies)); return
                    }

                    // Fallback: extract content between outermost brackets
                    if let start = raw.firstIndex(of: "["),
                       let end   = raw.lastIndex(of: "]") {
                        let slice = String(raw[start...end])
                        if let sliceData = slice.data(using: .utf8),
                           let replies = try? JSONDecoder().decode([String].self, from: sliceData),
                           !replies.isEmpty {
                            kbLogger.info("🤖 [KB API] ✅ Parsed \(replies.count) replies via bracket extraction")
                            completion(.success(replies)); return
                        }
                    }

                    // Last resort: split by newlines
                    let lines = raw
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                                 .trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-) \"")) }
                        .filter { !$0.isEmpty }

                    if lines.isEmpty {
                        let rawPreview = String(raw.prefix(200))
                        kbLogger.error("❌ [KB API] Could not parse any replies. Raw: \(rawPreview, privacy: .public)")
                        completion(.failure(OpenAIError.decodingError))
                    } else {
                        kbLogger.info("🤖 [KB API] ✅ Parsed \(lines.count) replies via newline split (fallback)")
                        completion(.success(lines))
                    }
                } catch {
                    kbLogger.error("❌ [KB API] JSON decode error: \(error, privacy: .public)")
                    completion(.failure(OpenAIError.decodingError))
                }
            }.resume()
        }
    }
}
