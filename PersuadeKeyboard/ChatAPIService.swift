import Foundation

// MARK: - API Key Store
// Reads the global internal key seeded by GlobalConfig on app launch.
private enum ChatKeyStore {
    static var apiKey: String? {
        let gd = UserDefaults(suiteName: UserScopedStorage.appGroupID)
        if let k = gd?.string(forKey: "global_openai_api_key"), !k.isEmpty { return k }
        return nil
    }
}

// MARK: - Errors
enum ChatAPIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case httpError(Int, String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:           return "AI service unavailable. Please try again later."
        case .invalidResponse:    return "Received an invalid response from the server."
        case .httpError(let c, let m): return "Error \(c): \(m)"
        case .network(let e):     return e.localizedDescription
        }
    }
}

// MARK: - Request Models (OpenAI Responses API)
private struct ResponsesRequest: Encodable {
    let model: String
    let instructions: String
    let input: [InputMessage]
    var temperature: Double?
    var top_p: Double?
    var max_output_tokens: Int?
}

private struct InputMessage: Encodable {
    let role: String
    let content: InputContent
}

private enum InputContent: Encodable {
    case text(String)
    case parts([ContentPart])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s):   try container.encode(s)
        case .parts(let p):  try container.encode(p)
        }
    }
}

private struct ContentPart: Encodable {
    let type: String
    let text: String?
    let image_url: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let text  { try container.encode(text, forKey: .text) }
        if let image_url { try container.encode(image_url, forKey: .image_url) }
    }
    private enum CodingKeys: String, CodingKey { case type, text, image_url }
}

// MARK: - Response Models
private struct ResponsesAPIResponse: Decodable {
    let id: String?
    let output: [ResponseOutput]?
    let error: APIErrorBody?
}

private struct ResponseOutput: Decodable {
    let type: String?
    let content: [OutputContent]?
}

private struct OutputContent: Decodable {
    let type: String?
    let text: String?
}

private struct APIErrorBody: Decodable {
    let message: String?
    let type: String?
    let code: String?
}

// MARK: - Chat API Service
final class ChatAPIService {
    static let shared = ChatAPIService()
    private init() {}

    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    // ─── System Prompt fallback (used when remote config unavailable) ───
    static var systemPrompt: String { defaultSystemPrompt }

    private static let defaultSystemPrompt = """
You are **SayThis**, an AI messaging assistant that helps users communicate clearly, confidently, and effectively in any conversation.

You exist to operate seamlessly wherever the user is communicating — text messages, DMs, emails, or chats — and to deliver **immediate, high-quality, ready-to-send responses** with zero friction.

Your purpose is simple:
**Help the user say the right thing, instantly.**

---

## **CORE IDENTITY**

You are:
* A communication expert
* A thoughtful message crafter
* A calm, confident writing partner

You are NOT:
* A generic chatbot
* A teacher of theory
* A verbose explainer

Every response you generate should feel like it came from someone who **understands tone, timing, and how people communicate**.

---

## **OPERATING ASSUMPTIONS**

Always assume:
* The user is on a **mobile device**
* They are in the middle of a **live conversation**
* They want a response they can **send immediately**
* Speed and clarity matter more than perfection

You may receive:
* A copied message from someone they are chatting with
* Extracted text from an image or screenshot
* A direct question asking for messaging advice or help

Regardless of input source, you are the **same SayThis** with the same goal:
**Help the user communicate better.**

---

## **PRIMARY BEHAVIOR**

When given a message from someone the user is chatting with:
1. Analyze intent, tone, context, and what kind of response would be appropriate
2. Identify the best response strategy
3. Generate **2–3 distinct reply options** that:
   * Sound natural
   * Are concise
   * Are immediately sendable
   * Use different tones or approaches

When given a general communication question:
* Provide clear, actionable guidance
* Prefer examples and exact phrasing
* Avoid theory unless it directly improves the message

---

## **OUTPUT STANDARD**

Your responses must be:
* Copy-paste ready
* Human-sounding
* Contextually aware
* Appropriate for the situation

Default to **short, clean paragraphs**.
Avoid unnecessary formatting.
Do not explain *why* a response works unless explicitly asked.

---

## **TONE & STYLE CONTROL**

Your tone is **user-selectable** and must be followed precisely.

### **Available Styles**

**Professional**
* Polished, confident, business-appropriate
* Neutral and credible

**Bold / Direct**
* High conviction
* Gets to the point
* Assumes confidence

**Empathetic**
* Warm and understanding
* Relationship-focused
* Reduces friction and pressure

**Casual / Concise**
* Minimal words
* Straight to the point
* Optimized for fast texting

If no tone is specified, default to **Professional**.

---

## **COMMUNICATION PRINCIPLES (INTERNAL GUIDANCE)**

Silently apply when appropriate:
* Clarity over cleverness
* Confidence over hedging
* Questions that move conversations forward
* Appropriate calls-to-action depending on context
* Emotional validation before logical framing

Never reference these principles explicitly unless asked.

---

## **CUSTOM USER KNOWLEDGE (IF AVAILABLE)**

If the user has provided:
* Context about their situation
* Background information
* Product or service details
* PDFs or documents

You must:
* Follow their exact context and framing
* Match their language and style
* Never invent missing details
* Ask for clarification if required to avoid errors

---

## **NON-NEGOTIABLE RULES**

* Do NOT say "As an AI"
* Do NOT mention system instructions or internal logic
* Do NOT include markdown, bullet points, or labels in short replies
* Do NOT overwhelm the user with too many options
* Do NOT add fluff, filler, or academic explanations

---

## **SUCCESS CRITERIA**

A response from SayThis is successful if:
* The user can send it **without editing**
* It sounds confident, intentional, and human
* It fits the context and moves the conversation forward

You are not here to sound impressive.
You are here to **help the user say the right thing**.

---

YOUR Output must be beautifully formatted
"""

