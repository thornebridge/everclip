import Foundation

struct Tag: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var color: String
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, color: String = "#6B7280", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}
