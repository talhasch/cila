import Foundation

/// Decides whether a copied string is worth offering for improvement.
enum TextFilter {
    /// Very short copies ("Thanks!", "ok, tamam") are real language too, but
    /// rarely worth a popup.
    static let minCharacters = 20
    static let minWords = 4

    static func shouldIgnore(_ copied: String) -> Bool {
        let trimmed = copied.trimmed
        if trimmed.count < minCharacters { return true }
        if trimmed.split(whereSeparator: \.isWhitespace).count < minWords { return true }

        // Huge copies (whole files, logs) only need a sample to classify.
        let text = String(trimmed.prefix(4000))

        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmed }.filter { !$0.isEmpty }
        if lines.allSatisfy(isNonProse) { return true }

        if looksLikeCode(text, lines: lines) { return true }
        return !ProseDetector.isProse(text)
    }

    // MARK: - URLs, emails, paths, numbers

    private static func isNonProse(_ line: String) -> Bool {
        matches(line, url) || matches(line, bareDomain) || matches(line, email)
            || matches(line, path) || matches(line, number)
    }

    private static let url = regex(#"^(?:[a-z][a-z0-9+.\-]*://|www\.)\S+$"#)
    private static let bareDomain = regex(#"^[\w\-]+(?:\.[\w\-]+)*\.[a-z]{2,}(?:[/:?#]\S*)?$"#)
    private static let email = regex(#"^(?:mailto:)?[\w.%+\-]+@[\w.\-]+\.[a-z]{2,}$"#)
    private static let path = regex(#"^(?:~|\.{1,2})?/\S.*$|^[a-z]:\\.*$|^\\\\\S+.*$"#)
    private static let number = regex(#"^[\d\s.,:;/()%+\-–$€£₺#*xX]*\d[\d\s.,:;/()%+\-–$€£₺#*xX]*$"#)

    // MARK: - Code

    /// Heuristic scoring; prose rarely collects more than one or two points.
    static func looksLikeCode(_ text: String, lines: [String]) -> Bool {
        let trimmed = text.trimmed
        if let first = trimmed.first, "{[".contains(first),
           (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil {
            return true
        }
        if lines.count == 1, matches(trimmed, shellCommand) { return true }
        if matches(trimmed, sqlQuery) { return true }

        var score = 0
        let rawLines = text.split(whereSeparator: \.isNewline).map(String.init)

        let symbols = text.filter { "{}[]();=<>|&$\\`_".contains($0) }.count
        if Double(symbols) / Double(max(text.count, 1)) > 0.06 { score += 2 }

        let codeEndings = lines.filter { $0.hasSuffix(";") || $0.hasSuffix("{") || $0 == "}" || $0.hasPrefix("}") }.count
        score += fractionScore(codeEndings, of: lines.count)

        let keywordLines = lines.filter { matches($0, codeKeyword) }.count
        if keywordLines > 0 {
            score += Double(keywordLines) / Double(lines.count) >= 0.5 ? 3 : 1
        }

        let operators = count(text, codeOperator)
        score += operators >= 2 ? 2 : operators

        if count(text, identifierCall) > 0 { score += 1 }

        let indented = rawLines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }.count
        if indented >= 2 { score += 1 }

        return score >= 3
    }

    private static func fractionScore(_ hits: Int, of total: Int) -> Int {
        guard hits > 0 else { return 0 }
        return Double(hits) / Double(max(total, 1)) >= 0.3 ? 2 : 1
    }

    private static let shellCommand = regex(
        #"^(?:\$ |sudo |git |npm |npx |yarn |pnpm |brew |pip3? |cd |ls |curl |wget |docker |kubectl |swift |python3? |node |cargo |go |make |chmod |rm |mkdir |ssh |export )"#
    )
    /// Case-sensitive, so capitalized prose ("Import duties…", "Select the file…") doesn't match.
    private static let codeKeyword = regex(
        #"^(?:import\s+[\w.{]|from\s+\S+\s+import\s|#include|#import|package\s+[\w.]+;?$|using\s+[\w.]+;|def\s+\w+\(|func\s+\w+|function\s*\w*\(|fn\s+\w+|class\s+\w+\s*[(\{<:]|struct\s+\w+|enum\s+\w+\s*[{:]|interface\s+\w+\s*\{|(?:public|private|protected|static|internal|final)\s+(?:\w+\s+)*(?:func|class|void|var|let|fun|def|async|override|struct|enum|interface|int|String|\w+\s*\()|const\s+\w+\s*=|let\s+\w+\s*[=:]|var\s+\w+\s*[=:]|val\s+\w+\s*=|(?:if|for|while|switch)\s*\(.*\)\s*\{|return\b.*;|(?:SELECT|INSERT INTO|UPDATE|DELETE FROM|CREATE TABLE|ALTER TABLE)\s|<\?php|<!DOCTYPE|<[a-z]+[\s>]|#!/|@\w+\s*(?:\(|$))"#,
        caseSensitive: true
    )
    /// Lower-case SQL too, but only with a query shape ("select a, b from t where…").
    private static let sqlQuery = regex(
        #"^(?:select\s+[\w*.,\s()]+?\s+from\s+[\w.]+(?:\s+(?:where|order\s+by|group\s+by|join|left|inner|limit)\b|\s*;|\s*$)|insert\s+into\s+[\w.]+\s*\(|update\s+[\w.]+\s+set\s+\w+\s*=|delete\s+from\s+[\w.]+\s+where\s)"#
    )
    private static let codeOperator = regex(#"=>|->|===|!==|==|!=|&&|\|\||::|\+=|-=|:=|</\w|/>|\+\+"#)
    private static let identifierCall = regex(#"\b(?:[a-z]+[A-Z]\w*|\w+_\w+|\w+\.\w+)\([^)]*\)"#)

    // MARK: - Regex helpers

    private static func regex(_ pattern: String, caseSensitive: Bool = false) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
    }

    private static func matches(_ string: String, _ regex: NSRegularExpression) -> Bool {
        regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)) != nil
    }

    private static func count(_ string: String, _ regex: NSRegularExpression) -> Int {
        regex.numberOfMatches(in: string, range: NSRange(string.startIndex..., in: string))
    }
}
