import AppKit
import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let typeTrimmed = Self("typeTrimmed")
}

@MainActor
final class HotkeyManager: ObservableObject {
    private let settings: AppSettings
    private let monitor: ClipboardMonitor
    private let sender = KeySender()
    private var handlerRegistered = false

    init(settings: AppSettings, monitor: ClipboardMonitor) {
        self.settings = settings
        self.monitor = monitor
        self.settings.hotkeyEnabledChanged = { [weak self] _ in
            self?.refreshRegistration()
        }
        self.ensureDefaultShortcut()
        self.registerHandlerIfNeeded()
        self.refreshRegistration()
    }

    func refreshRegistration() {
        self.registerHandlerIfNeeded()
        if self.settings.hotkeyEnabled {
            KeyboardShortcuts.enable(.typeTrimmed)
        } else {
            KeyboardShortcuts.disable(.typeTrimmed)
        }
    }

    @discardableResult
    func typeTrimmedTextNow() -> Bool {
        self.handleHotkey()
    }

    private func registerHandlerIfNeeded() {
        guard !self.handlerRegistered else { return }
        KeyboardShortcuts.onKeyUp(for: .typeTrimmed) { [weak self] in
            self?.handleHotkey()
        }
        self.handlerRegistered = true
    }

    private func ensureDefaultShortcut() {
        if KeyboardShortcuts.getShortcut(for: .typeTrimmed) == nil {
            KeyboardShortcuts.setShortcut(
                .init(.v, modifiers: [.command, .option, .control]),
                for: .typeTrimmed)
        }
    }

    @discardableResult
    private func handleHotkey() -> Bool {
        guard let trimmed = self.monitor.trimmedClipboardText(force: true) else {
            NSSound.beep()
            return false
        }

        guard KeySender.ensureAccessibility() else {
            NSSound.beep()
            return false
        }

        return self.sender.type(text: trimmed)
    }
}
