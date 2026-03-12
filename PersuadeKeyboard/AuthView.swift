import SwiftUI

// MARK: - Auth View (onboarding hero + transparent bottom-sheet auth + multi-step onboarding)
struct AuthView: View {
    @Binding var isAuthenticated: Bool

    // ── Onboarding step: 1 = hero, 2 = personal details, 3 = preferences ──
    @State private var onboardingStep: Int = 1

    // ── Auth sheet state ──
    @State private var showAuthSheet = false
    @State private var isSignUp = true
    @State private var sheetOffset: CGFloat = 0

    // ── Auth form fields ──
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // ── Step 2: Personal details ──
    @State private var userName = ""
    @State private var dateOfBirth = Date()

    // ── Step 3: Preferences ──
    @State private var selectedUseCases: Set<String> = []
    @State private var selectedTones: Set<String> = []

    // ── Loading screen ──
    @State private var showLoadingScreen = false
    @State private var loadingProgress: CGFloat = 0
    @State private var loadingPulse = false

    // ── Keyboard tracking ──
    @State private var keyboardHeight: CGFloat = 0

    // ── Animations ──
    @State private var appeared = false
    @State private var sphereFloat = false
    @State private var glowPulse = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var buttonsVisible = false
    @State private var dotsVisible = false

    // ── Typewriter cycling ──
    private let cyclingWords = ["Instantly.", "Confidently.", "Perfectly."]
    @State private var displayedWord = "Instantly."

    private let useCaseOptions = [
        ("message.fill", "Messaging"),
        ("envelope.fill", "Email"),
        ("briefcase.fill", "Work"),
        ("graduationcap.fill", "Education"),
        ("heart.fill", "Relationships"),
        ("cart.fill", "Sales")
    ]

    private let toneOptions = [
        "Professional", "Friendly", "Assertive",
        "Polite", "Casual", "Persuasive",
        "Empathetic", "Concise"
    ]