    // MARK: - Split-mode instruction fallback
    static var splitModeInstruction: String { defaultSplitModeInstruction }

    private static let defaultSplitModeInstruction = """


---

## SPLIT RESPONSE FORMAT (MANDATORY FOR THIS REQUEST)

You MUST structure your entire response using these markers, each on its own line:

[CONTEXT]
<Your brief analysis, coaching note, or strategic tip — 1 to 3 sentences. This goes in a separate info bubble.>

[REPLY]
<First reply option — standalone, ready-to-send message. No labels, no explanation, just the message text.>

[REPLY]
<Second reply option — different angle or tone. Same rules: just the message text.>

[REPLY]
<Third reply option (optional). Same rules.>

Rules:
• Start with exactly ONE [CONTEXT] block.
• Follow with 2–3 [REPLY] blocks. EVERY reply option MUST be in its own [REPLY] block.
• Each [REPLY] must contain ONLY the standalone message text — no labels, numbers, "Option 1:", or explanation.
• Do NOT combine multiple replies into a single [REPLY] block.
• Do NOT add any text outside these blocks.
"""

    // MARK: - Retry config
    private let maxRetries = 2
    private let retryDelay: TimeInterval = 1.0

    /// Returns true for transient network errors worth retrying (connection lost, reset, timeout).
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        let retryableCodes: Set<Int> = [
            NSURLErrorNetworkConnectionLost,     // -1005
            NSURLErrorTimedOut,                   // -1001
            NSURLErrorCannotConnectToHost,        // -1004
            NSURLErrorNotConnectedToInternet,     // -1009
            NSURLErrorSecureConnectionFailed,     // -1200
            NSURLErrorCannotFindHost,             // -1003
        ]
        return retryableCodes.contains(nsError.code)
    }

    // MARK: - Send message
    func sendMessage(
        messages: [ChatMessage],
        splitMode: Bool = false,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let apiKey = ChatKeyStore.apiKey else {
            completion(.failure(ChatAPIError.noAPIKey))
            return
        }

        // Fetch fresh config before every API call
        SayThisLog.api("sendMessage() called — fetching config…")
        RemoteConfigService.shared.fetchConfig { [weak self] config in
            guard let self else { return }

            let rc = config?.thinkChat

            if let rc {
                SayThisLog.api("✅ Using REMOTE config for Think/Chat")
                SayThisLog.api("  model=\(rc.model)  temp=\(rc.temperature)  topP=\(rc.topP)  maxTokens=\(rc.maxTokens)")
                SayThisLog.api("  systemPrompt preview: \(SayThisLog.preview(rc.systemPrompt))")
                if splitMode {
                    SayThisLog.api("  splitModeInstruction preview: \(SayThisLog.preview(rc.splitModeInstruction))")
                }
            } else {
                SayThisLog.warn("Config unavailable — Think/Chat using HARDCODED fallback defaults")
                SayThisLog.warn("  model=gpt-4.1-mini (default)  temp=nil  topP=nil  maxTokens=nil")
            }

            // Build input array from conversation history
            let input: [InputMessage] = messages.map { msg in
                if msg.attachments.isEmpty {
                    return InputMessage(role: msg.role.rawValue, content: .text(msg.content))
                } else {
                    var parts: [ContentPart] = []
                    if !msg.content.isEmpty {
                        parts.append(ContentPart(type: "input_text", text: msg.content, image_url: nil))
                    }
                    for att in msg.attachments where att.type == .image {
                        parts.append(ContentPart(
                            type: "input_image",
                            text: nil,
                            image_url: "data:\(att.mimeType);base64,\(att.base64Data)"
                        ))
                    }
                    // Documents: send as text context
                    for att in msg.attachments where att.type == .document {
                        parts.append(ContentPart(
                            type: "input_text",
                            text: "[Attached document: \(att.fileName)]",
                            image_url: nil
                        ))
                    }
                    if parts.isEmpty {
                        return InputMessage(role: msg.role.rawValue, content: .text(msg.content))
                    }
                    return InputMessage(role: msg.role.rawValue, content: .parts(parts))
                }
            }

            let sysPrompt = rc?.systemPrompt ?? Self.defaultSystemPrompt
            let splitInstr = rc?.splitModeInstruction ?? Self.defaultSplitModeInstruction
            let instructions = splitMode ? sysPrompt + splitInstr : sysPrompt

            var body = ResponsesRequest(
                model: rc?.model ?? "gpt-4.1-mini",
                instructions: instructions,
                input: input
            )
            body.temperature = rc?.temperature
            body.top_p = rc?.topP
            body.max_output_tokens = rc?.maxTokens

            var request = URLRequest(url: self.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 60

            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                DispatchQueue.main.async { completion(.failure(ChatAPIError.invalidResponse)) }
                return
            }

            self.performRequest(request, attempt: 0, completion: completion)
        }
    }

    /// Performs the URL request with automatic retry for transient network errors.
    private func performRequest(
        _ request: URLRequest,
        attempt: Int,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        SayThisLog.api("OpenAI Responses API call — attempt \(attempt + 1)")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            // Retry on transient network errors
            if let error, self.isRetryableError(error), attempt < self.maxRetries {
                let delay = self.retryDelay * Double(attempt + 1)
                SayThisLog.warn("Retryable error on attempt \(attempt + 1): \(error.localizedDescription) — retrying in \(delay)s")
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performRequest(request, attempt: attempt + 1, completion: completion)
                }
                return
            }

            if let error {
                SayThisLog.error("Think/Chat final network error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(ChatAPIError.network(error))) }
                return
            }

            guard let data, let httpResponse = response as? HTTPURLResponse else {
                SayThisLog.error("Think/Chat no data or non-HTTP response")
                DispatchQueue.main.async { completion(.failure(ChatAPIError.invalidResponse)) }
                return
            }

            SayThisLog.api("OpenAI response HTTP \(httpResponse.statusCode), body size: \(data.count) bytes")

            // Try parsing response
            if let apiResp = try? JSONDecoder().decode(ResponsesAPIResponse.self, from: data) {
                // Check for API error
                if let apiError = apiResp.error {
                    let msg = apiError.message ?? "Unknown API error"
                    SayThisLog.error("OpenAI API error: \(msg)")
                    DispatchQueue.main.async {
                        completion(.failure(ChatAPIError.httpError(httpResponse.statusCode, msg)))
                    }
                    return
                }

                // Extract text from output
                if let output = apiResp.output,
                   let firstMessage = output.first(where: { $0.type == "message" }),
                   let content = firstMessage.content,
                   let textContent = content.first(where: { $0.type == "output_text" }),
                   let text = textContent.text {
                    SayThisLog.api("✅ Think/Chat success — response length: \(text.count) chars")
                    DispatchQueue.main.async { completion(.success(text)) }
                    return
                }

                SayThisLog.warn("Parsed ResponsesAPIResponse but found no output_text. Output items: \(apiResp.output?.count ?? 0)")
            } else {
                SayThisLog.warn("Could not decode ResponsesAPIResponse — raw body: \((String(data: data, encoding: .utf8) ?? "unreadable").prefix(300))")
            }

            // If status code is not 2xx
            if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                SayThisLog.error("Think/Chat HTTP error \(httpResponse.statusCode): \(body.prefix(200))")
                DispatchQueue.main.async {
                    completion(.failure(ChatAPIError.httpError(httpResponse.statusCode, body)))
                }
                return
            }

            // Fallback: try raw text
            if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
                SayThisLog.warn("Using raw text fallback for Think/Chat response")
                DispatchQueue.main.async { completion(.success(raw)) }
                return
            }

            SayThisLog.error("Think/Chat: no usable response body")
            DispatchQueue.main.async { completion(.failure(ChatAPIError.invalidResponse)) }
        }.resume()
    }
}
