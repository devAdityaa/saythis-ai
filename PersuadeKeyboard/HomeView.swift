import SwiftUI

// MARK: - Tab Enum
enum AppTab: String, CaseIterable {
    case think    = "Think"
    case analyze  = "Analyze"
    case styles   = "Styles"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .think:    return "brain.head.profile"
        case .analyze:  return "camera.viewfinder"
        case .styles:   return "paintbrush.pointed.fill"
        case .settings: return "gearshape"
        }
    }

    var filledIcon: String {
        switch self {
        case .think:    return "brain.head.profile"
        case .analyze:  return "camera.viewfinder"
        case .styles:   return "paintbrush.pointed.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var isAuthenticated: Bool
    @State private var selectedTab: AppTab = .think

    var body: some View {
        VStack(spacing: 0) {
            // ── Tab content fills available space ──
            Group {
                switch selectedTab {
                case .think:
                    NavigationStack { ChatView() }
                case .analyze:
                    NavigationStack { AnalyzeView() }
                case .styles:
                    NavigationStack { PersonalizeKeyboardView() }
                case .settings:
                    NavigationStack { SettingsView(isAuthenticated: $isAuthenticated) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // ── Custom bottom tab bar ──
            tabBar
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    // MARK: - Custom Tab Bar
    private var tabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppTheme.surfaceBorder)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .background(
            AppTheme.bg
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? tab.filledIcon : tab.icon)
                    .font(.system(size: 20))
                    .frame(height: 24)
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(-0.3)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(
                selectedTab == tab
                    ? AppTheme.accent
                    : AppTheme.accent.opacity(0.30)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy HomeView
struct HomeView: View {
    @Binding var isAuthenticated: Bool
    var body: some View {
        MainTabView(isAuthenticated: $isAuthenticated)
    }
}

#Preview {
    MainTabView(isAuthenticated: .constant(true))
}
