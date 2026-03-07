import SwiftUI

// MARK: - Settings View (keyboard setup, server URL, sign out)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isAuthenticated: Bool

    @State private var serverURL = ""
    @State private var showServerConfig = false

    @State private var showSignOutConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // ── Header ──
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.card)
                            .clipShape(Circle())
                    }
                    Spacer()
                }

                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                // ── Account Info ──
                if let email = APIService.shared.userEmail {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppTheme.accent)
                            Text("Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.subtext)
                            Text(email)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                            Spacer()
                        }
                        .padding(12)
                        .background(AppTheme.card2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // ── Keyboard Setup ──
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .foregroundColor(AppTheme.accent)
                        Text("Keyboard Setup")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SettingStep(n: 1, text: "Settings > General > Keyboard > Keyboards")
                        SettingStep(n: 2, text: "Add New Keyboard > SayThis")
                        SettingStep(n: 3, text: "Tap SayThis > Allow Full Access")
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gear")
                                .font(.system(size: 13))
                            Text("Open Settings")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // ── Server Configuration (Developer) ──
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation { showServerConfig.toggle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "server.rack")
                                .foregroundColor(AppTheme.accent)
                            Text("Server Configuration")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: showServerConfig ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.subtext)
                        }
                    }

                    if showServerConfig {
                        Text("Backend API URL for authentication and data sync.")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.subtext)

                        TextField("http://localhost:3000", text: $serverURL)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(AppTheme.card2)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button {
                            let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                APIService.shared.baseURL = trimmed
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13))
                                Text("Update Server URL")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.accent)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // ── Sign Out ──
                Button {
                    showSignOutConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13))
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(AppTheme.danger)
                    .background(AppTheme.danger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppTheme.danger.opacity(0.2), lineWidth: 1)
                    )
                }
                .alert("Sign Out", isPresented: $showSignOutConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Sign Out", role: .destructive) {
                        APIService.shared.signOut()
                        withAnimation { isAuthenticated = false }
                    }
                } message: {
                    Text("Are you sure you want to sign out?")
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            serverURL = APIService.shared.baseURL
        }
    }
}

private struct SettingStep: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 20, height: 20)
                .background(AppTheme.accent)
                .foregroundColor(.black)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

#Preview {
    SettingsView(isAuthenticated: .constant(true))
}
