import Foundation
import CSQLite

final class PreferencesStore {
    private let db: DatabaseConnection

    init(db: DatabaseConnection) {
        self.db = db
    }

    func get(_ key: String) -> String? {
        let sql = "SELECT value FROM preferences WHERE key = ?"
        guard let stmt = db.prepare(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, key)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return db.col(stmt, 0)
    }

    func set(_ key: String, value: String) {
        let sql = "INSERT OR REPLACE INTO preferences (key, value) VALUES (?,?)"
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, key)
        db.bind(stmt, 2, value)
        sqlite3_step(stmt)
    }

    func remove(_ key: String) {
        guard let stmt = db.prepare("DELETE FROM preferences WHERE key = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, key)
        sqlite3_step(stmt)
    }

    // MARK: - Typed accessors

    func getInt(_ key: String, default defaultValue: Int) -> Int {
        guard let str = get(key), let val = Int(str) else { return defaultValue }
        return val
    }

    func setInt(_ key: String, value: Int) {
        set(key, value: String(value))
    }

    func getDouble(_ key: String, default defaultValue: Double) -> Double {
        guard let str = get(key), let val = Double(str) else { return defaultValue }
        return val
    }

    func setDouble(_ key: String, value: Double) {
        set(key, value: String(value))
    }

    func getBool(_ key: String, default defaultValue: Bool) -> Bool {
        guard let str = get(key) else { return defaultValue }
        return str == "1" || str == "true"
    }

    func setBool(_ key: String, value: Bool) {
        set(key, value: value ? "1" : "0")
    }

    func getStringArray(_ key: String) -> [String] {
        guard let str = get(key), let data = str.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    func setStringArray(_ key: String, value: [String]) {
        guard let data = try? JSONEncoder().encode(value),
              let str = String(data: data, encoding: .utf8) else { return }
        set(key, value: str)
    }
}
