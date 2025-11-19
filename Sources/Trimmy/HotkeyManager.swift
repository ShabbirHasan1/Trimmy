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
    private var failureAlertShown = false

    var hasClipboardText: Bool {
        self.monitor.clipboardText() != nil
    }

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
        guard KeySender.ensureAccessibility() else {
            Telemetry.accessibility
                .error(
                    "Accessibility not trusted; prompt should have been shown. bundle=\(Bundle.main.bundleIdentifier ?? "nil", privacy: .public) exec=\(Bundle.main.executableURL?.path ?? "nil", privacy: .public)")
            NSSound.beep()
            self.presentAccessibilityHelp()
            return false
        }

        guard let rawClipboard = self.monitor.clipboardText() else {
            Telemetry.hotkey.notice("Clipboard empty or unavailable.")
            NSSound.beep()
            return false
        }

        let textToType = self.monitor.trimmedClipboardText(force: true) ?? rawClipboard

        let lineCount = textToType.split(whereSeparator: { $0.isNewline }).count
        if lineCount > 20 {
            let proceed = self.confirmLargePaste(lineCount: lineCount, preview: textToType)
            if !proceed { return false }
        }

        return self.sender.type(text: textToType)
    }

    private func confirmLargePaste(lineCount: Int, preview: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Type \(lineCount) lines?"
        alert.informativeText = "You’re about to type \(lineCount) lines. Preview below."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Type All")
        alert.addButton(withTitle: "Cancel")

        let previewText = Self.previewSnippet(for: preview)
        let textView = NSTextView(frame: .zero)
        textView.string = previewText
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 120))
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 120).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 360).isActive = true

        alert.accessoryView = scroll

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentAccessibilityHelp() {
        guard !self.failureAlertShown else { return }
        self.failureAlertShown = true
        let alert = NSAlert()
        alert.messageText = "Allow Trimmy in Accessibility"
        alert.informativeText = """
        Trimmy needs Accessibility/Input Monitoring permission to type on your behalf.
        Open System Settings → Privacy & Security → Accessibility, add Trimmy, and enable it. Then retry the hotkey.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
        }
    }

    private static func previewSnippet(for text: String) -> String {
        let lines = text.split(whereSeparator: { $0.isNewline }).map(String.init)
        let snippetLines = lines.prefix(5)
        var snippet = snippetLines.joined(separator: "\n")
        if snippet.count > 400 {
            snippet = String(snippet.prefix(400)) + "…"
        }
        return snippet
    }
}
