import Foundation

// MARK: - Response Models

struct AuthResponse: Codable {
    struct User: Codable {
        let id: String
        let email: String
        let createdAt: String
    }
    let token: String
    let user: User
}

struct UserProfile: Codable {
    let id: String
    let email: String
    let createdAt: String
    let settings: UserSettings
    let metrics: UserMetrics
}

struct UserSettings: Codable {
    let theme: String
    let customSystemPrompt: String
}

struct UserMetrics: Codable {
    let repliesGenerated: Int
    let chatsStarted: Int
    let screenshotsAnalyzed: Int
    let keyboardUsages: Int
}

struct SuccessResponse: Codable {
    let success: Bool
}

struct APIErrorResponse: Codable {
    let error: String
}

// MARK: - API Service

final class APIService {
    static let shared = APIService()

    private let appGroupID = "group.com.goatedx.persuade"
    private let tokenKey   = "auth_token"
    private let emailKey   = "user_email"
    private let baseURLKey = "api_base_url"

    private let session: URLSession

    // ── Persisted Properties ──

    // ── PRODUCTION URL ──────────────────────────────────────────────────
    // After deploying to Vercel, paste your URL here as the fallback default.
    // e.g. "https://persuade-ai-backend.vercel.app"
    // The user can also override it at runtime via Settings > Server Configuration.
    private static let productionURL = "https://persuade-ai-backend.vercel.app/"
    // ────────────────────────────────────────────────────────────────────

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? Self.productionURL }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    var token: String? {
        get {
            UserDefaults(suiteName: appGroupID)?.string(forKey: tokenKey)
                ?? UserDefaults.standard.string(forKey: tokenKey)
        }
        set {
            UserDefaults(suiteName: appGroupID)?.set(newValue, forKey: tokenKey)
            UserDefaults.standard.set(newValue, forKey: tokenKey)
        }
    }

    var userEmail: String? {
        get {
            UserDefaults(suiteName: appGroupID)?.string(forKey: emailKey)
                ?? UserDefaults.standard.string(forKey: emailKey)
        }
        set {
            UserDefaults(suiteName: appGroupID)?.set(newValue, forKey: emailKey)
            UserDefaults.standard.set(newValue, forKey: emailKey)
        }
    }

    var isLoggedIn: Bool {
        guard let t = token, !t.isEmpty else { return false }
        return true
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // ═══════════════════════════════
    //  AUTH
    // ═══════════════════════════════

    func register(email: String, password: String,
                  completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let body: [String: Any] = ["email": email, "password": password]
        request(method: "POST", path: "/api/auth/register", body: body, auth: false) {
            (result: Result<AuthResponse, Error>) in
            if case .success(let resp) = result {
                self.token     = resp.token
                self.userEmail = resp.user.email
                UserDefaults.standard.set(true, forKey: "isAuthenticated")
            }
            completion(result)
        }
    }

    func login(email: String, password: String,
               completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let body: [String: Any] = ["email": email, "password": password]
        request(method: "POST", path: "/api/auth/login", body: body, auth: false) {
            (result: Result<AuthResponse, Error>) in
            if case .success(let resp) = result {
                self.token     = resp.token
                self.userEmail = resp.user.email
                UserDefaults.standard.set(true, forKey: "isAuthenticated")
            }
            completion(result)
        }
    }

    func signOut() {
        token     = nil
        userEmail = nil
        let group = UserDefaults(suiteName: appGroupID)
        group?.removeObject(forKey: tokenKey)
        group?.removeObject(forKey: emailKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
        UserDefaults.standard.set(false, forKey: "isAuthenticated")
    }

    // ═══════════════════════════════
    //  PROFILE
    // ═══════════════════════════════

    func getProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        request(method: "GET", path: "/api/user/profile", completion: completion)
    }

    // ═══════════════════════════════
    //  SETTINGS
    // ═══════════════════════════════

    func getSettings(completion: @escaping (Result<UserSettings, Error>) -> Void) {
        request(method: "GET", path: "/api/user/settings", completion: completion)
    }

    func updateSettings(theme: String? = nil,
                        customSystemPrompt: String? = nil,
                        completion: @escaping (Result<SuccessResponse, Error>) -> Void) {
        var body: [String: Any] = [:]
        if let theme              { body["theme"] = theme }
        if let customSystemPrompt { body["customSystemPrompt"] = customSystemPrompt }
        request(method: "PUT", path: "/api/user/settings", body: body, completion: completion)
    }

    // ═══════════════════════════════
    //  METRICS
    // ═══════════════════════════════

    func trackEvent(_ event: String, completion: ((Result<SuccessResponse, Error>) -> Void)? = nil) {
        request(method: "POST", path: "/api/metrics/track", body: ["event": event]) {
            (result: Result<SuccessResponse, Error>) in
            completion?(result)
        }
    }

    func getMetrics(completion: @escaping (Result<UserMetrics, Error>) -> Void) {
        request(method: "GET", path: "/api/metrics", completion: completion)
    }

    // ═══════════════════════════════
    //  GENERIC REQUEST
    // ═══════════════════════════════

    private func request<T: Codable>(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        auth: Bool = true,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: baseURL + path) else {
            completion(.failure(apiError("Invalid URL")))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if auth, let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        session.dataTask(with: req) { data, response, error in
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(self.apiError("Network error: \(error.localizedDescription)")))
                }
                return
            }

            guard let data, let http = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(self.apiError("No response from server")))
                }
                return
            }

            guard http.statusCode >= 200, http.statusCode < 300 else {
                let msg: String
                if let apiErr = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    msg = apiErr.error
                } else {
                    msg = "Server error (\(http.statusCode))"
                }
                DispatchQueue.main.async {
                    completion(.failure(self.apiError(msg)))
                }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                DispatchQueue.main.async { completion(.success(decoded)) }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(self.apiError("Failed to parse server response")))
                }
            }
        }.resume()
    }

    private func apiError(_ message: String) -> NSError {
        NSError(domain: "APIService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
