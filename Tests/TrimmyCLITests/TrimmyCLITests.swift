import Testing
@testable import TrimmyCLI

struct TrimmyCLITests {
    @Test
    func trimsMultilineCommand() {
        let input = """
        echo hi \\
        ls -la
        """
        let result = cliTrim(
            input,
            settings: CLISettings(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true),
            force: false)
        #expect(result.transformed)
        #expect(!result.trimmed.contains("\n"))
    }

    @Test
    func noChangeSingleLine() {
        let input = "single line"
        let result = cliTrim(input, settings: CLISettings(), force: false)
        #expect(result.transformed == false)
        #expect(result.trimmed == input)
    }

    @Test
    func removesBoxDrawing() {
        let input = "│ ls -la"
        let result = cliTrim(input, settings: CLISettings(removeBoxDrawing: true), force: false)
        #expect(result.transformed)
        #expect(!result.trimmed.contains("│"))
    }

    @Test
    func preservesBlankLinesWhenRequested() {
        let input = "a\n\nb"
        let result = cliTrim(input, settings: CLISettings(preserveBlankLines: true), force: false)
        #expect(result.trimmed.contains("\n\n"))
    }
}
