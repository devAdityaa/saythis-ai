import SwiftUI

// MARK: - Home View (Action-driven dashboard with paste input + tool cards)
struct HomeView: View {
    @Binding var isAuthenticated: Bool
    @State private var showAnalyze = false
    @State private var showSettings = false
    @State private var showChat = false
    @State private var showPersonalize = false

    // Dashboard entrance animations
    @State private var dashboardAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                AmbientBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 12)

                        // ── Header ──
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 0) {
                                    Text("Say")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("This")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(AppTheme.accent)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(AppTheme.accent)
                                    Text("Say the right thing. Instantly.")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.subtext)
                                }
                            }
                            Spacer()
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.subtext)
                                    .frame(width: 40, height: 40)
                                    .background(AppTheme.card)
                                    .clipShape(Circle())
                            }
                        }
                        .opacity(dashboardAppeared ? 1 : 0)
                        .offset(y: dashboardAppeared ? 0 : 18)

                        // ── Tools Section ──
                        HStack {
                            Text("Tools")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppTheme.subtext.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(1.2)
                            Spacer()
                        }
                        .padding(.leading, 2)
                        .opacity(dashboardAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.12), value: dashboardAppeared)

                        VStack(spacing: 12) {
                            FeatureCard(
                                icon: "camera.viewfinder",
                                title: "Screenshot Reply",
                                description: "Confused what to reply? Screenshot it and get suggestions",
                                badgeText: "Vision AI"
                            ) { showAnalyze = true }
                                .opacity(dashboardAppeared ? 1 : 0)
                                .offset(y: dashboardAppeared ? 0 : 24)
                                .animation(.easeOut(duration: 0.5).delay(0.14), value: dashboardAppeared)

                            FeatureCard(
                                icon: "bubble.left.and.bubble.right",
                                title: "Think",
                                description: "Your thinking space to work through any reply",
                                badgeText: "AI Chat"
                            ) { showChat = true }
                                .opacity(dashboardAppeared ? 1 : 0)
                                .offset(y: dashboardAppeared ? 0 : 24)
                                .animation(.easeOut(duration: 0.5).delay(0.18), value: dashboardAppeared)

                            FeatureCard(
                                icon: "paintbrush.pointed.fill",
                                title: "AI Styles",
                                description: "Choose your AI tone and customize how it writes",
                                badgeText: "Customize"
                            ) { showPersonalize = true }
                                .opacity(dashboardAppeared ? 1 : 0)
                                .offset(y: dashboardAppeared ? 0 : 24)
                                .animation(.easeOut(duration: 0.5).delay(0.22), value: dashboardAppeared)
                        }

                        // ── Pro Tip ──
                        HStack(spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow.opacity(0.8))

                            Text("Pro tip: ")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white) +
                            Text("Use the SayThis keyboard directly in any messaging app!")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.subtext)

                            Spacer()
                        }
                        .padding(12)
                        .background(AppTheme.card2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .opacity(dashboardAppeared ? 1 : 0)
                        .offset(y: dashboardAppeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.26), value: dashboardAppeared)

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                guard !dashboardAppeared else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        dashboardAppeared = true
                    }
                }
            }
            .navigationDestination(isPresented: $showAnalyze) {
                AnalyzeView()
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(isAuthenticated: $isAuthenticated)
            }
            .navigationDestination(isPresented: $showChat) {
                ChatView()
            }
            .navigationDestination(isPresented: $showPersonalize) {
                PersonalizeKeyboardView()
            }
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    var badgeText: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard !isDisabled else { return }
            action()
        }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isDisabled ? AppTheme.subtext : AppTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(
                            (isDisabled ? AppTheme.subtext : AppTheme.accent).opacity(0.12)
                        )
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isDisabled ? AppTheme.subtext : .white)

                        if let badgeText {
                            Text(badgeText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isDisabled ? AppTheme.subtext : AppTheme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    (isDisabled ? AppTheme.subtext : AppTheme.accent).opacity(0.12)
                                )
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isDisabled ? AppTheme.subtext.opacity(0.4) : AppTheme.accent)
                }

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.subtext)
                    .lineLimit(2)
            }
            .padding(16)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isDisabled ? Color.white.opacity(0.04) : AppTheme.accent.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .opacity(isDisabled ? 0.6 : 1)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isDisabled { withAnimation(.easeOut(duration: 0.1)) { pressed = true } } }
                .onEnded   { _ in withAnimation(.easeOut(duration: 0.2)) { pressed = false } }
        )
    }
}

#Preview {
    HomeView(isAuthenticated: .constant(true))
}
