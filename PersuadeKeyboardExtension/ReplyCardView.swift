import UIKit

final class ReplyCardView: UIView {

    // ── Action callbacks ──
    var onInsert: (() -> Void)?   // "Insert" or "Replace"
    var onCopy:   (() -> Void)?

    // ── Subviews ──
    private let textLabel      = UILabel()
    private let actionButton   = UIButton(type: .system)
    private let copyButton     = UIButton(type: .system)

    // ── Config ──
    private let primaryLabel: String  // "Insert" or "Replace"

    init(text: String, primaryLabel: String = "Insert") {
        self.primaryLabel = primaryLabel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupCard()
        buildLabel(text)
        buildButtons()
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Card styling

    private func setupCard() {
        backgroundColor = KBTheme.card
        layer.cornerRadius = 14
        layer.masksToBounds = false
        // Subtle border via layer
        layer.borderWidth  = 0.5
        layer.borderColor  = UIColor.white.withAlphaComponent(0.06).cgColor
        // Soft shadow for depth
        layer.shadowColor   = UIColor.black.withAlphaComponent(0.25).cgColor
        layer.shadowOffset  = CGSize(width: 0, height: 2)
        layer.shadowRadius  = 6
        layer.shadowOpacity = 1
        layer.masksToBounds = false
    }

    // MARK: - Text label

    private func buildLabel(_ text: String) {
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text          = text
        textLabel.textColor     = UIColor.white.withAlphaComponent(0.92)
        textLabel.numberOfLines = 0
        textLabel.font          = .systemFont(ofSize: 14, weight: .regular)

        // Line height via paragraph style
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 3
        let attrStr = NSMutableAttributedString(string: text)
        attrStr.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: text.count))
        textLabel.attributedText = attrStr
    }

    // MARK: - Buttons

    private func buildButtons() {
        // Primary action button (Insert / Replace)
        styleButton(actionButton,
                    title: primaryLabel,
                    icon: primaryLabel == "Replace" ? "arrow.triangle.2.circlepath" : "arrow.up.forward",
                    filled: true)
        actionButton.addAction(UIAction { [weak self] _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self?.onInsert?()
        }, for: .touchUpInside)

        // Copy button — icon only, no label
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor       = KBTheme.subtext
        copyButton.backgroundColor = KBTheme.card2
        copyButton.layer.cornerRadius = 8
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        copyButton.heightAnchor.constraint(equalToConstant: 28).isActive = true

        copyButton.addAction(UIAction { [weak self] _ in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.onCopy?()
            // Brief checkmark feedback
            self?.copyButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
            self?.copyButton.tintColor = KBTheme.accent
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
                self?.copyButton.tintColor = KBTheme.subtext
            }
        }, for: .touchUpInside)
    }

    // MARK: - Layout

    private func buildLayout() {
        // Thin divider line between text and buttons
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        divider.translatesAutoresizingMaskIntoConstraints = false

        // Button row: action button (fills) + fixed copy button
        let buttonRow = UIStackView(arrangedSubviews: [actionButton, copyButton])
        buttonRow.axis         = .horizontal
        buttonRow.spacing      = 6
        buttonRow.alignment    = .center
        buttonRow.distribution = .fill
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textLabel)
        addSubview(divider)
        addSubview(buttonRow)

        NSLayoutConstraint.activate([
            // Text label
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            // Divider
            divider.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            // Button row
            buttonRow.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 9),
            buttonRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            buttonRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            buttonRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Button styling helper

    private func styleButton(_ button: UIButton, title: String, icon: String, filled: Bool) {
        var config = UIButton.Configuration.filled()
        config.title           = title
        config.image           = UIImage(systemName: icon,
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
        config.imagePadding    = 5
        config.imagePlacement  = .trailing
        config.contentInsets   = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.cornerStyle     = .capsule

        if filled {
            config.baseBackgroundColor = KBTheme.accent
            config.baseForegroundColor = .black
        } else {
            config.baseBackgroundColor = KBTheme.card2
            config.baseForegroundColor = KBTheme.text
        }

        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            return out
        }

        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }
}
