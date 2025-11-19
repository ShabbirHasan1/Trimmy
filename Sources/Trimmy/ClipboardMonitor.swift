import AppKit
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    private let settings: AppSettings
    private let pasteboard = NSPasteboard.general
    private let trimmyMarker = NSPasteboard.PasteboardType("com.steipete.trimmy")
    private var timer: DispatchSourceTimer?
    private var lastSeenChangeCount: Int
    private var detector: CommandDetector { CommandDetector(settings: self.settings) }
    private let pollInterval: DispatchTimeInterval = .milliseconds(150)
    private let pollLeeway: DispatchTimeInterval = .milliseconds(50)
    private let graceDelay: DispatchTimeInterval = .milliseconds(80)

    @Published var lastSummary: String = ""

    init(settings: AppSettings) {
        self.settings = settings
        self.lastSeenChangeCount = self.pasteboard.changeCount
    }

    func start() {
        self.stop()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        t.schedule(deadline: .now(), repeating: self.pollInterval, leeway: self.pollLeeway)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        self.timer = t
    }

    func stop() {
        self.timer?.cancel()
        self.timer = nil
    }

    @discardableResult
    func trimClipboardIfNeeded(force: Bool = false) -> Bool {
        let changeCount = self.pasteboard.changeCount
        self.lastSeenChangeCount = changeCount

        guard let trimmed = self.trimmedClipboardText(force: force) else { return false }
        self.writeTrimmed(trimmed)
        self.lastSeenChangeCount = self.pasteboard.changeCount
        self.updateSummary(with: trimmed)
        return true
    }

    private func tick() {
        let current = self.pasteboard.changeCount
        guard current != self.lastSeenChangeCount else { return }

        let observed = current
        // Grace delay lets promised pasteboard data settle before we read/transform.
        DispatchQueue.main.asyncAfter(deadline: .now() + self.graceDelay) { [weak self] in
            guard let self, observed == self.pasteboard.changeCount else { return }
            _ = self.trimClipboardIfNeeded()
            self.lastSeenChangeCount = self.pasteboard.changeCount
        }
    }

    private func readTextFromPasteboard() -> String? {
        if self.pasteboard.types?.contains(self.trimmyMarker) == true { return nil }
        return self.pasteboard.string(forType: .string)
    }

    /// Exposes the current clipboard string (nil if empty or Trimmy marker).
    func clipboardText() -> String? {
        self.readTextFromPasteboard()
    }

    private func writeTrimmed(_ text: String) {
        self.pasteboard.declareTypes([.string, self.trimmyMarker], owner: nil)
        self.pasteboard.setString(text, forType: .string)
        self.pasteboard.setData(Data(), forType: self.trimmyMarker)
    }

    private func updateSummary(with text: String) {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        self.lastSummary = ClipboardMonitor.ellipsize(singleLine, limit: 90)
    }

    func trimmedClipboardText(force: Bool = false) -> String? {
        guard let text = self.readTextFromPasteboard() else { return nil }
        guard self.settings.autoTrimEnabled || force else { return nil }

        var currentText = text
        var wasTransformed = false

        if let cleaned = self.detector.cleanBoxDrawingCharacters(currentText) {
            currentText = cleaned
            wasTransformed = true
        }

        let overrideAggressiveness: Aggressiveness? = force ? .high : nil

        if let commandTransformed = self.detector.transformIfCommand(currentText, aggressivenessOverride: overrideAggressiveness) {
            currentText = commandTransformed
            wasTransformed = true
        } else if force {
            if !wasTransformed, !text.contains("\\\n"), !text.contains("\n") { return nil }
        } else if !wasTransformed {
            return nil
        }

        return currentText
    }

    static func ellipsize(_ text: String, limit: Int) -> String {
        guard limit >= 3, text.count > limit else { return text }
        let keep = limit - 1 // account for ellipsis
        let headCount = keep / 2
        let tailCount = keep - headCount
        let head = text.prefix(headCount)
        let tail = text.suffix(tailCount)
        return "\(head)…\(tail)"
    }
}
