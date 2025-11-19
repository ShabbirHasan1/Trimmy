import Testing
@testable import Trimmy

@MainActor
@Suite
struct HotkeyManagerPreviewTests {
    private let manager: HotkeyManager = {
        let settings = AppSettings()
        let monitor = ClipboardMonitor(settings: settings)
        return HotkeyManager(settings: settings, monitor: monitor)
    }()

    @Test
    func previewReturnsPlaceholderWhenEmpty() {
        #expect(HotkeyManager.previewSnippet(for: "") == "(preview is empty)")
    }

    @Test
    func previewTruncatesAt50kChars() {
        let text = String(repeating: "a", count: 60000)
        let snippet = HotkeyManager.previewSnippet(for: text)
        #expect(snippet.count == 50001) // 50_000 chars + ellipsis
        #expect(snippet.hasSuffix("…"))
    }

    @Test
    func previewLimitsTo1000Lines() {
        let lines = Array(repeating: "line", count: 1500).joined(separator: "\n")
        let snippet = HotkeyManager.previewSnippet(for: lines)
        #expect(snippet.split(whereSeparator: { $0.isNewline }).count == 1000)
    }
}
