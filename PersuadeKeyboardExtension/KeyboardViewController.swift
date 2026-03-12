import UIKit

// MARK: - Dynamic Theme

enum KBTheme {
    private static let appGroupID = "group.com.goatedx.persuade"

    static var themeID: String {
        let group = UserDefaults(suiteName: appGroupID)
        group?.synchronize()
        return group?.string(forKey: "keyboard_theme")
            ?? UserDefaults.standard.string(forKey: "keyboard_theme")
            ?? "default_dark"
    }

    static var bg: UIColor {
        switch themeID {
        case "ocean_blue":       return UIColor(red: 8/255,  green: 16/255, blue: 30/255,  alpha: 1)
        case "midnight_purple":  return UIColor(red: 14/255, green: 10/255, blue: 24/255,  alpha: 1)
        case "forest_green":     return UIColor(red: 8/255,  green: 18/255, blue: 12/255,  alpha: 1)
        default:                 return UIColor(red: 9/255,  green: 14/255, blue: 23/255,  alpha: 1)
        }
    }

    static var card: UIColor {
        switch themeID {
        case "ocean_blue":       return UIColor(red: 15/255, green: 30/255, blue: 55/255,  alpha: 1)
        case "midnight_purple":  return UIColor(red: 28/255, green: 20/255, blue: 50/255,  alpha: 1)
        case "forest_green":     return UIColor(red: 16/255, green: 35/255, blue: 22/255,  alpha: 1)
        default:                 return UIColor(red: 18/255, green: 30/255, blue: 46/255,  alpha: 1)
        }
    }

    static var card2: UIColor {
        switch themeID {
        case "ocean_blue":       return UIColor(red: 10/255, green: 22/255, blue: 42/255,  alpha: 1)
        case "midnight_purple":  return UIColor(red: 20/255, green: 14/255, blue: 36/255,  alpha: 1)
        case "forest_green":     return UIColor(red: 12/255, green: 26/255, blue: 16/255,  alpha: 1)
        default:                 return UIColor(red: 14/255, green: 24/255, blue: 38/255,  alpha: 1)
        }
    }

    static var accent: UIColor {
        switch themeID {
        case "ocean_blue":       return UIColor(red: 0/255,   green: 150/255, blue: 255/255, alpha: 1)
        case "midnight_purple":  return UIColor(red: 160/255, green: 100/255, blue: 255/255, alpha: 1)
        case "forest_green":     return UIColor(red: 50/255,  green: 200/255, blue: 100/255, alpha: 1)
        default:                 return UIColor(red: 0/255,   green: 200/255, blue: 200/255, alpha: 1)
        }
    }

    static let text: UIColor    = .white
    static let subtext: UIColor = UIColor(white: 0.62, alpha: 1)
    static let danger: UIColor  = .systemRed

    static var logoImageName: String {
        switch themeID {
        case "ocean_blue":      return "persuadeKeyboardLogoOcean"
        case "midnight_purple": return "persuadeKeyboardLogoPurple"
        case "forest_green":    return "persuadeKeyboardLogoGreen"
        default:                return "persuadeKeyboardLogo"
        }
    }
}

// MARK: - Mode Pill Button

final class ModePillButton: UIButton {
    var mode: KBGenerationMode

    init(mode: KBGenerationMode) {
        self.mode = mode
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 13
        layer.masksToBounds = true
        titleLabel?.font = .systemFont(ofSize: 11.5, weight: .semibold)
        contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

        // Icon + title
        let icon = UIImage(systemName: mode.icon,
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        setImage(icon, for: .normal)
        setTitle(" \(mode.name)", for: .normal)
        imageView?.contentMode = .scaleAspectFit

        // Semantic ordering
        semanticContentAttribute = .forceLeftToRight

        heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ selected: Bool) {
        if selected {
            backgroundColor = KBTheme.accent
            setTitleColor(.black, for: .normal)
            tintColor = .black
        } else {
            backgroundColor = KBTheme.card2
            setTitleColor(KBTheme.subtext, for: .normal)
            tintColor = KBTheme.subtext
        }
    }
}

// MARK: - Keyboard Controller

class KeyboardViewController: UIInputViewController {

