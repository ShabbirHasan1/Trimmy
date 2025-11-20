import AppKit
import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let trimClipboard = Self("trimClipboard")
}

@MainActor
final class HotkeyManager: ObservableObject {
    private let settings: AppSettings
    private let monitor: ClipboardMonitor
    private var handlerRegistered = false

    init(settings: AppSettings, monitor: ClipboardMonitor) {
        self.settings = settings
        self.monitor = monitor
        self.settings.trimHotkeyEnabledChanged = { [weak self] _ in
            self?.refreshRegistration()
        }
        self.ensureDefaultShortcut()
        self.registerHandlerIfNeeded()
        self.refreshRegistration()
    }

    func refreshRegistration() {
        self.registerHandlerIfNeeded()
        if self.settings.trimHotkeyEnabled {
            KeyboardShortcuts.enable(.trimClipboard)
        } else {
            KeyboardShortcuts.disable(.trimClipboard)
        }
    }

    @discardableResult
    func trimClipboardNow() -> Bool {
        self.handleTrimClipboardHotkey()
    }

    private func registerHandlerIfNeeded() {
        guard !self.handlerRegistered else { return }
        KeyboardShortcuts.onKeyUp(for: .trimClipboard) { [weak self] in
            self?.handleTrimClipboardHotkey()
        }
        self.handlerRegistered = true
    }

    private func ensureDefaultShortcut() {
        if KeyboardShortcuts.getShortcut(for: .trimClipboard) == nil {
            KeyboardShortcuts.setShortcut(
                .init(.t, modifiers: [.command, .option]),
                for: .trimClipboard)
        }
    }

    @discardableResult
    private func handleTrimClipboardHotkey() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let didTrim = self.monitor.trimClipboardIfNeeded(force: true)
        if !didTrim {
            self.monitor.lastSummary = "Clipboard not trimmed (nothing command-like detected)."
        }
        return didTrim
    }
}
