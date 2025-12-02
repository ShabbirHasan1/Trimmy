import Foundation

enum CLIAggressiveness: String { case low, normal, high }

struct CLISettings {
    var aggressiveness: CLIAggressiveness = .normal
    var preserveBlankLines: Bool = false
    var removeBoxDrawing: Bool = true
}

struct CLITrimResult { let original: String; let trimmed: String; let transformed: Bool }

@main
struct TrimmyCLI {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        var force = false
        var inputPath: String?
        var json = false
        var settings = CLISettings()

        var idx = 0
        while idx < args.count {
            switch args[idx] {
            case "--trim":
                if idx + 1 < args.count, !args[idx + 1].hasPrefix("--") {
                    inputPath = args[idx + 1]; idx += 1
                }
            case "--force", "-f":
                force = true
            case "--json":
                json = true
            case "--aggressiveness":
                if idx + 1 < args.count, let aggr = CLIAggressiveness(rawValue: args[idx + 1].lowercased()) {
                    settings.aggressiveness = aggr; idx += 1
                }
            case "--preserve-blank-lines":
                settings.preserveBlankLines = true
            case "--no-preserve-blank-lines":
                settings.preserveBlankLines = false
            case "--remove-box-drawing":
                settings.removeBoxDrawing = true
            case "--keep-box-drawing":
                settings.removeBoxDrawing = false
            case "--help", "-h":
                self.printHelp(); return
            default: break
            }
            idx += 1
        }

        guard let input = readInput(path: inputPath) else {
            fputs("No input provided. Use --trim <file> or pipe to stdin.\n", stderr)
            exit(1)
        }

        let result = cliTrim(input, settings: settings, force: force)

        if json {
            let payload: [String: Any] = [
                "original": result.original,
                "trimmed": result.trimmed,
                "transformed": result.transformed,
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data([0x0A]))
            } catch {
                fputs("Failed to encode JSON: \(error)\n", stderr)
                exit(3)
            }
        } else {
            FileHandle.standardOutput.write(result.trimmed.data(using: String.Encoding.utf8) ?? Data())
            FileHandle.standardOutput.write(Data([0x0A]))
        }

        exit(result.transformed ? 0 : 2)
    }

    private static func readInput(path: String?) -> String? {
        if let path, !path.isEmpty {
            return try? String(contentsOfFile: path, encoding: .utf8)
        }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func printHelp() {
        let help = """
        TrimmyCLI – headless trimmer

        Usage:
          trimmycli --trim [file] [options]    Trim input from file or stdin.

        Options:
          --trim <file>              Input file (optional; stdin if omitted)
          --force, -f                Force High aggressiveness
          --aggressiveness <level>   low | normal | high
          --preserve-blank-lines     Keep blank lines when flattening
          --no-preserve-blank-lines  Remove blank lines
          --remove-box-drawing       Strip box-drawing characters (default true)
          --keep-box-drawing         Disable box-drawing removal
          --json                     Emit JSON {original, trimmed, transformed}
          --help, -h                 Show help

        Exit codes:
          0  trimmed (or unchanged if no transformations needed and force not requested)
          1  no input / error reading
          2  no transformation applied (for callers who need to detect changes)
        """
        print(help)
    }
}

// MARK: - Trimming pipeline (standalone, mirrors app heuristics)

func cliTrim(_ text: String, settings: CLISettings, force: Bool) -> CLITrimResult {
    var current = text
    var transformed = false

    if settings.removeBoxDrawing, let cleaned = cleanBoxDrawing(current) {
        current = cleaned; transformed = true
    }

    if let stripped = stripPromptPrefixes(current) {
        current = stripped; transformed = true
    }

    if let repairedURL = repairWrappedURL(current) {
        current = repairedURL; transformed = true
    }

    let override = force ? CLIAggressiveness.high : settings.aggressiveness
    if let command = transformIfCommand(
        current,
        aggressiveness: override,
        preserveBlankLines: settings.preserveBlankLines)
    {
        current = command; transformed = true
    }

    return CLITrimResult(original: text, trimmed: current, transformed: transformed)
}

