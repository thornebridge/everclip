import SwiftUI

enum ContentType: String, Codable, CaseIterable {
    case text
    case url
    case image
    case code
    case file
    case color
    case markdown

    var displayName: String {
        switch self {
        case .text:     "Text"
        case .url:      "Link"
        case .image:    "Image"
        case .code:     "Code"
        case .file:     "File"
        case .color:    "Color"
        case .markdown: "Markdown"
        }
    }

    var accentColor: Color {
        switch self {
        case .text:     Color(red: 0.23, green: 0.51, blue: 0.96)
        case .url:      Color(red: 0.06, green: 0.73, blue: 0.51)
        case .image:    Color(red: 0.55, green: 0.36, blue: 0.96)
        case .code:     Color(red: 0.96, green: 0.62, blue: 0.04)
        case .file:     Color(red: 0.42, green: 0.45, blue: 0.50)
        case .color:    Color(red: 0.96, green: 0.26, blue: 0.40)
        case .markdown: Color(red: 0.38, green: 0.45, blue: 0.96)
        }
    }

    var iconName: String {
        switch self {
        case .text:     "doc.text"
        case .url:      "link"
        case .image:    "photo"
        case .code:     "chevron.left.forwardslash.chevron.right"
        case .file:     "doc"
        case .color:    "paintpalette"
        case .markdown: "doc.richtext"
        }
    }
}
