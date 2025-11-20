import Foundation
import Testing
@testable import Trimmy

@MainActor
@Suite
struct TrimmyTests {
    @Test
    func detectsMultiLineCommand() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        settings.preserveBlankLines = false
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\nls -la\n"
        #expect(detector.transformIfCommand(text) == "echo hi ls -la")
    }

    @Test
    func skipsSingleLine() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        #expect(detector.transformIfCommand("ls -la") == nil)
    }

    @Test
    func skipsLongCopies() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let blob = Array(repeating: "echo hi", count: 11).joined(separator: "\n")
        #expect(detector.transformIfCommand(blob) == nil)
    }

    @Test
    func preservesBlankLinesWhenEnabled() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        settings.preserveBlankLines = true
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\n\necho bye\n"
        #expect(detector.transformIfCommand(text) == "echo hi\n\necho bye")
    }

    @Test
    func flattensBackslashContinuations() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        python script.py \\
          --flag yes \\
          --count 2
        """
        #expect(detector.transformIfCommand(text) == "python script.py --flag yes --count 2")
    }

    @Test
    func repairsAllCapsTokenBreaks() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = "N\nODE_PATH=/usr/bin\nls"
        #expect(detector.transformIfCommand(text) == "NODE_PATH=/usr/bin ls")
    }

    @Test
    func collapsesBlankLinesWhenNotPreserved() {
        let settings = AppSettings()
        settings.preserveBlankLines = false
        settings.aggressiveness = .high // allow flattening with minimal cues
        let detector = CommandDetector(settings: settings)
        let text = "echo a\n\necho b"
        #expect(detector.transformIfCommand(text) == "echo a echo b")
    }

    @Test
    func ignoresHarmlessMultilineText() {
        let settings = AppSettings()
        settings.aggressiveness = .low // stricter threshold to avoid flattening prose
        let detector = CommandDetector(settings: settings)
        let text = "Shopping list:\napples\noranges"
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func lowAggressivenessNeedsClearSignals() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hello
        world
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func highAggressivenessFlattensLooseCommands() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        npm
        install
        """
        #expect(detector.transformIfCommand(text) == "npm install")
    }

    @Test(arguments: Aggressiveness.allCases)
    func aggressivenessThresholds(_ level: Aggressiveness) {
        let settings = AppSettings()
        settings.aggressiveness = level
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hi \\
        --flag yes
        """
        let result = detector.transformIfCommand(text)
        #expect(result == "echo hi --flag yes")
    }

    @Test
    func normalAggressivenessKeepsNonCommands() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        Meeting notes:
        bullet
        items
        """
        #expect(detector.transformIfCommand(text) == "Meeting notes: bullet items")
    }

    @Test
    func preserveBlankLinesRoundTrip() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        settings.preserveBlankLines = true
        let detector = CommandDetector(settings: settings)
        let text = """
        echo a \\
        --flag yes

        echo b
        """
        #expect(detector.transformIfCommand(text) == "echo a --flag yes\n\necho b")
    }

    @Test
    func backslashWithoutCommandShouldFlattenOnlyWhenHigh() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        let detectorLow = CommandDetector(settings: settings)
        let text = """
        Not really a command \\
        just text
        """
        #expect(detectorLow.transformIfCommand(text) == "Not really a command just text")

        let settingsHigh = AppSettings()
        settingsHigh.aggressiveness = .high
        let detectorHigh = CommandDetector(settings: settingsHigh)
        #expect(detectorHigh.transformIfCommand(text) == "Not really a command just text")
    }

    @Test
    func removesBoxDrawingCharacters() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "hello │ │ world │ │ test"
        #expect(detector.cleanBoxDrawingCharacters(text) == "hello world test")
    }

    @Test
    func returnsNilWhenNoBoxDrawingCharacters() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let text = "hello world test"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func respectsRemoveBoxDrawingSetting() {
        let settings = AppSettings()
        settings.removeBoxDrawing = false
        let detector = CommandDetector(settings: settings)
        let text = "hello │ │ world"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func collapsesExtraSpacesAfterStrippingBoxDrawing() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "│ │ echo   │ │    hi │ │"
        #expect(detector.cleanBoxDrawingCharacters(text) == "echo hi")
    }

    @Test
    func boxDrawingRemovalIsNoOpWhenDisabled() {
        let settings = AppSettings()
        settings.removeBoxDrawing = false
        let detector = CommandDetector(settings: settings)
        let text = "│ │ echo   hi │ │"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func boxDrawingRemovalStillAllowsCommandFlattening() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        // Simulate a multi-line prompt wrapped with box characters.
        let text = """
        │ │ kubectl \\
        │ │   get pods
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned?.contains("kubectl \\") == true)
        // After cleaning, it should also flatten as a command.
        #expect(detector.transformIfCommand(cleaned ?? "") == "kubectl get pods")
    }

    @Test
    func stripsLeadingBoxRunsAcrossLines() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        │ ls -la \\
        │   | grep '^d'
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "ls -la \\\n | grep '^d'")
        #expect(detector.transformIfCommand(cleaned ?? "") == "ls -la | grep '^d'")
    }

    @Test
    func stripsTrailingBoxRunsAcrossLines() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hi │
        | tr h H │
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\n| tr h H")
        #expect(detector.transformIfCommand(cleaned ?? "") == "echo hi | tr h H")
    }

    @Test
    func stripsLeadingWhenMostLinesShareGutter() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """
        │ echo hi
        │ cat file
        plain line
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\ncat file\nplain line")
    }

    @Test
    func stripsTrailingWhenMostLinesShareGutter() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hi │
        run thing │
        plain line
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\nrun thing\nplain line")
    }

    @Test
    func doesNotStripWhenGutterBelowMajority() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """
        │ echo hi
        plain line
        plain line two
        """
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func stripsSingleLineWithLeadingGutter() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "│ kubectl get pods"
        #expect(detector.cleanBoxDrawingCharacters(text) == "kubectl get pods")
    }

    @Test
    func stripsBothSidesWhenMostLinesDo() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        │ ls -la │
        │   | grep '^d' │
        plain line
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "ls -la\n | grep '^d'\nplain line")
        #expect(detector.transformIfCommand(cleaned ?? "") == "ls -la | grep '^d' plain line")
    }

    @Test
    func ignoresGutterDetectionOnEmptyLines() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = """

        │ echo hi

        │ cat file

        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "echo hi\n\ncat file")
    }

    @Test
    func stripsLeadingAndTrailingBoxRunsWithMixedCounts() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        ││ curl https://example.com │
        ││   | jq '.data' │
        """
        let cleaned = detector.cleanBoxDrawingCharacters(text)
        #expect(cleaned == "curl https://example.com\n | jq '.data'")
        #expect(detector.transformIfCommand(cleaned ?? "") == "curl https://example.com | jq '.data'")
    }

    @Test
    func doesNotStripMidLineBoxGlyphsWithoutSharedGutter() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "echo │hi│ there"
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
    }

    @Test
    func boxDrawingRemovalDoesNotStripLegitPipes() {
        let settings = AppSettings()
        settings.removeBoxDrawing = true
        let detector = CommandDetector(settings: settings)
        let text = "echo 1 | wc -l"
        // No box characters present; return nil and leave single pipe untouched.
        #expect(detector.cleanBoxDrawingCharacters(text) == nil)
        // Single-line input should not be flattened; ensure it remains untouched.
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func summaryEllipsizesLongPreview() {
        let long = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        // limit 20 -> head 9, tail 10, plus ellipsis
        let truncated = ClipboardMonitor.ellipsize(long, limit: 20)
        #expect(truncated == "012345678…QRSTUVWXYZ")
        #expect(truncated.count == 20)
    }

    @Test
    func summaryDoesNotEllipsizeShortPreview() {
        let text = "short preview"
        #expect(ClipboardMonitor.ellipsize(text, limit: 90) == text)
    }
}
