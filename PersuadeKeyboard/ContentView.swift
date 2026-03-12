import SwiftUI

// MARK: - Root View (auth router)
struct ContentView: View {
    @State private var isAuthenticated: Bool = {
        let hasFlag = UserDefaults.standard.bool(forKey: "isAuthenticated")
        let hasToken = APIService.shared.isLoggedIn
        return hasFlag && hasToken
    }()

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView(isAuthenticated: $isAuthenticated)
                    .transition(.opacity)
            } else {
                AuthView(isAuthenticated: $isAuthenticated)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isAuthenticated)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
