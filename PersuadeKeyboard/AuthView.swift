import SwiftUI

// MARK: - Auth View (Landing hero → snap-scroll → Auth form)
struct AuthView: View {
    @Binding var isAuthenticated: Bool

    // Auth form state
    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Two-page snap state: 0 = hero/landing, 1 = auth form
    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0

    // Hero entrance animation
    @State private var appeared = false

    // Chevron bounce
    @State private var chevronAnimating = false

    // Typewriter cycling
    @State private var displayedWord = ""
    @State private var cursorVisible = true
    @State private var wordIndex = 0
    @State private var charIndex = 0
    @State private var isDeleting = false
    // Snapshot words once to avoid mid-animation changes from async config fetch
    @State private var words: [String] = ["Companion", "Sidekick", "Wingman", "Assistant", "Edge"]
    @State private var typingStarted = false

    var body: some View {
        GeometryReader { screen in
            let h = screen.size.height
            let w = screen.size.width

            ZStack {
                AppTheme.bg.ignoresSafeArea()

                // Enhanced animated background
                AmbientBackground()
                FloatingParticles()

                // Two-page container
                ZStack(alignment: .top) {
                    heroSection(screenHeight: h)
                        .frame(width: w, height: h)
                        .offset(y: CGFloat(-currentPage) * h + dragOffset)

                    authFormSection(screenHeight: h, screenWidth: w)
                        .frame(width: w, height: h)
                        .offset(y: CGFloat(1 - currentPage) * h + dragOffset)
                }
                .frame(width: w, height: h)
                .clipped()
            }
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        let t = value.translation.height
                        if (currentPage == 0 && t > 0) || (currentPage == 1 && t < 0) {
                            dragOffset = t * 0.25  // rubber-band
                        } else {
                            dragOffset = t * 0.8
                        }
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        let velocity = value.predictedEndTranslation.height

                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            if currentPage == 0 && (value.translation.height < -threshold || velocity < -250) {
                                currentPage = 1
                            } else if currentPage == 1 && (value.translation.height > threshold || velocity > 250) {
                                currentPage = 0
                            }
                            dragOffset = 0
                        }
                    }
            )
        }
        .ignoresSafeArea()
        .onAppear {
            // Snapshot config words if available (prevents mid-animation array changes)
            if let configWords = RemoteConfigService.shared.cached?.ui.typewriterWords, !configWords.isEmpty {
                words = configWords
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                appeared = true
            }
            chevronAnimating = true
            guard !typingStarted else { return }
            typingStarted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                startTyping()
            }
            startCursorBlink()
        }
    }

    // MARK: - Hero / Landing Section
    private func heroSection(screenHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: screenHeight * 0.06)

            // Blob — slightly smaller frame to reduce dead space
            BlobView(size: 160)
                .frame(height: 210)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.6)

            BadgePill(icon: "sparkles", text: RemoteConfigService.shared.cached?.ui.landingBadge ?? "AI Messaging")
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .padding(.bottom, 10)

            // Title with typewriter
            HStack(spacing: 0) {
                Text("Your AI ")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(displayedWord)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppTheme.accent)
                Text(cursorVisible ? "|" : " ")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(AppTheme.accent)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
            .padding(.bottom, 6)

            VStack(spacing: 4) {
                Text(RemoteConfigService.shared.cached?.ui.landingSubtitle ?? "Always know what to say.")
                    .font(.system(size: 15))
                    .foregroundColor(AppTheme.subtext)
                Text("Copy. Paste. Send.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)

            Spacer().frame(height: screenHeight * 0.04)

            // Feature highlights — fills the blank space (dynamic from control panel)
            VStack(spacing: 10) {
                let configRows = RemoteConfigService.shared.cached?.ui.featureRows
                let rows = (configRows?.isEmpty == false ? configRows : nil) ?? [
                    RCFeatureRow(icon: "keyboard", text: "AI keyboard that works in any app"),
                    RCFeatureRow(icon: "camera.viewfinder", text: "Screenshot any chat and get a reply"),
                    RCFeatureRow(icon: "bubble.left.and.bubble.right", text: "Think through your reply before you send")
                ]
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    LandingFeatureRow(icon: row.icon, text: row.text)
                }
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()

            // Bouncing chevron
            VStack(spacing: 4) {
                Text("Swipe up to get started")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.subtext.opacity(0.6))
                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 20))
                    .foregroundColor(AppTheme.subtext.opacity(0.5))
                    .offset(y: chevronAnimating ? 8 : 0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: chevronAnimating)
            }
            .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Auth Form Section
    private func authFormSection(screenHeight: CGFloat, screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 20)

            Spacer().frame(height: screenHeight * 0.04)

            // Header
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Text("Say")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Text("This")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppTheme.accent)
                }

                Text(isSignUp
                     ? "Create your account to get started"
                     : "Welcome back! Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtext)
            }
            .padding(.bottom, 24)

            // Form fields
            VStack(spacing: 14) {
                AuthTextField(
                    icon: "envelope",
                    placeholder: "Email",
                    text: $email,
                    isSecure: false
                )

                AuthTextField(
                    icon: "lock",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true
                )

                if isSignUp {
                    AuthTextField(
                        icon: "lock.shield",
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        isSecure: true
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 24)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(AppTheme.danger)
                    .transition(.opacity)
                    .padding(.top, 10)
            }

            Spacer().frame(height: 20)

            // Primary button
            Button(action: handleAuth) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(AppTheme.accent)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.7 : 1)
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            // Toggle sign up / sign in
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSignUp.toggle()
                    errorMessage = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(AppTheme.subtext)
                    Text(isSignUp ? "Sign in" : "Sign up")
                        .foregroundColor(AppTheme.accent)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }

            Spacer()

            // Swipe back hint
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                Text("Swipe down to go back")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(AppTheme.subtext.opacity(0.3))
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Auth action
    private func handleAuth() {
        withAnimation { errorMessage = nil }

        guard !email.isEmpty, !password.isEmpty else {
            withAnimation { errorMessage = "Please fill in all fields." }
            return
        }
        guard email.contains("@") else {
            withAnimation { errorMessage = "Please enter a valid email." }
            return
        }
        if isSignUp {
            guard password == confirmPassword else {
                withAnimation { errorMessage = "Passwords don't match." }
                return
            }
            guard password.count >= 6 else {
                withAnimation { errorMessage = "Password must be at least 6 characters." }
                return
            }
        }

        isLoading = true

        if isSignUp {
            APIService.shared.register(email: email, password: password) { result in
                isLoading = false
                switch result {
                case .success:
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isAuthenticated = true
                    }
                case .failure(let error):
                    withAnimation { errorMessage = error.localizedDescription }
                }
            }
        } else {
            APIService.shared.login(email: email, password: password) { result in
                isLoading = false
                switch result {
                case .success:
                    withAnimation(.easeInOut(duration: 0.4)) {
                        isAuthenticated = true
                    }
                case .failure(let error):
                    withAnimation { errorMessage = error.localizedDescription }
                }
            }
        }
    }

    // MARK: - Typewriter animation
    private func startTyping() {
        // Safety: bail out if words array is empty
        guard !words.isEmpty else { return }

        // Safety: clamp wordIndex within bounds
        if wordIndex >= words.count { wordIndex = 0 }

        let word = words[wordIndex]

        if !isDeleting {
            if charIndex <= word.count {
                displayedWord = String(word.prefix(charIndex))
                charIndex += 1
                let delay = Double.random(in: 0.06...0.12)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { startTyping() }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    isDeleting = true
                    startTyping()
                }
            }
        } else {
            if charIndex > 0 {
                charIndex -= 1
                displayedWord = String(word.prefix(charIndex))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { startTyping() }
            } else {
                isDeleting = false
                wordIndex = (wordIndex + 1) % words.count
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { startTyping() }
            }
        }
    }

    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}

// MARK: - Landing Feature Row (small icon + text pill for hero page)
private struct LandingFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.subtext)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(AppTheme.card.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
        )
    }
}

// MARK: - Styled text field
struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.subtext)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(icon == "envelope" ? .emailAddress : .default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    AuthView(isAuthenticated: .constant(false))
}
