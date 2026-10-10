import AudioToolbox
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private let state = KeyboardState()
    private var hostingController: UIHostingController<KeyboardRootView>?
    private var heightConstraint: NSLayoutConstraint?
    private var lastShiftTap = Date.distantPast
    private let haptics = HapticFeedback()
    private var configurationObserver: ConfigurationChangeObserver?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Los ajustes solo se leían en `viewWillAppear`, que no se llama al volver a primer
        // plano con el teclado ya abierto, así que un cambio hecho en la app (p. ej. desactivar
        // la vibración) no se aplicaba. Se recargan también al reactivarse la app anfitriona
        // y en cuanto la app avisa de que guardó.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadConfiguration),
            name: .NSExtensionHostDidBecomeActive,
            object: nil
        )
        configurationObserver = ConfigurationChangeObserver { [weak self] in
            self?.reloadConfiguration()
        }

        let root = KeyboardRootView(state: state) { [weak self] action in
            self?.perform(action)
        }
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 16.4, *) {
            host.safeAreaRegions = []
        }

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let height = view.heightAnchor.constraint(equalToConstant: state.keyboardHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true

        hostingController = host
        heightConstraint = height
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        state.showingEmoji = false
        state.needsInputModeSwitchKey = needsInputModeSwitchKey
        reloadConfiguration()
        updateAutoCapitalization()
    }

    @objc private func reloadConfiguration() {
        state.reload()
        heightConstraint?.constant = state.keyboardHeight
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if state.needsInputModeSwitchKey != needsInputModeSwitchKey {
            state.needsInputModeSwitchKey = needsInputModeSwitchKey
            heightConstraint?.constant = state.keyboardHeight
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        updateAutoCapitalization()
    }

    // MARK: - Acciones

    func perform(_ action: KeyAction) {
        playFeedback()
        let proxy = textDocumentProxy

        switch action.type {
        case .character:
            guard !action.text.isEmpty else { break }
            let text = state.shift == .off ? action.text : action.text.uppercased()
            proxy.insertText(text)
            if state.shift == .on { state.shift = .off }
        case .space:
            proxy.insertText(" ")
        case .backspace:
            proxy.deleteBackward()
        case .deleteWord:
            deleteWordBackward()
        case .shift:
            toggleShift()
            return
        case .capsLock:
            state.shift = state.shift == .locked ? .off : .locked
            return
        case .returnKey:
            proxy.insertText("\n")
        case .tab:
            proxy.insertText("\t")
        case .dismissKeyboard:
            dismissKeyboard()
            return
        case .nextKeyboard:
            advanceToNextInputMode()
            return
        case .emoji:
            state.showingEmoji = true
            return
        case .paste:
            if hasFullAccess, let text = UIPasteboard.general.string, !text.isEmpty {
                proxy.insertText(text)
            }
        case .copy:
            if hasFullAccess, let text = proxy.selectedText, !text.isEmpty {
                UIPasteboard.general.string = text
            }
            return
        case .cut:
            if hasFullAccess, let text = proxy.selectedText, !text.isEmpty {
                UIPasteboard.general.string = text
                proxy.deleteBackward()
            }
        case .cursorLeft:
            proxy.adjustTextPosition(byCharacterOffset: -1)
        case .cursorRight:
            proxy.adjustTextPosition(byCharacterOffset: 1)
        case .none:
            return
        }

        updateAutoCapitalization()
    }

    private func toggleShift() {
        let now = Date()
        defer { lastShiftTap = now }

        if state.shift == .locked {
            state.shift = .off
        } else if now.timeIntervalSince(lastShiftTap) < 0.35 {
            state.shift = .locked
        } else {
            state.shift = state.shift == .off ? .on : .off
        }
    }

    private func deleteWordBackward() {
        let proxy = textDocumentProxy
        guard let before = proxy.documentContextBeforeInput, !before.isEmpty else {
            proxy.deleteBackward()
            return
        }

        var characters = Array(before)
        var count = 0
        while let last = characters.last, last.isWhitespace {
            characters.removeLast()
            count += 1
        }
        while let last = characters.last, !last.isWhitespace, !last.isPunctuation {
            characters.removeLast()
            count += 1
        }
        for _ in 0..<max(count, 1) {
            proxy.deleteBackward()
        }
    }

    private func updateAutoCapitalization() {
        guard state.settings.autoCapitalize, state.shift != .locked else { return }

        let proxy = textDocumentProxy
        let type = proxy.autocapitalizationType ?? .sentences
        let before = proxy.documentContextBeforeInput ?? ""
        let shouldCapitalize: Bool

        switch type {
        case .none:
            return
        case .allCharacters:
            shouldCapitalize = true
        case .words:
            shouldCapitalize = before.last.map { $0.isWhitespace } ?? true
        default:
            shouldCapitalize = Self.isStartOfSentence(before)
        }

        state.shift = shouldCapitalize ? .on : .off
    }

    private static func isStartOfSentence(_ text: String) -> Bool {
        guard let last = text.last else { return true }
        if last.isNewline { return true }
        guard last.isWhitespace else { return false }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let lastNonSpace = trimmed.last else { return true }
        return lastNonSpace.isNewline || ".!?".contains(lastNonSpace)
    }

    /// No espera a la vibración ni al sonido: ambos se reproducen en segundo plano.
    private func playFeedback() {
        let settings = state.settings
        guard settings.haptics || settings.keyClicks, hasFullAccess else { return }
        if settings.haptics {
            haptics.play(settings)
        }
        if settings.keyClicks {
            AudioServicesPlaySystemSound(1104)
        }
    }
}
