import Foundation

enum PreviewMetrics {
    static func charCountSuffix(count: Int, limit: Int? = nil, showTruncations: Bool = true) -> String {
        let truncations = showTruncations ? (limit.map { self.truncationCount(for: count, limit: $0) } ?? 0) : 0
        if count >= 1000 {
            let k = Double(count) / 1000.0
            let formatted = k >= 10 ? String(format: "%.0fk", k) : String(format: "%.1fk", k)
            return truncations > 0
                ? " (\(formatted) chars, \(truncations) truncations)"
                : " (\(formatted) chars)"
        } else {
            return truncations > 0
                ? " (\(count) chars, \(truncations) truncations)"
                : " (\(count) chars)"
        }
    }

    static func prettyBadge(count: Int, limit: Int? = nil, showTruncations: Bool = true) -> String {
        let chars = count >= 1000
            ? "\(kString(count)) chars"
            : "\(count) chars"

        guard showTruncations, let limit, limit > 0 else {
            return " · \(chars)"
        }

        let truncations = self.truncationCount(for: count, limit: limit)
        guard truncations > 0 else { return " · \(chars)" }
        return " · \(chars) · \(truncations) trimmed"
    }

    static func displayString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "⏎ ")
            .replacingOccurrences(of: "\t", with: "⇥ ")
    }

    static func displayStringWithVisibleWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: " ", with: "·")
            .replacingOccurrences(of: "\t", with: "⇥")
            .replacingOccurrences(of: "\n", with: "⏎")
    }

    /// Map a source string to a visible-whitespace string while carrying per-character flags.
    /// Each source character expands to exactly one visible character so indices stay aligned.
    static func mapToVisibleWhitespace(_ text: String, removed: [Bool]) -> (String, [Bool]) {
        precondition(text.count == removed.count, "removed flags must match character count")
        var mapped = ""
        var mappedRemoved: [Bool] = []
        for (ch, flag) in zip(text, removed) {
            let out: Character = switch ch {
            case " ": "·"
            case "\t": "⇥"
            case "\n": "⏎"
            default: ch
            }
            mapped.append(out)
            mappedRemoved.append(flag)
        }
        return (mapped, mappedRemoved)
    }

    private static func truncationCount(for count: Int, limit: Int) -> Int {
        guard count > limit, limit > 0 else { return 0 }
        return (count + limit - 1) / limit - 1
    }

    private static func kString(_ count: Int) -> String {
        let k = Double(count) / 1000.0
        return k >= 10 ? String(format: "%.0f", k) + "k" : String(format: "%.1f", k) + "k"
    }
}