    // ── Top bar ──
    private let topBar        = UIStackView()
    private let logoView      = UIImageView()
    private let titleStack    = UIStackView()
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let nextKBButton  = UIButton(type: .system)

    // ── Mode selector (horizontal pills) ──
    private let modeSelectorScrollView = UIScrollView()
    private let modeSelectorStack      = UIStackView()
    private var modePillButtons: [ModePillButton] = []

    // ── Empty state ──
    private let emptyStateView = UIView()
    private let emptyIconView  = UIImageView()
    private let emptyLabel     = UILabel()
    private let generateButton = UIButton(type: .system)
    private let statusLabel    = UILabel()

    // ── Replies state ──
    private let repliesView         = UIView()
    private let scrollView          = UIScrollView()
    private let repliesStack        = UIStackView()
    private let regenerateButton    = UIButton(type: .system)

    // ── Locked (not logged in) state ──
    private let lockedOverlay    = UIView()
    private let lockedIconView   = UIImageView()
    private let lockedTitleLabel = UILabel()
    private let lockedHintLabel  = UILabel()
    private var isUserLoggedIn   = false

    // ── State ──
    private var modes: [KBGenerationMode] = []
    private var selectedModeIndex: Int = 0

    private var selectedMode: KBGenerationMode {
        guard selectedModeIndex < modes.count else {
            return KBModeStore.builtInDefaults().first!
        }
        return modes[selectedModeIndex]
    }

    // MARK: - Auth check

    private func checkAuth() -> Bool {
        // No App Group — keyboard is always accessible.
        // API key is on the backend, not in the app.
        return true
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        isUserLoggedIn = checkAuth()
        loadModes()
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isUserLoggedIn = checkAuth()
        reapplyTheme()
        loadModes()          // pick up mode changes from main app

        if isUserLoggedIn {
            lockedOverlay.isHidden = true
            modeSelectorScrollView.isHidden = false
            refreshEmptyState()
        } else {
            lockedOverlay.isHidden = false
            modeSelectorScrollView.isHidden = true
            emptyStateView.isHidden = true
            repliesView.isHidden = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isUserLoggedIn {
            updateFullAccessState()
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        if selectedMode.inputSource == .clipboard {
            refreshEmptyState()
        }
    }

    // MARK: - Modes

    private func loadModes() {
        modes = KBModeStore.loadModes()
        if selectedModeIndex >= modes.count { selectedModeIndex = 0 }
        rebuildModePills()
    }

    private func selectMode(at index: Int) {
        selectedModeIndex = index
        modePillButtons.enumerated().forEach { i, btn in btn.setSelected(i == index) }
        // Go back to empty state when switching modes
        showEmptyState()
        refreshEmptyState()
    }

    // MARK: - Build UI

    private func buildUI() {
        guard let root = inputView else { return }
        root.backgroundColor = KBTheme.bg
        root.allowsSelfSizing = true

        let hc = root.heightAnchor.constraint(equalToConstant: 280)
        hc.priority = UILayoutPriority(999)
        hc.isActive = true

        setupTopBar(root: root)
        setupModeSelector(root: root)
        setupEmptyStateView(root: root)
        setupRepliesView(root: root)
        setupLockedOverlay(root: root)

        if isUserLoggedIn {
            emptyStateView.isHidden = false
            repliesView.isHidden    = true
            lockedOverlay.isHidden  = true
        } else {
            emptyStateView.isHidden = true
            repliesView.isHidden    = true
            lockedOverlay.isHidden  = false
            modeSelectorScrollView.isHidden = true
        }
    }

    // MARK: Locked Overlay (not logged in)

    private func setupLockedOverlay(root: UIView) {
        lockedOverlay.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let lockIcon = UIImage(systemName: "lock.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .light))
        lockedIconView.image       = lockIcon
        lockedIconView.tintColor   = KBTheme.accent.withAlphaComponent(0.5)
        lockedIconView.contentMode = .scaleAspectFit
        lockedIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockedIconView.widthAnchor.constraint(equalToConstant: 30),
            lockedIconView.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Title
        lockedTitleLabel.text          = "Sign in to SayThis"
        lockedTitleLabel.font          = .systemFont(ofSize: 14, weight: .semibold)
        lockedTitleLabel.textColor     = KBTheme.text
        lockedTitleLabel.textAlignment = .center

        // Hint
        lockedHintLabel.text          = "Open the SayThis app and sign in to use the keyboard."
        lockedHintLabel.font          = .systemFont(ofSize: 11.5)
        lockedHintLabel.textColor     = KBTheme.subtext
        lockedHintLabel.textAlignment = .center
        lockedHintLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [lockedIconView, lockedTitleLabel, lockedHintLabel])
        stack.axis      = .vertical
        stack.spacing   = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        lockedOverlay.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: lockedOverlay.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: lockedOverlay.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: lockedOverlay.trailingAnchor, constant: -24)
        ])

