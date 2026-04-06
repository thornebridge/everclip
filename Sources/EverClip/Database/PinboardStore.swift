import Foundation
import CSQLite

final class PinboardStore {
    private let db: DatabaseConnection

    init(db: DatabaseConnection) {
        self.db = db
    }

    // MARK: - Pinboard CRUD

    func save(_ pinboard: Pinboard) {
        let sql = """
            INSERT OR REPLACE INTO pinboards (id, name, color, icon, sort_order, created_at)
            VALUES (?,?,?,?,?,?)
        """
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, pinboard.id)
        db.bind(stmt, 2, pinboard.name)
        db.bind(stmt, 3, pinboard.color)
        db.bind(stmt, 4, pinboard.icon)
        db.bindInt(stmt, 5, pinboard.sortOrder)
        db.bindDouble(stmt, 6, pinboard.createdAt.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func loadAll() -> [Pinboard] {
        let sql = "SELECT id, name, color, icon, sort_order, created_at FROM pinboards ORDER BY sort_order ASC"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var pinboards: [Pinboard] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            pinboards.append(Pinboard(
                id: db.col(stmt, 0) ?? UUID().uuidString,
                name: db.col(stmt, 1) ?? "Untitled",
                color: db.col(stmt, 2) ?? "#3B82F6",
                icon: db.col(stmt, 3) ?? "pin",
                sortOrder: db.colInt(stmt, 4),
                createdAt: Date(timeIntervalSince1970: db.colDouble(stmt, 5))
            ))
        }
        return pinboards
    }

    func delete(id: String) {
        guard let stmt = db.prepare("DELETE FROM pinboards WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, id)
        sqlite3_step(stmt)
    }

    // MARK: - Entry associations

    func addEntry(entryID: String, toPinboard pinboardID: String) {
        let sql = "INSERT OR IGNORE INTO entry_pinboards (entry_id, pinboard_id, sort_order, pinned_at) VALUES (?,?,0,?)"
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, entryID)
        db.bind(stmt, 2, pinboardID)
        db.bindDouble(stmt, 3, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func removeEntry(entryID: String, fromPinboard pinboardID: String) {
        let sql = "DELETE FROM entry_pinboards WHERE entry_id = ? AND pinboard_id = ?"
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, entryID)
        db.bind(stmt, 2, pinboardID)
        sqlite3_step(stmt)
    }

    func entryIDs(inPinboard pinboardID: String) -> Set<String> {
        let sql = "SELECT entry_id FROM entry_pinboards WHERE pinboard_id = ? ORDER BY sort_order ASC"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, pinboardID)

        var ids: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let id = db.col(stmt, 0) { ids.insert(id) }
        }
        return ids
    }

    func pinboardIDs(forEntry entryID: String) -> Set<String> {
        let sql = "SELECT pinboard_id FROM entry_pinboards WHERE entry_id = ?"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, entryID)

        var ids: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let id = db.col(stmt, 0) { ids.insert(id) }
        }
        return ids
    }

    func entryCount(inPinboard pinboardID: String) -> Int {
        let sql = "SELECT COUNT(*) FROM entry_pinboards WHERE pinboard_id = ?"
        guard let stmt = db.prepare(sql) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, pinboardID)
        return sqlite3_step(stmt) == SQLITE_ROW ? db.colInt(stmt, 0) : 0
    }
}
