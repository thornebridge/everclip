import Foundation

struct SmartRule: Identifiable, Equatable {
    let id: String
    var name: String
    var targetPinboardID: String?
    var conditions: [RuleCondition]
    var isEnabled: Bool
    var sortOrder: Int
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, targetPinboardID: String? = nil,
         conditions: [RuleCondition] = [], isEnabled: Bool = true,
         sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.targetPinboardID = targetPinboardID
        self.conditions = conditions
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

enum RuleCondition: Codable, Equatable {
    case sourceApp(bundleID: String)
    case contentType(ContentType)
    case textMatches(pattern: String)
    case urlDomain(String)

    var displayName: String {
        switch self {
        case .sourceApp:   "Source App"
        case .contentType: "Content Type"
        case .textMatches: "Text Matches"
        case .urlDomain:   "URL Domain"
        }
    }
}
