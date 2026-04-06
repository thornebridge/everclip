import Foundation
import CSQLite

final class SmartRuleStore {
    private let db: DatabaseConnection

    init(db: DatabaseConnection) {
        self.db = db
    }

    func save(_ rule: SmartRule) {
        let sql = """
            INSERT OR REPLACE INTO smart_rules
                (id, name, target_pinboard_id, conditions_json, is_enabled, sort_order, created_at)
            VALUES (?,?,?,?,?,?,?)
        """
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }

        let conditionsJSON: String
        if let data = try? JSONEncoder().encode(rule.conditions),
           let str = String(data: data, encoding: .utf8) {
            conditionsJSON = str
        } else {
            conditionsJSON = "[]"
        }

        db.bind(stmt, 1, rule.id)
        db.bind(stmt, 2, rule.name)
        db.bind(stmt, 3, rule.targetPinboardID)
        db.bind(stmt, 4, conditionsJSON)
        db.bindInt(stmt, 5, rule.isEnabled ? 1 : 0)
        db.bindInt(stmt, 6, rule.sortOrder)
        db.bindDouble(stmt, 7, rule.createdAt.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func loadAll() -> [SmartRule] {
        let sql = "SELECT id, name, target_pinboard_id, conditions_json, is_enabled, sort_order, created_at FROM smart_rules ORDER BY sort_order ASC"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var rules: [SmartRule] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let conditionsJSON = db.col(stmt, 3) ?? "[]"
            let conditions = (try? JSONDecoder().decode([RuleCondition].self, from: Data(conditionsJSON.utf8))) ?? []

            rules.append(SmartRule(
                id: db.col(stmt, 0) ?? UUID().uuidString,
                name: db.col(stmt, 1) ?? "Untitled Rule",
                targetPinboardID: db.col(stmt, 2),
                conditions: conditions,
                isEnabled: db.colInt(stmt, 4) != 0,
                sortOrder: db.colInt(stmt, 5),
                createdAt: Date(timeIntervalSince1970: db.colDouble(stmt, 6))
            ))
        }
        return rules
    }

    func delete(id: String) {
        guard let stmt = db.prepare("DELETE FROM smart_rules WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, id)
        sqlite3_step(stmt)
    }
}
