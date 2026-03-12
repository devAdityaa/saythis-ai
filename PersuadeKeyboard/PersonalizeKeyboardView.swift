import SwiftUI

// MARK: - Keyboard Theme Definition

struct KeyboardThemeOption: Identifiable {
    let id: String
    let name: String
    let bg: Color
    let card: Color
    let accent: Color

    static let all: [KeyboardThemeOption] = [
        KeyboardThemeOption(
            id: "default_dark", name: "Default Dark",
            bg:     Color(red: 16/255, green: 34/255,  blue: 34/255),
            card:   Color(red: 19/255, green: 236/255, blue: 236/255).opacity(0.05),
            accent: Color(red: 19/255, green: 236/255, blue: 236/255)
        ),
        KeyboardThemeOption(
            id: "ocean_blue", name: "Ocean Blue",
            bg:     Color(red: 8/255,   green: 16/255,  blue: 30/255),
            card:   Color(red: 15/255,  green: 30/255,  blue: 55/255),
            accent: Color(red: 0/255,   green: 150/255, blue: 255/255)
        ),
        KeyboardThemeOption(
            id: "midnight_purple", name: "Midnight Purple",
            bg:     Color(red: 14/255,  green: 10/255,  blue: 24/255),
            card:   Color(red: 28/255,  green: 20/255,  blue: 50/255),
            accent: Color(red: 160/255, green: 100/255, blue: 255/255)
        ),
        KeyboardThemeOption(
            id: "forest_green", name: "Forest Green",
            bg:     Color(red: 8/255,   green: 18/255,  blue: 12/255),
            card:   Color(red: 16/255,  green: 35/255,  blue: 22/255),
            accent: Color(red: 50/255,  green: 200/255, blue: 100/255)
        )
    ]
}

// MARK: - Available Mode Icons

private let modeIconOptions: [(String, String)] = [
    ("arrowshape.turn.up.left.fill", "Reply"),
    ("sparkle.magnifyingglass",      "Refine"),
    ("sparkles",                     "Sparkles"),
    ("bolt.fill",                    "Bolt"),
    ("wand.and.stars",               "Magic"),
    ("quote.bubble.fill",            "Quote"),
    ("megaphone.fill",               "Megaphone"),
    ("target",                       "Target"),
    ("checkmark.seal.fill",          "Seal"),
    ("flame.fill",                   "Flame"),
    ("brain.head.profile",           "Brain"),
    ("briefcase.fill",               "Briefcase"),
    ("chart.line.uptrend.xyaxis",    "Chart"),
    ("dollarsign.circle.fill",       "Dollar"),
    ("person.fill.checkmark",        "Close"),
    ("envelope.fill",                "Email")
]

// MARK: - Personalize Keyboard View (redesigned for new design language)

struct PersonalizeKeyboardView: View {
    @Environment(\.dismiss) private var dismiss

    // Theme state
    @State private var selectedTheme = "default_dark"

    // Mode state
    @State private var modes: [GenerationMode] = []
    @State private var editingModeID: UUID? = nil
    @State private var showAddMode = false

    // Save state
    @State private var isSaving    = false
    @State private var saveSuccess = false
    @State private var errorMessage: String?
    @State private var isLoading   = true

