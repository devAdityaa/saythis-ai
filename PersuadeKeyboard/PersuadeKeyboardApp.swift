//
//  PersuadeKeyboardApp.swift
//  PersuadeKeyboard
//
//  Created by Debaditya Banerji on 25/02/26.
//

import SwiftUI

@main
struct PersuadeKeyboardApp: App {
    init() {
        // Fetch remote config on launch so UI/prompts are ready
        RemoteConfigService.shared.fetchConfig()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