        root.addSubview(lockedOverlay)
        NSLayoutConstraint.activate([
            lockedOverlay.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 4),
            lockedOverlay.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            lockedOverlay.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            lockedOverlay.trailingAnchor.constraint(equalTo: root.trailingAnchor)
        ])
    }

    // MARK: Top Bar

    private func setupTopBar(root: UIView) {
        topBar.axis      = .horizontal
        topBar.alignment = .center
        topBar.spacing   = 8

        let bundle = Bundle(for: KeyboardViewController.self)
        logoView.image = UIImage(named: KBTheme.logoImageName, in: bundle, compatibleWith: nil)
            ?? UIImage(named: "persuadeKeyboardLogo", in: bundle, compatibleWith: nil)
        logoView.contentMode = .scaleAspectFit
        logoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 24),
            logoView.heightAnchor.constraint(equalToConstant: 24)
        ])

        titleLabel.text      = "SayThis"
        titleLabel.font      = .systemFont(ofSize: 12.5, weight: .bold)
        titleLabel.textColor = KBTheme.text

        subtitleLabel.text      = "Say the right thing."
        subtitleLabel.font      = .systemFont(ofSize: 9)
        subtitleLabel.textColor = KBTheme.subtext

        titleStack.axis    = .vertical
        titleStack.spacing = 1
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        nextKBButton.setImage(UIImage(systemName: "globe"), for: .normal)
        nextKBButton.tintColor = KBTheme.subtext
        nextKBButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nextKBButton.widthAnchor.constraint(equalToConstant: 30),
            nextKBButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        nextKBButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        topBar.addArrangedSubview(logoView)
        topBar.addArrangedSubview(titleStack)
        topBar.addArrangedSubview(spacer)
        topBar.addArrangedSubview(nextKBButton)

        topBar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            topBar.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    // MARK: Mode Selector

    private func setupModeSelector(root: UIView) {
        modeSelectorScrollView.showsHorizontalScrollIndicator = false
        modeSelectorScrollView.showsVerticalScrollIndicator   = false
        modeSelectorScrollView.alwaysBounceHorizontal         = true
        modeSelectorScrollView.translatesAutoresizingMaskIntoConstraints = false

        modeSelectorStack.axis      = .horizontal
        modeSelectorStack.spacing   = 6
        modeSelectorStack.alignment = .center
        modeSelectorStack.translatesAutoresizingMaskIntoConstraints = false
        modeSelectorScrollView.addSubview(modeSelectorStack)

        NSLayoutConstraint.activate([
            modeSelectorStack.topAnchor.constraint(equalTo: modeSelectorScrollView.contentLayoutGuide.topAnchor),
            modeSelectorStack.bottomAnchor.constraint(equalTo: modeSelectorScrollView.contentLayoutGuide.bottomAnchor),
            modeSelectorStack.leadingAnchor.constraint(equalTo: modeSelectorScrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            modeSelectorStack.trailingAnchor.constraint(equalTo: modeSelectorScrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            modeSelectorStack.heightAnchor.constraint(equalTo: modeSelectorScrollView.frameLayoutGuide.heightAnchor)
        ])

        root.addSubview(modeSelectorScrollView)
        NSLayoutConstraint.activate([
            modeSelectorScrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 6),
            modeSelectorScrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            modeSelectorScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            modeSelectorScrollView.heightAnchor.constraint(equalToConstant: 32)
        ])

        rebuildModePills()
    }

    private func rebuildModePills() {
        // Remove existing pills
        modePillButtons.forEach { $0.removeFromSuperview() }
        modeSelectorStack.arrangedSubviews.forEach {
            modeSelectorStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        modePillButtons.removeAll()

        for (i, mode) in modes.enumerated() {
            let pill = ModePillButton(mode: mode)
            pill.setSelected(i == selectedModeIndex)
            let idx = i
            pill.addAction(UIAction { [weak self] _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self?.selectMode(at: idx)
            }, for: .touchUpInside)
            modeSelectorStack.addArrangedSubview(pill)
            modePillButtons.append(pill)
        }
    }

    // MARK: Empty State

    private func setupEmptyStateView(root: UIView) {
        // Icon
        emptyIconView.contentMode = .scaleAspectFit
        emptyIconView.tintColor   = KBTheme.accent.withAlphaComponent(0.4)
        emptyIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyIconView.widthAnchor.constraint(equalToConstant: 24),
            emptyIconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Hint label
        emptyLabel.font          = .systemFont(ofSize: 12)
        emptyLabel.textColor     = KBTheme.subtext
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 2

        // Status label (errors / hints)
        statusLabel.font          = .systemFont(ofSize: 10.5)
        statusLabel.textColor     = KBTheme.subtext
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        // Generate button
        styleGenerateButton(generating: false)
        generateButton.addTarget(self, action: #selector(onGenerate), for: .touchUpInside)

        // Centre stack
        let centreStack = UIStackView(arrangedSubviews: [emptyIconView, emptyLabel, statusLabel, generateButton])
        centreStack.axis      = .vertical
        centreStack.spacing   = 8
        centreStack.alignment = .center
        centreStack.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(centreStack)

        NSLayoutConstraint.activate([
            centreStack.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            centreStack.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 12),
            centreStack.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -12),
            generateButton.widthAnchor.constraint(equalTo: centreStack.widthAnchor)
        ])

        root.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: modeSelectorScrollView.bottomAnchor, constant: 2),
            emptyStateView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -6),
            emptyStateView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            emptyStateView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12)
        ])

        refreshEmptyState()
    }

    private func refreshEmptyState() {
        let mode = selectedMode
        let icon = UIImage(systemName: mode.icon,
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .light))
        emptyIconView.image = icon

        switch mode.inputSource {
        case .clipboard:
            let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            emptyLabel.text = clip.isEmpty
                ? "Copy a message, then tap \(mode.name)"
                : "Ready — tap \(mode.name)"

        case .textField:
            let typed = textDocumentProxy.documentContextBeforeInput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            emptyLabel.text = typed.isEmpty
                ? "Type your message first, then tap \(mode.name)"
                : "Ready — tap \(mode.name)"
        }

        styleGenerateButton(generating: false)
    }

    // MARK: Replies View

    private func setupRepliesView(root: UIView) {
        repliesStack.axis    = .vertical
        repliesStack.spacing = 8
        repliesStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(repliesStack)
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            repliesStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            repliesStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            repliesStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            repliesStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            repliesStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Regenerate button — minimal, secondary style
        styleRegenerateButton(generating: false)
        regenerateButton.addTarget(self, action: #selector(onRegenerate), for: .touchUpInside)

        repliesView.translatesAutoresizingMaskIntoConstraints = false
        repliesView.addSubview(scrollView)
        repliesView.addSubview(regenerateButton)

        NSLayoutConstraint.activate([
            regenerateButton.bottomAnchor.constraint(equalTo: repliesView.bottomAnchor),
            regenerateButton.leadingAnchor.constraint(equalTo: repliesView.leadingAnchor),
            regenerateButton.trailingAnchor.constraint(equalTo: repliesView.trailingAnchor),
            regenerateButton.heightAnchor.constraint(equalToConstant: 36),

            scrollView.topAnchor.constraint(equalTo: repliesView.topAnchor, constant: 2),
            scrollView.bottomAnchor.constraint(equalTo: regenerateButton.topAnchor, constant: -6),
            scrollView.leadingAnchor.constraint(equalTo: repliesView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: repliesView.trailingAnchor)
        ])

        root.addSubview(repliesView)
        NSLayoutConstraint.activate([
            repliesView.topAnchor.constraint(equalTo: modeSelectorScrollView.bottomAnchor, constant: 4),
            repliesView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -6),
            repliesView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            repliesView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12)
        ])
    }

    // MARK: - Button Styling

    private func styleGenerateButton(generating: Bool) {
        let mode = selectedMode
        let title = generating ? "Generating…" : mode.name
        let icon  = generating ? "ellipsis" : mode.icon

        generateButton.setTitle("  \(title)", for: .normal)
        generateButton.setImage(
            UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)),
            for: .normal
        )
        generateButton.tintColor       = .black
        generateButton.backgroundColor = generating ? KBTheme.accent.withAlphaComponent(0.55) : KBTheme.accent
        generateButton.setTitleColor(.black, for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .semibold)
        generateButton.layer.cornerRadius = 11
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.heightAnchor.constraint(equalToConstant: 38).isActive = false
        if generateButton.constraints.filter({ $0.firstAttribute == .height }).isEmpty {
            generateButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
        }
    }

    private func styleRegenerateButton(generating: Bool) {
        let mode = selectedMode
        let title = generating ? "Regenerating…" : "Regenerate"
        regenerateButton.setTitle(title, for: .normal)
        regenerateButton.setImage(
            UIImage(systemName: "arrow.clockwise", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)),
            for: .normal
        )
        regenerateButton.tintColor       = KBTheme.accent
        regenerateButton.backgroundColor = KBTheme.accent.withAlphaComponent(0.08)
        regenerateButton.setTitleColor(KBTheme.accent, for: .normal)
        regenerateButton.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        regenerateButton.layer.cornerRadius = 10
        regenerateButton.semanticContentAttribute = .forceRightToLeft
        regenerateButton.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Re-apply Theme

    private func reapplyTheme() {
        guard let root = inputView else { return }
        root.backgroundColor = KBTheme.bg
        generateButton.backgroundColor   = KBTheme.accent
        regenerateButton.tintColor       = KBTheme.accent
        regenerateButton.backgroundColor = KBTheme.accent.withAlphaComponent(0.08)
        regenerateButton.setTitleColor(KBTheme.accent, for: .normal)
        nextKBButton.tintColor = KBTheme.subtext
        emptyIconView.tintColor = KBTheme.accent.withAlphaComponent(0.4)

        let bundle = Bundle(for: KeyboardViewController.self)
        logoView.image = UIImage(named: KBTheme.logoImageName, in: bundle, compatibleWith: nil)
            ?? UIImage(named: "persuadeKeyboardLogo", in: bundle, compatibleWith: nil)

        // Refresh pill colours
        modePillButtons.enumerated().forEach { i, btn in btn.setSelected(i == selectedModeIndex) }
    }

    // MARK: - Full Access

    private func updateFullAccessState() {
        let full = hasFullAccess
        generateButton.isEnabled = full
        generateButton.alpha     = full ? 1.0 : 0.4

        if !full {
            emptyLabel.text      = "Enable Full Access in Settings › Keyboards › SayThis"
            emptyLabel.textColor = KBTheme.danger
            statusLabel.text     = ""
        } else {
            emptyLabel.textColor = KBTheme.subtext
            refreshEmptyState()
        }
    }

    // MARK: - Generate

    @objc private func onGenerate() {
        let mode  = selectedMode
        let input = resolveInput(for: mode)

        guard let text = input, !text.isEmpty else {
            let hint = mode.inputSource == .clipboard
                ? "Copy a message first, then tap \(mode.name)."
                : "Type your message first, then tap \(mode.name)."
            statusLabel.text      = hint
            statusLabel.textColor = KBTheme.danger
            return
        }

        statusLabel.text = ""
        generateButton.isEnabled = false
        styleGenerateButton(generating: true)

        OpenAIClient.shared.generateReplies(
            from: buildUserMessage(input: text, mode: mode),
            systemPrompt: mode.effectiveSystemPrompt
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.generateButton.isEnabled = true
                self.styleGenerateButton(generating: false)

                switch result {
                case .success(let replies):
                    self.renderReplies(replies)
                case .failure(let error):
                    self.statusLabel.text      = error.localizedDescription
                    self.statusLabel.textColor = KBTheme.danger
                }
            }
        }
    }

    // MARK: - Regenerate

    @objc private func onRegenerate() {
        let mode  = selectedMode
        let input = resolveInput(for: mode)
        guard let text = input, !text.isEmpty else { return }

        regenerateButton.isEnabled = false
        styleRegenerateButton(generating: true)

        OpenAIClient.shared.generateReplies(
            from: buildUserMessage(input: text, mode: mode),
            systemPrompt: mode.effectiveSystemPrompt
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.regenerateButton.isEnabled = true
                self.styleRegenerateButton(generating: false)

                switch result {
                case .success(let replies):
                    self.renderReplies(replies)
                case .failure:
                    self.showEmptyState()
                }
            }
        }
    }

    // MARK: - Input resolution

    private func resolveInput(for mode: KBGenerationMode) -> String? {
        switch mode.inputSource {
        case .clipboard:
            let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return clip.isEmpty ? nil : clip
        case .textField:
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let after  = textDocumentProxy.documentContextAfterInput  ?? ""
            let full   = (before + after).trimmingCharacters(in: .whitespacesAndNewlines)
            return full.isEmpty ? nil : full
        }
    }

    private func buildUserMessage(input: String, mode: KBGenerationMode) -> String {
        switch mode.inputSource {
        case .clipboard:
            return "Generate suggestions for this message:\n\n\(input)"
        case .textField:
            return "Improve this drafted message:\n\n\(input)"
        }
    }

    // MARK: - Render Replies

    private func renderReplies(_ replies: [String]) {
        clearReplies()
        let mode = selectedMode
        let primaryLabel = (mode.inputSource == .textField) ? "Replace" : "Insert"

        for reply in replies.prefix(5) {
            let card = ReplyCardView(text: reply, primaryLabel: primaryLabel)

            card.onInsert = { [weak self] in
                guard let self else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                if mode.inputSource == .textField {
                    // Replace existing text
                    self.replaceDocumentText(with: reply)
                } else {
                    self.textDocumentProxy.insertText(reply)
                }
            }

            card.onCopy = {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIPasteboard.general.string = reply
            }

            repliesStack.addArrangedSubview(card)
        }

        emptyStateView.isHidden = true
        repliesView.isHidden    = false
    }

    /// Replace all text in the document context with `newText`
    private func replaceDocumentText(with newText: String) {
        // Move cursor to end of document
        if let after = textDocumentProxy.documentContextAfterInput, !after.isEmpty {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: after.count)
        }
        // Delete all text before cursor
        if let before = textDocumentProxy.documentContextBeforeInput, !before.isEmpty {
            for _ in 0..<before.count {
                textDocumentProxy.deleteBackward()
            }
        }
        // Insert new text
        textDocumentProxy.insertText(newText)
    }

    private func clearReplies() {
        repliesStack.arrangedSubviews.forEach {
            repliesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func showEmptyState() {
        clearReplies()
        emptyStateView.isHidden = false
        repliesView.isHidden    = true
        refreshEmptyState()
    }
}
