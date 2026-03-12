import SwiftUI

// MARK: - Settings View (redesigned to match premium design language)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isAuthenticated: Bool

    @State private var serverURL = ""
    @State private var showServerConfig = false
    @State private var showSignOutConfirm = false
    @State private var userDisplayName = ""
    @State private var userDOBString = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──
            settingsHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // ── Account Info ──
                    if let email = APIService.shared.userEmail {
                        settingsCard {
                            HStack(spacing: 12) {
                                // Avatar circle — first letter of name or email
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.accentGradient)
                                        .frame(width: 44, height: 44)
                                    let initial = userDisplayName.isEmpty
                                        ? String(email.prefix(1)).uppercased()
                                        : String(userDisplayName.prefix(1)).uppercased()
                                    Text(initial)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    if !userDisplayName.isEmpty {
                                        Text(userDisplayName)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppTheme.text)
                                    } else {
                                        Text("Account")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AppTheme.text)
                                    }
                                    Text(email)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.subtext)
                                    if !userDOBString.isEmpty,
                                       let date = ISO8601DateFormatter().date(from: userDOBString) {
                                        let fmt: DateFormatter = {
                                            let f = DateFormatter()
                                            f.dateStyle = .long
                                            return f
                                        }()
                                        Text(fmt.string(from: date))
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.subtext.opacity(0.6))
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    // ── Keyboard Setup ──
                    settingsCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "keyboard")
                                    .foregroundColor(AppTheme.accent)
                                    .font(.system(size: 15))
                                Text("Keyboard Setup")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(AppTheme.text)
                            }

                            VStack(alignment: .leading, spacing: 10) {
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
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(AppTheme.accent)
                                .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    // ── Server Configuration (Developer) ──
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                withAnimation { showServerConfig.toggle() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(AppTheme.accent)
                                        .font(.system(size: 15))
                                    Text("Server Configuration")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppTheme.text)
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
                                    .foregroundColor(AppTheme.text)
                                    .padding(12)
                                    .background(AppTheme.accent.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                                    )
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .tint(AppTheme.accent)

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
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(AppTheme.accent)
                                    .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }

                    // ── Sign Out ──
                    Button {
                        showSignOutConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 13))
                            Text("Sign Out")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(AppTheme.danger)
                        .background(AppTheme.danger.opacity(0.08))
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

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            serverURL = APIService.shared.baseURL
            userDisplayName = UserDefaults.standard.string(forKey: "user_display_name") ?? ""
            userDOBString = UserDefaults.standard.string(forKey: "user_date_of_birth") ?? ""
        }
    }

    // MARK: - Header
    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .frame(width: 38, height: 38)
                .background(AppTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text("Settings")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.text)
                Text("CONFIGURATION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(AppTheme.accent.opacity(0.6))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            AppTheme.glassBackground
                .overlay(
                    Rectangle()
                        .fill(AppTheme.surfaceBorder)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Card wrapper
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(AppTheme.accent.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
            )
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
                .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.text.opacity(0.85))
        }
    }
}

#Preview {
    SettingsView(isAuthenticated: .constant(true))
}
