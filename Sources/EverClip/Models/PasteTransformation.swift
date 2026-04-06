import Foundation

enum PasteTransformation: String, CaseIterable, Identifiable {
    case plainText
    case uppercase
    case lowercase
    case titleCase
    case trimWhitespace
    case urlEncode
    case urlDecode
    case wrapInQuotes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainText:      "Plain Text"
        case .uppercase:      "UPPERCASE"
        case .lowercase:      "lowercase"
        case .titleCase:      "Title Case"
        case .trimWhitespace: "Trim Whitespace"
        case .urlEncode:      "URL Encode"
        case .urlDecode:      "URL Decode"
        case .wrapInQuotes:   "Wrap in \"Quotes\""
        }
    }

    func apply(_ input: String) -> String {
        switch self {
        case .plainText:      return input
        case .uppercase:      return input.uppercased()
        case .lowercase:      return input.lowercased()
        case .titleCase:      return input.capitalized
        case .trimWhitespace: return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case .urlEncode:      return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        case .urlDecode:      return input.removingPercentEncoding ?? input
        case .wrapInQuotes:   return "\"\(input)\""
        }
    }
}
