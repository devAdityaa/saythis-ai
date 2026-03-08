//
//  PersuadeKeyboardApp.swift
//  PersuadeKeyboard
//
//  Created by Debaditya Banerji on 25/02/26.
//

import SwiftUI

// MARK: - Global API Key
// Single internal key used across all accounts. Replace with your production key.
enum GlobalConfig {
    static let openAIKey = ""

    /// Writes the global key into the App Group so the keyboard extension can read it.
    static func seedKeyToAppGroup() {
        let gd = UserDefaults(suiteName: UserScopedStorage.appGroupID)
        gd?.set(openAIKey, forKey: "global_openai_api_key")
    }
}

@main
struct PersuadeKeyboardApp: App {
    init() {
        GlobalConfig.seedKeyToAppGroup()
        RemoteConfigService.shared.fetchConfig()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
