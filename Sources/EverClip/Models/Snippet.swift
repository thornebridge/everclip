import Foundation

struct Snippet: Identifiable, Equatable {
    let id: String
    var abbreviation: String
    var expansionText: String
    var isEnabled: Bool
    var useCount: Int
    let createdAt: Date

    init(id: String = UUID().uuidString, abbreviation: String, expansionText: String,
         isEnabled: Bool = true, useCount: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.abbreviation = abbreviation
        self.expansionText = expansionText
        self.isEnabled = isEnabled
        self.useCount = useCount
        self.createdAt = createdAt
    }

    /// Expand template variables in the expansion text.
    func expand(clipboard: String? = nil) -> String {
        var result = expansionText
        let now = Date()
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium

        let timeFmt = DateFormatter()
        timeFmt.timeStyle = .short

        result = result.replacingOccurrences(of: "{{date}}", with: dateFmt.string(from: now))
        result = result.replacingOccurrences(of: "{{time}}", with: timeFmt.string(from: now))
        result = result.replacingOccurrences(of: "{{iso}}", with: ISO8601DateFormatter().string(from: now))
        if let clip = clipboard {
            result = result.replacingOccurrences(of: "{{clipboard}}", with: clip)
        }
        return result
    }
}
