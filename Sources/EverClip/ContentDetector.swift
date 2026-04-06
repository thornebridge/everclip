import Foundation

struct ContentDetector {
    func detect(_ text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isURL(trimmed)      { return .url }
        if isColor(trimmed)    { return .color }
        if isMarkdown(trimmed) { return .markdown }
        if isCode(trimmed)     { return .code }
        return .text
    }

    // MARK: - URL

    private func isURL(_ text: String) -> Bool {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector.firstMatch(in: text, range: range), match.range.length >= text.count * 3 / 4 {
            return true
        }
        return false
    }

    // MARK: - Color

    private func isColor(_ text: String) -> Bool {
        let stripped = text.hasPrefix("#") ? String(text.dropFirst()) : text
        if (stripped.count == 3 || stripped.count == 6 || stripped.count == 8),
           stripped.allSatisfy({ $0.isHexDigit }) {
            return true
        }
        let lower = text.lowercased()
        if lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(") || lower.hasPrefix("hsl(") || lower.hasPrefix("hsla(") {
            return true
        }
        return false
    }

    // MARK: - Markdown

    private func isMarkdown(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 3 else { return false }

        var score = 0

        // Headings: # Title
        let headingLines = lines.filter { $0.range(of: #"^#{1,6}\s"#, options: .regularExpression) != nil }
        if headingLines.count >= 1 { score += 3 }

        // Bold/italic: **text** or *text*
        if text.contains("**") || text.range(of: #"\*\w"#, options: .regularExpression) != nil { score += 1 }

        // Lists: - item or * item or 1. item
        let listLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).range(of: #"^[-*]\s|^\d+\.\s"#, options: .regularExpression) != nil }
        if listLines.count >= 2 { score += 2 }

        // Code fences
        let fences = lines.filter { $0.hasPrefix("```") }
        if fences.count >= 2 { score += 3 }

        // Links: [text](url)
        if text.range(of: #"\[.+?\]\(.+?\)"#, options: .regularExpression) != nil { score += 2 }

        // Checkboxes: - [ ] or - [x]
        if text.contains("- [ ]") || text.contains("- [x]") { score += 2 }

        // Must score high enough AND not be detected as code first
        return score >= 4
    }

    // MARK: - Code

    private func isCode(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return false }

        var score = 0

        // Indentation
        let indented = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
        if indented.count > lines.count / 3 { score += 2 }

        // Language keywords / symbols
        let patterns = [
            "function ", "func ", "def ", "class ", "import ", "from ",
            "const ", "let ", "var ", "return ", "if (", "else {", "for ",
            "while ", "switch ", "case ", "struct ", "enum ", "interface ",
            "public ", "private ", "async ", "await ",
            "=>", "->", "&&", "||", "!==", "===",
        ]
        for p in patterns where text.contains(p) { score += 1 }

        // Semicolons at line ends
        let semiLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasSuffix(";") }
        if semiLines.count > 1 { score += 2 }

        // Balanced braces
        let open = text.filter { $0 == "{" }.count
        let close = text.filter { $0 == "}" }.count
        if open > 0 && open == close { score += 2 }

        return score >= 4
    }
}
