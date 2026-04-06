import Foundation

struct Pinboard: Identifiable, Equatable {
    let id: String
    var name: String
    var color: String
    var icon: String
    var sortOrder: Int
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, color: String = "#3B82F6",
         icon: String = "pin", sortOrder: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