private func cleanBoxDrawing(_ text: String) -> String? {
    let pattern = #"[\u2500-\u257F\u2580-\u259F]+"#
    let cleaned = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
    return cleaned == text ? nil : cleaned
}

private func stripPromptPrefixes(_ text: String) -> String? {
    var lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    var changed = false
    for idx in lines.indices {
        let line = lines[idx]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("$") || trimmed.hasPrefix("#") else { continue }
        let dropped = trimmed.dropFirst().drop { $0.isWhitespace }
        guard !dropped.isEmpty else { continue }
        lines[idx] = Substring(dropped)
        changed = true
    }
    guard changed else { return nil }
    return lines.joined(separator: "\n")
}

private func repairWrappedURL(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = trimmed.lowercased()
    let schemeCount = (lower.components(separatedBy: "https://").count - 1) +
        (lower.components(separatedBy: "http://").count - 1)
    guard schemeCount == 1 else { return nil }
    guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return nil }

    let collapsed = trimmed.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    guard collapsed != trimmed else { return nil }
    let valid = #"^https?://[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+$"#
    guard collapsed.range(of: valid, options: .regularExpression) != nil else { return nil }
    return collapsed
}

private func transformIfCommand(
    _ text: String,
    aggressiveness: CLIAggressiveness,
    preserveBlankLines: Bool) -> String?
{
    guard text.contains("\n") else { return nil }
    let lines = text.split(whereSeparator: { $0.isNewline })
    guard lines.count >= 2 else { return nil }
    if lines.count > 10 { return nil }

    let strongSignals = text.contains("\\\n")
        || text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil
        || text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil
        || text.range(of: #"[A-Za-z0-9._~-]+/[A-Za-z0-9._~-]+"#, options: .regularExpression) != nil

    let looksLikeCode = isLikelySourceCode(text)
    if aggressiveness != .high, looksLikeCode, !strongSignals { return nil }

    var score = 0
    if text.contains("\\\n") { score += 1 }
    if text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil { score += 1 }
    if text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil { score += 1 }
    if lines.allSatisfy(isLikelyCommandLine(_:)) { score += 1 }
    if text.range(of: #"(?m)^\s*(sudo\s+)?[A-Za-z0-9./~_-]+"#, options: .regularExpression) != nil { score += 1 }

    let threshold = switch aggressiveness {
    case .low: 3
    case .normal: 2
    case .high: 1
    }
    guard score >= threshold else { return nil }

    return flatten(text, preserveBlankLines: preserveBlankLines)
}

private func isLikelyCommandLine(_ lineSubstr: Substring) -> Bool {
    let line = lineSubstr.trimmingCharacters(in: .whitespaces)
    guard !line.isEmpty else { return false }
    if line.last == "." { return false }
    let pattern = #"^(sudo\s+)?[A-Za-z0-9./~_-]+(?:\s+|\z)"#
    return line.range(of: pattern, options: .regularExpression) != nil
}

private func isLikelySourceCode(_ text: String) -> Bool {
    let hasBraces = text.contains("{") || text.contains("}") || text.lowercased().contains("begin")
    let keywordPattern = #"(?m)^\s*(import|package|namespace|using|template|class|struct|enum|"#
        + #"extension|protocol|interface|func|def|fn|let|var|public|private|internal|"#
        + #"open|protected|if|for|while)\b"#
    let hasKeywords = text.range(of: keywordPattern, options: .regularExpression) != nil
    return hasBraces && hasKeywords
}

private func flatten(_ text: String, preserveBlankLines: Bool) -> String {
    let placeholder = "__BLANK_SEP__"
    var result = text
    if preserveBlankLines {
        result = result.replacingOccurrences(of: "\n\\s*\n", with: placeholder, options: .regularExpression)
    }

    let lines = result.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline })
    let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
    result = trimmedLines.joined(separator: " ")
    result = result.replacingOccurrences(of: #"\\\s*\n\s*"#, with: " ", options: .regularExpression)
    result = result.replacingOccurrences(of: "\n", with: " ")
    result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

    if preserveBlankLines {
        result = result.replacingOccurrences(of: placeholder, with: "\n\n")
    }

    return result.trimmingCharacters(in: .whitespaces)
}
