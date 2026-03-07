import Foundation

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

    static func builtInDefaults() -> [KBGenerationMode] {
        [
            KBGenerationMode(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Reply",
                icon: "arrowshape.turn.up.left.fill",
                baseSystemPrompt: "You are a reply suggestion assistant for any conversation. The user will provide a message they received. Generate exactly 3 short, natural reply suggestions. Each reply should take a different angle — vary the tone and approach. Return ONLY a valid JSON array of exactly 3 strings with no other text, no labels, no explanations. Example format: [\"Reply one.\", \"Reply two.\", \"Reply three.\"]",
                userInstructions: "",
                inputSource: .clipboard,
                isBuiltIn: true
            ),
            KBGenerationMode(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Refine",
                icon: "sparkle.magnifyingglass",
                baseSystemPrompt: "You are a message improvement assistant. The user will provide a message they have drafted. Generate exactly 3 improved versions of their message — each clearer, more professional, and impactful while preserving the core intent and meaning. Vary the approach slightly across the 3 versions. Return ONLY a valid JSON array of exactly 3 strings with no other text, no labels, no explanations. Example format: [\"Improved version one.\", \"Improved version two.\", \"Improved version three.\"]",
                userInstructions: "",
                inputSource: .textField,
                isBuiltIn: true
            )
        ]
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

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": trimmed]
            ],
            "temperature": 0.8,
            "max_tokens": 600
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(OpenAIError.network(error))); return
            }
            guard let data, let http = response as? HTTPURLResponse else {
                completion(.failure(OpenAIError.invalidResponse)); return
            }

            guard http.statusCode == 200 else {
                if http.statusCode == 429 {
                    completion(.failure(OpenAIError.rateLimited)); return
                }
                if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                    completion(.failure(OpenAIError.httpError(http.statusCode, body.error.message)))
                } else {
                    completion(.failure(OpenAIError.httpError(http.statusCode, "Unknown error")))
                }
                return
            }

            do {
                let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
                guard let content = chat.choices.first?.message.content else {
                    completion(.failure(OpenAIError.invalidResponse)); return
                }

                let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)

                // Try JSON array first
                if let jsonData = raw.data(using: .utf8),
                   let replies = try? JSONDecoder().decode([String].self, from: jsonData),
                   !replies.isEmpty {
                    completion(.success(replies)); return
                }

                // Fallback: extract content between outermost brackets
                if let start = raw.firstIndex(of: "["),
                   let end   = raw.lastIndex(of: "]") {
                    let slice = String(raw[start...end])
                    if let sliceData = slice.data(using: .utf8),
                       let replies = try? JSONDecoder().decode([String].self, from: sliceData),
                       !replies.isEmpty {
                        completion(.success(replies)); return
                    }
                }

                // Last resort: split by newlines
                let lines = raw
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                             .trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-) \"")) }
                    .filter { !$0.isEmpty }

                completion(lines.isEmpty ? .failure(OpenAIError.decodingError) : .success(lines))
            } catch {
                completion(.failure(OpenAIError.decodingError))
            }
        }.resume()
    }
}
