import AppKit
import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let typeTrimmed = Self("typeTrimmed")
    static let trimClipboard = Self("trimClipboard")
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
        self.settings.trimHotkeyEnabledChanged = { [weak self] _ in
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

        if self.settings.trimHotkeyEnabled {
            KeyboardShortcuts.enable(.trimClipboard)
        } else {
            KeyboardShortcuts.disable(.trimClipboard)
        }
    }

    @discardableResult
    func typeTrimmedTextNow() -> Bool {
        self.handleHotkey()
    }

    @discardableResult
    func trimClipboardNow() -> Bool {
        self.handleTrimClipboardHotkey()
    }

    private func registerHandlerIfNeeded() {
        guard !self.handlerRegistered else { return }
        KeyboardShortcuts.onKeyUp(for: .typeTrimmed) { [weak self] in
            self?.handleHotkey()
        }
        KeyboardShortcuts.onKeyUp(for: .trimClipboard) { [weak self] in
            self?.handleTrimClipboardHotkey()
        }
        self.handlerRegistered = true
    }

    private func ensureDefaultShortcut() {
        if KeyboardShortcuts.getShortcut(for: .typeTrimmed) == nil {
            KeyboardShortcuts.setShortcut(
                .init(.v, modifiers: [.command, .option, .control]),
                for: .typeTrimmed)
        }

        if KeyboardShortcuts.getShortcut(for: .trimClipboard) == nil {
            KeyboardShortcuts.setShortcut(
                .init(.t, modifiers: [.command, .option]),
                for: .trimClipboard)
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

    @discardableResult
    private func handleTrimClipboardHotkey() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let didTrim = self.monitor.trimClipboardIfNeeded(force: true)
        if !didTrim {
            self.monitor.lastSummary = "Clipboard not trimmed (nothing command-like detected)."
        }
        return didTrim
    }

    private func confirmLargePaste(lineCount: Int, preview: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Type \(lineCount) lines?"
        alert.informativeText = "You’re about to type \(lineCount) lines."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Type All")
        alert.addButton(withTitle: "Cancel")

        let previewText = Self.previewSnippet(for: preview)
        let contentWidth: CGFloat = 360
        let contentHeight: CGFloat = 120

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
        textView.string = previewText
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.labelColor
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: contentHeight).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

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

    static func previewSnippet(for text: String) -> String {
        let lines = text.split(whereSeparator: { $0.isNewline }).map(String.init)
        let snippetLines = lines.prefix(1000)
        var snippet = snippetLines.joined(separator: "\n")
        if snippet.count > 50000 {
            snippet = String(snippet.prefix(50000)) + "…"
        }
        if snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "(preview is empty)"
        }
        return snippet
    }
}
