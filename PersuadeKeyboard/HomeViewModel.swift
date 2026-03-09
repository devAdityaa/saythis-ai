import SwiftUI

// MARK: - Home View Model (paste + generate replies)

@Observable
final class HomeViewModel {
    var pastedText: String = ""
    var isGenerating: Bool = false
    var generatedReplies: [String] = []
    var errorMessage: String?
    var replyCopiedIndex: Int? = nil

    var canGenerate: Bool {
        !pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    func generateReplies() {
        let trimmed = pastedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let userToken = APIService.shared.token, !userToken.isEmpty else {
            errorMessage = "Please sign in to use SayThis."
            return
        }

        isGenerating = true
        errorMessage = nil
        generatedReplies = []

        let systemPrompt = """
        You are a reply suggestion assistant for any conversation. The user will provide a message they received. Generate exactly 3 short, natural reply suggestions. Each reply should take a different angle — vary the tone and approach. Return ONLY a valid JSON array of exactly 3 strings with no other text, no labels, no explanations. Example format: ["Reply one.", "Reply two.", "Reply three."]
        """

        let userMessage = "Generate suggestions for this message:\n\n\(trimmed)"

        // Route through backend proxy (analyze endpoint accepts JWT + chat/completions format)
        let base = APIService.shared.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = URL(string: "\(base)/api/ai/analyze")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "gpt-4.1-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "temperature": 0.8,
            "max_tokens": 600
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isGenerating = false

                if let error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                guard let data,
                      let http = response as? HTTPURLResponse,
                      http.statusCode == 200 else {
                    self.errorMessage = "Failed to get response from AI."
                    return
                }

                struct ChatResponse: Decodable {
                    struct Choice: Decodable {
                        struct Message: Decodable { let content: String }
                        let message: Message
                    }
                    let choices: [Choice]
                }

                guard let chat = try? JSONDecoder().decode(ChatResponse.self, from: data),
                      let content = chat.choices.first?.message.content else {
                    self.errorMessage = "Could not parse AI response."
                    return
                }

                let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)

                // Tier 1: direct JSON array
                if let jsonData = raw.data(using: .utf8),
                   let replies = try? JSONDecoder().decode([String].self, from: jsonData),
                   !replies.isEmpty {
                    self.generatedReplies = replies
                    return
                }

                // Tier 2: bracket extraction
                if let start = raw.firstIndex(of: "["),
                   let end = raw.lastIndex(of: "]"),
                   let sliceData = String(raw[start...end]).data(using: .utf8),
                   let replies = try? JSONDecoder().decode([String].self, from: sliceData),
                   !replies.isEmpty {
                    self.generatedReplies = replies
                    return
                }

                // Tier 3: line split fallback
                let lines = raw.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.-) \"")) }
                    .filter { !$0.isEmpty }

                if !lines.isEmpty {
                    self.generatedReplies = lines
                } else {
                    self.errorMessage = "Could not parse AI response."
                }
            }
        }.resume()
    }

    func copyReply(at index: Int) {
        guard index < generatedReplies.count else { return }
        UIPasteboard.general.string = generatedReplies[index]
        replyCopiedIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.replyCopiedIndex == index { self?.replyCopiedIndex = nil }
        }
    }

    func reset() {
        generatedReplies = []
        errorMessage = nil
    }
}