    var body: some View {
        GeometryReader { screen in
            let h = screen.size.height
            let w = screen.size.width

            ZStack {
                // ── Background ──
                AppTheme.bg.ignoresSafeArea()
                AmbientBackground()
                FloatingParticles()

                // ── Main content ──
                switch onboardingStep {
                case 1:
                    heroSection(screenHeight: h, screenWidth: w)
                case 2:
                    personalDetailsStep(screenWidth: w)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 3:
                    preferencesStep(screenWidth: w)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                default:
                    EmptyView()
                }

                // ── Auth bottom sheet ──
                if showAuthSheet {
                    authSheetOverlay(screenHeight: h)
                }

                // ── Loading overlay ──
                if showLoadingScreen {
                    loadingOverlay()
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            startEntranceAnimations()
            setupKeyboardObservers()
        }
    }

    // MARK: - Keyboard Observers
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil, queue: .main
        ) { notification in
            if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
                withAnimation(.easeOut(duration: duration)) {
                    keyboardHeight = frame.height
                }
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil, queue: .main
        ) { notification in
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                keyboardHeight = 0
            }
        }
    }

    // MARK: - Entrance Animations
    private func startEntranceAnimations() {
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) { appeared = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.6)) { titleVisible = true }
        withAnimation(.easeOut(duration: 0.7).delay(0.9)) { subtitleVisible = true }
        withAnimation(.easeOut(duration: 0.7).delay(1.1)) { buttonsVisible = true }
        withAnimation(.easeOut(duration: 0.5).delay(1.4)) { dotsVisible = true }

        // Continuous floating
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true).delay(0.5)) {
            sphereFloat = true
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.3)) {
            glowPulse = true
        }

        // Start typewriter cycling after title appears
        Task { await typewriterLoop() }
    }

    @MainActor
    private func typewriterLoop() async {
        // Wait for entrance animation to settle
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        var idx = 0

        while !Task.isCancelled {
            // Erase current word
            while !displayedWord.isEmpty {
                displayedWord.removeLast()
                try? await Task.sleep(nanoseconds: 55_000_000) // 55ms per char
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // pause between words

            // Advance to next word
            idx = (idx + 1) % cyclingWords.count
            let word = cyclingWords[idx]

            // Type next word
            for i in 1...word.count {
                let endIdx = word.index(word.startIndex, offsetBy: i)
                displayedWord = String(word[..<endIdx])
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms per char
            }

            // Show word for a moment
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s pause
        }
    }

    // MARK: - Hero Section (Step 1)
    private func heroSection(screenHeight: CGFloat, screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // ── Top bar ──
            HStack {
                Spacer()
                Text("STEP 1 OF 3")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(AppTheme.accent)
                Spacer()
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)
            .opacity(appeared ? 1 : 0)

            Spacer()

            // ── Obsidian Sphere (floating) ──
            ZStack {
                // Glow behind sphere
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.accent.opacity(glowPulse ? 0.12 : 0.06), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 320)

                BlobView(size: 192)
            }
            .offset(y: sphereFloat ? -8 : 8)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.6)

            Spacer()

            // ── Content (no card background — clean floating text) ──
            VStack(spacing: 28) {
                VStack(spacing: 14) {
                    // Headline — static first line, cycling word on second line
                    VStack(spacing: 4) {
                        Text("Say the right thing.")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(AppTheme.text)

                        // Fixed-size container: invisible anchor (widest word) prevents layout shift
                        ZStack {
                            Text("Confidently.")
                                .font(.system(size: 32, weight: .bold))
                                .italic()
                                .opacity(0)
                            Text(displayedWord.isEmpty ? "\u{200B}" : displayedWord)
                                .font(.system(size: 32, weight: .bold))
                                .italic()
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .multilineTextAlignment(.center)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 20)

                    // Subtitle
                    Text(RemoteConfigService.shared.cached?.ui.landingSubtitle ?? "Your AI companion for any messaging app.\nCopy, paste, and send with confidence.")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.subtext)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(subtitleVisible ? 1 : 0)
                        .offset(y: subtitleVisible ? 0 : 15)
                }
                .padding(.horizontal, 24)

                // ── Action buttons ──
                VStack(spacing: 12) {
                    Button {
                        isSignUp = true
                        errorMessage = nil
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                            showAuthSheet = true
                        }
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.accent)
                            .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppTheme.accent.opacity(0.35), radius: 24, y: 6)
                    }

                    Button {
                        isSignUp = false
                        errorMessage = nil
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                            showAuthSheet = true
                        }
                    } label: {
                        Text("Log in")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 24)
                .opacity(buttonsVisible ? 1 : 0)
                .offset(y: buttonsVisible ? 0 : 20)

                // ── Progress dots ──
                progressDots(activeStep: 1)
                    .opacity(dotsVisible ? 1 : 0)
                    .padding(.bottom, 44)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Dots
    private func progressDots(activeStep: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                if step == activeStep {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: 24, height: 5)
                } else {
                    Circle()
                        .fill(step < activeStep
                              ? AppTheme.accent.opacity(0.5)
                              : AppTheme.subtext.opacity(0.3))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: activeStep)
    }

    // MARK: - Auth Bottom Sheet (transparent glass)
    private func authSheetOverlay(screenHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // Backdrop — blurred, tap to dismiss
            Color.black.opacity(0.35)
                .background(.ultraThinMaterial.opacity(0.3))
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        showAuthSheet = false
                    }
                }

            // ── Sheet ──
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 20)

                // Header
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Say")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.text)
                        Text("This")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.accent)
                    }

                    Text(isSignUp ? "Create your account" : "Welcome back")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.subtext)
                }
                .padding(.bottom, 24)

                // Form
                VStack(spacing: 14) {
                    // Email
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email Address")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.subtext.opacity(0.8))
                            .padding(.leading, 4)

                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.subtext.opacity(0.5))
                            TextField(
                                "",
                                text: $email,
                                prompt: Text("name@example.com")
                                    .foregroundColor(Color.gray)
                            )
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.text)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .tint(AppTheme.accent)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Password")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.subtext.opacity(0.8))
                            .padding(.leading, 4)

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.subtext.opacity(0.5))
                            SecureField("••••••••", text: $password)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.text)
                                .tint(AppTheme.accent)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }

                    // Confirm password
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Confirm Password")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.subtext.opacity(0.8))
                                .padding(.leading, 4)

                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.subtext.opacity(0.5))
                                SecureField("••••••••", text: $confirmPassword)
                                    .font(.system(size: 15))
                                    .foregroundColor(AppTheme.text)
                                    .tint(AppTheme.accent)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 24)

                // Error
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.danger)
                        .padding(.top, 10)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                Spacer().frame(height: 24)

                // Primary button
                Button(action: handleAuth) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(Color(red: 16/255, green: 34/255, blue: 34/255))
                        }
                        Text(isSignUp ? "Create Account" : "Log In")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppTheme.accent)
                    .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: AppTheme.accent.opacity(0.25), radius: 20, y: 4)
                }
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)
                .padding(.horizontal, 24)

                // Toggle
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundColor(AppTheme.subtext)
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    } label: {
                        Text(isSignUp ? "Sign In" : "Sign Up")
                            .foregroundColor(AppTheme.accent)
                            .fontWeight(.bold)
                    }
                }
                .font(.system(size: 14))
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
            .background(
                // Glass background
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.bg.opacity(0.85))
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 40, y: -8)
                    .ignoresSafeArea(edges: .bottom)
            )
            .offset(y: sheetOffset - keyboardHeight)
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let t = value.translation.height
                        withAnimation(.interactiveSpring()) {
                            sheetOffset = max(0, t)
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 || value.predictedEndTranslation.height > 200 {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                showAuthSheet = false
                                sheetOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                sheetOffset = 0
                            }
                        }
                    }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: showAuthSheet)
        .animation(.easeInOut(duration: 0.3), value: isSignUp)
    }

    // MARK: - Step 2: Personal Details
    private func personalDetailsStep(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("STEP 2 OF 3")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(AppTheme.accent)
                Spacer()
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("Tell us about yourself")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppTheme.text)
                        .multilineTextAlignment(.center)

                    Text("This helps us personalize your experience")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.subtext)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    // Name
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.subtext.opacity(0.8))
                            .padding(.leading, 4)

                        HStack(spacing: 12) {
                            Image(systemName: "person")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.subtext.opacity(0.5))
                            TextField("Enter your name", text: $userName)
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.text)
                                .tint(AppTheme.accent)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }

                    // Date of Birth
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Date of Birth")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.subtext.opacity(0.8))
                            .padding(.leading, 4)

                        DatePicker(
                            "Date of Birth",
                            selection: $dateOfBirth,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .colorScheme(.dark)
                    }
                }
                .padding(.horizontal, 24)

                // Continue
                VStack(spacing: 10) {
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        UserDefaults.standard.set(userName, forKey: "user_display_name")
                        let formatter = ISO8601DateFormatter()
                        UserDefaults.standard.set(formatter.string(from: dateOfBirth), forKey: "user_date_of_birth")
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            onboardingStep = 3
                        }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(userName.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? AppTheme.accent.opacity(0.4) : AppTheme.accent)
                            .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: AppTheme.accent.opacity(0.2), radius: 16, y: 4)
                    }
                    .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            onboardingStep = 3
                        }
                    } label: {
                        Text("Skip for now")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.subtext.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)

                progressDots(activeStep: 2)
                    .padding(.bottom, 44)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(y: -keyboardHeight * 0.5)
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        .onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }

    // MARK: - Step 3: Preferences
    private func preferencesStep(screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("STEP 3 OF 3")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(AppTheme.accent)
                Spacer()
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text("Customize your experience")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.text)
                            .multilineTextAlignment(.center)

                        Text("Select what you'll use SayThis for")
                            .font(.system(size: 15))
                            .foregroundColor(AppTheme.subtext)
                            .multilineTextAlignment(.center)
                    }

                    // Use cases
                    VStack(alignment: .leading, spacing: 10) {
                        Text("I WANT TO USE SAYTHIS FOR")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(AppTheme.accent.opacity(0.6))

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ], spacing: 10) {
                            ForEach(useCaseOptions, id: \.1) { icon, label in
                                preferenceChip(
                                    icon: icon, label: label,
                                    isSelected: selectedUseCases.contains(label)
                                ) {
                                    if selectedUseCases.contains(label) {
                                        selectedUseCases.remove(label)
                                    } else {
                                        selectedUseCases.insert(label)
                                    }
                                }
                            }
                        }
                    }

                    // Tones
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PREFERRED TONE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(AppTheme.accent.opacity(0.6))

                        FlowLayout(spacing: 8) {
                            ForEach(toneOptions, id: \.self) { tone in
                                toneChip(
                                    tone: tone,
                                    isSelected: selectedTones.contains(tone)
                                ) {
                                    if selectedTones.contains(tone) {
                                        selectedTones.remove(tone)
                                    } else {
                                        selectedTones.insert(tone)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            // Finish
            VStack(spacing: 10) {
                Button {
                    UserDefaults.standard.set(Array(selectedUseCases), forKey: "user_use_cases")
                    UserDefaults.standard.set(Array(selectedTones), forKey: "user_preferred_tones")
                    startLoadingTransition()
                } label: {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppTheme.accent)
                        .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: AppTheme.accent.opacity(0.25), radius: 20, y: 4)
                }

                Button {
                    startLoadingTransition()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.subtext.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)

            progressDots(activeStep: 3)
                .padding(.top, 20)
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preference Chip
    private func preferenceChip(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { action() }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(isSelected ? Color(red: 16/255, green: 34/255, blue: 34/255) : AppTheme.subtext)
            .background(isSelected ? AppTheme.accent : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? AppTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tone Chip
    private func toneChip(tone: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { action() }
        }) {
            Text(tone)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundColor(isSelected ? Color(red: 16/255, green: 34/255, blue: 34/255) : AppTheme.subtext)
                .background(isSelected ? AppTheme.accent : Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? AppTheme.accent : Color.white.opacity(0.08), lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading overlay
    private func loadingOverlay() -> some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()
            AmbientBackground()

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [AppTheme.accent.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(1.0 + loadingProgress * 0.2)

                    BlobView(size: 100, interactive: false)
                        .scaleEffect(loadingPulse ? 1.12 : 0.92)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: loadingPulse)
                        .onAppear { loadingPulse = true }
                }

                VStack(spacing: 16) {
                    Text("Setting up your experience...")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppTheme.text)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppTheme.accent.opacity(0.1))
                                .frame(height: 4)
                            Capsule()
                                .fill(AppTheme.accent)
                                .frame(width: geo.size.width * loadingProgress, height: 4)
                                .shadow(color: AppTheme.accent.opacity(0.4), radius: 8)
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: 220)
                }
            }
        }
    }

    // MARK: - Loading transition
    private func startLoadingTransition() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showLoadingScreen = true
        }
        withAnimation(.easeInOut(duration: 2.0)) {
            loadingProgress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isAuthenticated = true
            }
        }
    }

    // MARK: - Auth action
    private func handleAuth() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )

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
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                        showAuthSheet = false
                        sheetOffset = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                            onboardingStep = 2
                        }
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
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangeSubviews(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}

#Preview {
    AuthView(isAuthenticated: .constant(false))
}