    private let themeKey = "keyboard_theme"

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (matching workspace header style) ──
            stylesHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .tint(AppTheme.accent)
                            .padding(.top, 40)
                    } else {
                        // ── Theme Section ──
                        themeSection

                        // ── Generation Modes Section ──
                        modesSection

                        // ── Save ──
                        saveButton

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.danger)
                                .transition(.opacity)
                        }
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { loadSettings() }
        .sheet(isPresented: $showAddMode) {
            AddModeSheet { newMode in
                modes.append(newMode)
                saveModesLocally()
            }
        }
    }

    // MARK: - Header
    private var stylesHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.accent)
                .frame(width: 38, height: 38)
                .background(AppTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text("Styles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.text)
                Text("PERSONALIZE")
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

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "paintpalette.fill", title: "Keyboard Theme")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(KeyboardThemeOption.all) { theme in
                    ThemeCard(theme: theme, isSelected: selectedTheme == theme.id) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTheme = theme.id }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Modes Section

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "rectangle.stack.fill", title: "AI Styles")

            Text("Choose how the AI writes for you. Add your own instructions or create new styles.")
                .font(.system(size: 12))
                .foregroundColor(AppTheme.subtext)
                .lineSpacing(2)

            ForEach($modes) { $mode in
                ModeCard(
                    mode: $mode,
                    isExpanded: editingModeID == mode.id,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            editingModeID = editingModeID == mode.id ? nil : mode.id
                        }
                    },
                    onDelete: {
                        withAnimation {
                            modes.removeAll { $0.id == mode.id }
                            if editingModeID == mode.id { editingModeID = nil }
                            saveModesLocally()
                        }
                    }
                )
            }

            // Add custom mode button
            Button {
                showAddMode = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.accent)
                    Text("Add Custom Mode")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.accent.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.accent.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(AppTheme.accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: saveSettings) {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView().tint(Color(red: 16/255, green: 34/255, blue: 34/255))
                } else {
                    Image(systemName: saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 14))
                }
                Text(saveSuccess ? "Saved!" : "Save Changes")
                    .font(.system(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(saveSuccess ? Color.green.opacity(0.85) : AppTheme.accent)
            .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppTheme.accent.opacity(0.25), radius: 16, y: 4)
        }
        .disabled(isSaving)
        .opacity(isSaving ? 0.7 : 1)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.accent)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.text)
        }
    }

    // MARK: - Load / Save

    private func loadSettings() {
        selectedTheme = UserScopedStorage.getShared(forKey: themeKey) ?? "default_dark"
        modes = GenerationModeStore.loadModes()

        APIService.shared.getSettings { result in
            if case .success(let settings) = result {
                if !settings.theme.isEmpty { selectedTheme = settings.theme }
            }
            isLoading = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { isLoading = false }
    }

    private func saveModesLocally() {
        GenerationModeStore.saveModes(modes)
    }

    private func saveSettings() {
        withAnimation { errorMessage = nil; saveSuccess = false }
        isSaving = true

        UserScopedStorage.setShared(selectedTheme, forKey: themeKey)
        // Also write plain key to App Group so keyboard extension can read it
        UserDefaults(suiteName: UserScopedStorage.appGroupID)?.set(selectedTheme, forKey: themeKey)
        GenerationModeStore.saveModes(modes)

        APIService.shared.updateSettings(theme: selectedTheme) { result in
            isSaving = false
            withAnimation { saveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { saveSuccess = false }
            }
        }
    }
}

// MARK: - Mode Card

private struct ModeCard: View {
    @Binding var mode: GenerationMode
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(mode.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.text)
                            if mode.isBuiltIn {
                                Text("Built-in")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(AppTheme.accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(mode.inputSource == .clipboard ? "Reads clipboard" : "Reads typed text")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.subtext)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.subtext.opacity(0.6))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded editor
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle()
                        .fill(AppTheme.surfaceBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 12)

                    if mode.isBuiltIn {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Custom Instructions")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppTheme.subtext)
                                .padding(.horizontal, 12)

                            Text("Add extra rules on top of the default behavior")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.subtext.opacity(0.6))
                                .padding(.horizontal, 12)

