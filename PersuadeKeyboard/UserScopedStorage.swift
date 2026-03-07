import Foundation

// MARK: - UserScopedStorage
//
// Namespaces every UserDefaults key by the signed-in user's email address so
// data from different accounts NEVER bleeds into each other on a shared device.
//
// Key format:  "<base_key>|<user@email.com>"
// Example:     "openai_api_key|alice@example.com"
//
// Keys intentionally NOT scoped (login-state, not user-data):
//   • auth_token       – replaced on every login/logout
//   • user_email       – the identity itself
//   • isAuthenticated  – boolean session flag
//   • api_base_url     – developer setting, not user-specific

enum UserScopedStorage {

    static let appGroupID = "group.com.goatedx.persuade"

    // MARK: - Namespace

    /// Email of the currently signed-in user, read fresh from UserDefaults.
    static var currentUserEmail: String? {
        UserDefaults(suiteName: appGroupID)?.string(forKey: "user_email")
            ?? UserDefaults.standard.string(forKey: "user_email")
    }

    /// Returns "<base>|<email>", or just "<base>" when no user is signed in.
    static func scopedKey(_ base: String) -> String {
        guard let email = currentUserEmail, !email.isEmpty else { return base }
        return "\(base)|\(email)"
    }

    // MARK: - App Group + Standard  (shared with keyboard extension)

    /// Write to both App Group and standard UserDefaults under a user-scoped key.
    static func setShared(_ value: String?, forKey base: String) {
        let key = scopedKey(base)
        UserDefaults(suiteName: appGroupID)?.set(value, forKey: key)
        UserDefaults.standard.set(value, forKey: key)
    }

    /// Read from App Group first, then standard UserDefaults.
    static func getShared(forKey base: String) -> String? {
        let key = scopedKey(base)
        if let v = UserDefaults(suiteName: appGroupID)?.string(forKey: key), !v.isEmpty { return v }
        let std = UserDefaults.standard.string(forKey: key)
        return (std?.isEmpty == false) ? std : nil
    }

    // MARK: - Standard only

    static func setLocal(_ value: String?, forKey base: String) {
        UserDefaults.standard.set(value, forKey: scopedKey(base))
    }

    static func getLocal(forKey base: String) -> String? {
        let v = UserDefaults.standard.string(forKey: scopedKey(base))
        return (v?.isEmpty == false) ? v : nil
    }

    // MARK: - Filesystem helpers

    /// A filesystem-safe folder name derived from the user's email.
    /// e.g. "alice@example.com" → "alice_example_com"
    static var userDirectoryName: String {
        guard let email = currentUserEmail, !email.isEmpty else { return "_shared" }
        let safe = email
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        return safe.isEmpty ? "_shared" : safe
    }
}
