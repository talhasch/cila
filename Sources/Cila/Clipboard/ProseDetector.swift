import Foundation
import NaturalLanguage

/// Decides whether text reads like natural-language prose someone may want to
/// polish, as opposed to logs, tables, listings, UI labels, IDs and the like.
/// Thresholds were tuned against `ProseDetectorTests`.
enum ProseDetector {
    static func isProse(_ text: String) -> Bool {
        let text = text.trimmed
        let tokens = text.split(whereSeparator: \.isWhitespace)
        let nonWhitespace = text.filter { !$0.isWhitespace }
        guard !tokens.isEmpty, !nonWhitespace.isEmpty else { return false }

        // Character and token makeup.
        let letterRatio = ratio(nonWhitespace.filter(\.isLetter).count, nonWhitespace.count)
        let words = tokens.compactMap(naturalWord)
        let wordRatio = ratio(words.count, tokens.count)
        guard letterRatio >= 0.75, wordRatio >= 0.7 else { return false }

        // Language identification: prose is recognised with high confidence;
        // casual writing can score lower, so then demand very clean words.
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let confidence = recognizer.languageHypotheses(withMaximum: 1).values.first ?? 0
        if confidence < 0.5 { return false }
        if confidence < 0.85 && (letterRatio < 0.9 || wordRatio < 0.9) { return false }

        // Title Case Everywhere: headings, menu bars, lists of names.
        if words.count >= 3 {
            let capitalized = words.filter { $0.first?.isUppercase == true }.count
            if ratio(capitalized, words.count) >= 0.75 { return false }
        }

        return !hasNonProseLayout(text)
    }

    // MARK: - Layout

    private static func hasNonProseLayout(_ text: String) -> Bool {
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.trimmed.isEmpty }.map(String.init)

        // Tab-separated or column-aligned output (tables, `ls`, menu bars).
        let columnar = lines.filter { $0.trimmed.contains("\t") || matches($0, columnGap) }.count
        if ratio(columnar, lines.count) >= 0.5 { return true }

        guard lines.count >= 3 else { return false }

        // Many indented, non-bullet lines: stack traces, command output.
        let indented = lines.dropFirst().filter {
            ($0.first?.isWhitespace ?? false) && !matches($0.trimmed, bullet)
        }.count
        if ratio(indented, lines.count) >= 0.4 { return true }

        // Lists of short items: names, menu entries, file names.
        let averageWords = ratio(lines.reduce(0) { $0 + $1.split(whereSeparator: \.isWhitespace).count }, lines.count)
        if averageWords < 3.5 { return true }

        return false
    }

    /// Two or more spaces between words, not after a sentence end ("end.  Next").
    private static let columnGap = try! NSRegularExpression(pattern: #"[^\s.!?:] {2,}\S"#)
    private static let bullet = try! NSRegularExpression(pattern: #"^(?:[-*•–]|\d+[.)])\s"#)

    // MARK: - Helpers

    /// The token's letters if it reads like a natural word ("don't", "e-mail",
    /// "(hello),"), or nil for things like `foo.bar()`, `camelCase`, `x=1`, `42`.
    private static func naturalWord(_ token: Substring) -> Substring? {
        let core = token.trimmingCharacters(in: edgePunctuation)
        guard let first = core.first, first.isLetter,
              core.allSatisfy({ $0.isLetter || $0 == "'" || $0 == "’" || $0 == "-" })
        else { return nil }
        // camelCase identifiers (but allow ALLCAPS and Capitalized words).
        if first.isLowercase && core.dropFirst().contains(where: \.isUppercase) { return nil }
        return Substring(core)
    }

    private static let edgePunctuation = CharacterSet(charactersIn: "\"'“”‘’«»()[]¿¡.,!?;:…-—")

    private static func ratio(_ part: Int, _ whole: Int) -> Double {
        Double(part) / Double(max(whole, 1))
    }

    private static func matches(_ string: String, _ regex: NSRegularExpression) -> Bool {
        regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
    }
}