                            TextEditor(text: $mode.userInstructions)
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.text)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(minHeight: 80, maxHeight: 140)
                                .background(AppTheme.accent.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                                )
                                .padding(.horizontal, 12)
                                .tint(AppTheme.accent)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            // Name
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppTheme.subtext)
                                TextField("Mode name", text: $mode.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(AppTheme.accent.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                                    )
                                    .tint(AppTheme.accent)
                            }
                            .padding(.horizontal, 12)

                            // Icon picker
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Icon")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppTheme.subtext)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(modeIconOptions, id: \.0) { iconName, _ in
                                            Button {
                                                mode.icon = iconName
                                            } label: {
                                                Image(systemName: iconName)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(mode.icon == iconName ? Color(red: 16/255, green: 34/255, blue: 34/255) : AppTheme.subtext)
                                                    .frame(width: 34, height: 34)
                                                    .background(mode.icon == iconName ? AppTheme.accent : AppTheme.accent.opacity(0.05))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                }
                            }
                            .padding(.leading, 12)

                            // Input source
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Input Source")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppTheme.subtext)
                                HStack(spacing: 6) {
                                    inputSourcePill(label: "Clipboard", source: .clipboard)
                                    inputSourcePill(label: "Typed Text", source: .textField)
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 12)

                            // System prompt
                            VStack(alignment: .leading, spacing: 4) {
                                Text("System Prompt")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppTheme.subtext)
                                TextEditor(text: $mode.baseSystemPrompt)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.text)
                                    .scrollContentBackground(.hidden)
                                    .padding(10)
                                    .frame(minHeight: 100, maxHeight: 160)
                                    .background(AppTheme.accent.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                                    )
                                    .tint(AppTheme.accent)
                            }
                            .padding(.horizontal, 12)

                            // Delete
                            Button(role: .destructive) {
                                onDelete()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                    Text("Delete Mode")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.red.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.accent.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(AppTheme.accent.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    @ViewBuilder
    private func inputSourcePill(label: String, source: GenerationMode.InputSource) -> some View {
        Button {
            mode.inputSource = source
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(mode.inputSource == source ? Color(red: 16/255, green: 34/255, blue: 34/255) : AppTheme.subtext)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(mode.inputSource == source ? AppTheme.accent : AppTheme.accent.opacity(0.05))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Add Mode Sheet

private struct AddModeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (GenerationMode) -> Void

    @State private var name        = ""
    @State private var icon        = "sparkles"
    @State private var prompt      = ""
    @State private var inputSource = GenerationMode.InputSource.clipboard

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mode Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.subtext)
                        TextField("e.g. Follow-Up, Cold Pitch...", text: $name)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.text)
                            .padding(12)
                            .background(AppTheme.accent.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                            )
                            .tint(AppTheme.accent)
                    }

                    // Icon
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.subtext)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                            ForEach(modeIconOptions, id: \.0) { iconName, _ in
                                Button { icon = iconName } label: {
                                    Image(systemName: iconName)
                                        .font(.system(size: 14))
                                        .foregroundColor(icon == iconName ? Color(red: 16/255, green: 34/255, blue: 34/255) : AppTheme.subtext)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .background(icon == iconName ? AppTheme.accent : AppTheme.accent.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }

                    // Input source
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input Source")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.subtext)
                        HStack(spacing: 8) {
                            ForEach([(GenerationMode.InputSource.clipboard, "Clipboard"), (.textField, "Typed Text")], id: \.0) { src, label in
                                Button { inputSource = src } label: {
                                    Text(label)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(inputSource == src ? Color(red: 16/255, green: 34/255, blue: 34/255) : AppTheme.subtext)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(inputSource == src ? AppTheme.accent : AppTheme.accent.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }

                    // System prompt
                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Prompt")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppTheme.subtext)
                        Text("Instruct the AI on how to generate responses in this mode. Return ONLY a JSON array of strings.")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.subtext.opacity(0.7))
                            .lineSpacing(2)
                        TextEditor(text: $prompt)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.text)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .frame(minHeight: 120)
                            .background(AppTheme.accent.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(AppTheme.accent.opacity(0.10), lineWidth: 1)
                            )
                            .tint(AppTheme.accent)
                    }

                    // Add button
                    Button {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty, !trimmedPrompt.isEmpty else { return }
                        let newMode = GenerationMode(
                            id: UUID(),
                            name: trimmedName,
                            icon: icon,
                            baseSystemPrompt: trimmedPrompt,
                            userInstructions: "",
                            inputSource: inputSource,
                            isBuiltIn: false
                        )
                        onAdd(newMode)
                        dismiss()
                    } label: {
                        Text("Add Mode")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 16/255, green: 34/255, blue: 34/255))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AppTheme.accent.opacity(0.4)
                                    : AppTheme.accent
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("New Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.subtext)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Theme Card

private struct ThemeCard: View {
    let theme: KeyboardThemeOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.bg)
                        .frame(height: 60)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.card)
                            .frame(width: 80, height: 14)
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.accent)
                                .frame(width: 36, height: 10)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.card)
                                .frame(width: 28, height: 10)
                        }
                    }
                }

                Text(theme.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? theme.accent : AppTheme.subtext)
            }
            .padding(10)
            .background(isSelected ? theme.accent.opacity(0.08) : AppTheme.accent.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? theme.accent : AppTheme.accent.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PersonalizeKeyboardView()
}
