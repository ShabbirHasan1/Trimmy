import Foundation

private let boxDrawingCharacterClass = "[│┃╎╏┆┇┊┋╽╿￨｜]"

@MainActor
struct CommandDetector {
    let settings: AppSettings

    nonisolated static func stripBoxDrawingCharacters(in text: String) -> String? {
        var result = text

        // Legacy mid-line cleanup for paired gutters that show up as "│ │".
        if result.contains("│ │") {
            result = result.replacingOccurrences(of: "│ │", with: " ")
        }

        let lines = result.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !nonEmptyLines.isEmpty {
            let leadingPattern =
                #"^\s*\#(boxDrawingCharacterClass)+ ?"# // strip 1..n leading bars plus following space
            let trailingPattern =
                #" ?\#(boxDrawingCharacterClass)+\s*$"# // strip 1..n trailing bars plus preceding space
            let majorityThreshold = nonEmptyLines.count / 2 + 1 // strict majority

            let leadingMatches = nonEmptyLines.count(where: {
                $0.range(of: leadingPattern, options: .regularExpression) != nil
            })
            let trailingMatches = nonEmptyLines.count(where: {
                $0.range(of: trailingPattern, options: .regularExpression) != nil
            })

            let stripLeading = leadingMatches >= majorityThreshold
            let stripTrailing = trailingMatches >= majorityThreshold

            if stripLeading || stripTrailing {
                var rebuilt: [String] = []
                rebuilt.reserveCapacity(lines.count)

                for line in lines {
                    var lineStr = String(line)
                    if stripLeading {
                        lineStr = lineStr.replacingOccurrences(
                            of: leadingPattern,
                            with: "",
                            options: .regularExpression)
                    }
                    if stripTrailing {
                        lineStr = lineStr.replacingOccurrences(
                            of: trailingPattern,
                            with: "",
                            options: .regularExpression)
                    }
                    rebuilt.append(lineStr)
                }

                result = rebuilt.joined(separator: "\n")
            }
        }

        // Collapse any doubled spaces left behind after stripping the glyphs.
        let collapsed = result.replacingOccurrences(
            of: #" {2,}"#,
            with: " ",
            options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == text ? nil : trimmed
    }

    func cleanBoxDrawingCharacters(_ text: String) -> String? {
        guard self.settings.removeBoxDrawing else { return nil }
        return Self.stripBoxDrawingCharacters(in: text)
    }

    func transformIfCommand(_ text: String, aggressivenessOverride: Aggressiveness? = nil) -> String? {
        guard text.contains("\n") else { return nil }

        let lines = text.split(whereSeparator: { $0.isNewline })
        guard lines.count >= 2 else { return nil }
        if lines.count > 10 { return nil }

        var score = 0
        if text.contains("\\\n") { score += 1 }
        if text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil { score += 1 }
        if lines.allSatisfy(self.isLikelyCommandLine(_:)) { score += 1 }
        if text.range(of: #"(?m)^\s*(sudo\s+)?[A-Za-z0-9./~_-]+"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"[-/]"#, options: .regularExpression) != nil { score += 1 }

        let aggressiveness = aggressivenessOverride ?? self.settings.aggressiveness
        guard score >= aggressiveness.scoreThreshold else { return nil }

        let flattened = self.flatten(text)
        return flattened == text ? nil : flattened
    }

    private func isLikelyCommandLine(_ lineSubstr: Substring) -> Bool {
        let line = lineSubstr.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return false }
        if line.last == "." { return false }
        let pattern = #"^(sudo\s+)?[A-Za-z0-9./~_-]+(?:\s+|\z)"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    private func flatten(_ text: String) -> String {
        // Preserve intentional blank lines by temporarily swapping them out, then restoring.
        let placeholder = "__BLANK_SEP__"
        var result = text
        if self.settings.preserveBlankLines {
            result = result.replacingOccurrences(of: "\n\\s*\n", with: placeholder, options: .regularExpression)
        }
        result = result.replacingOccurrences(
            of: #"(?<!\n)([A-Z0-9_.-])\s*\n\s*([A-Z0-9_.-])(?!\n)"#,
            with: "$1$2",
            options: .regularExpression)
        result = result.replacingOccurrences(
            of: #"(?<=[/~])\s*\n\s*([A-Za-z0-9._-])"#,
            with: "$1",
            options: .regularExpression)
        result = result.replacingOccurrences(of: #"\\\s*\n"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if self.settings.preserveBlankLines {
            result = result.replacingOccurrences(of: placeholder, with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
