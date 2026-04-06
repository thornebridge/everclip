import Foundation

struct ClipboardEntry: Identifiable {
    let id: String
    let contentType: ContentType
    let textContent: String?
    let imagePath: String?
    let sourceApp: String?
    let createdAt: Date
    let contentHash: String

    // V2 fields
    var title: String? = nil
    var sourceAppBundleID: String? = nil
    var isFavorite: Bool = false
    var rtfData: Data? = nil

    var displayText: String {
        if let t = title, !t.isEmpty { return t }
        if let text = textContent { return String(text.prefix(300)) }
        if contentType == .image { return "Image" }
        return ""
    }

    var effectiveTitle: String {
        if let t = title, !t.isEmpty { return t }
        switch contentType {
        case .url:
            if let text = textContent, let url = URL(string: text) {
                return url.host ?? text
            }
            return textContent ?? "Link"
        case .image: return "Image"
        case .file:  return textContent ?? "File"
        default:     return String((textContent ?? "").prefix(50))
        }
    }
}
