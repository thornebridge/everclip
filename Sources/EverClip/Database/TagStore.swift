import Foundation
import CSQLite

final class TagStore {
    private let db: DatabaseConnection

    init(db: DatabaseConnection) {
        self.db = db
    }

    // MARK: - Tag CRUD

    func save(_ tag: Tag) {
        let sql = "INSERT OR REPLACE INTO tags (id, name, color, created_at) VALUES (?,?,?,?)"
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, tag.id)
        db.bind(stmt, 2, tag.name)
        db.bind(stmt, 3, tag.color)
        db.bindDouble(stmt, 4, tag.createdAt.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func loadAll() -> [Tag] {
        let sql = "SELECT id, name, color, created_at FROM tags ORDER BY name ASC"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var tags: [Tag] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            tags.append(Tag(
                id: db.col(stmt, 0) ?? UUID().uuidString,
                name: db.col(stmt, 1) ?? "",
                color: db.col(stmt, 2) ?? "#6B7280",
                createdAt: Date(timeIntervalSince1970: db.colDouble(stmt, 3))
            ))
        }
        return tags
    }

    func delete(id: String) {
        guard let stmt = db.prepare("DELETE FROM tags WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, id)
        sqlite3_step(stmt)
    }

    // MARK: - Entry associations

    func addTag(tagID: String, toEntry entryID: String) {
        let sql = "INSERT OR IGNORE INTO entry_tags (entry_id, tag_id) VALUES (?,?)"
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, entryID)
        db.bind(stmt, 2, tagID)
        sqlite3_step(stmt)
    }

    func removeTag(tagID: String, fromEntry entryID: String) {
        let sql = "DELETE FROM entry_tags WHERE entry_id = ? AND tag_id = ?"
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, entryID)
        db.bind(stmt, 2, tagID)
        sqlite3_step(stmt)
    }

    func entryIDs(withTag tagID: String) -> Set<String> {
        let sql = "SELECT entry_id FROM entry_tags WHERE tag_id = ?"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, tagID)

        var ids: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let id = db.col(stmt, 0) { ids.insert(id) }
        }
        return ids
    }

    func tagIDs(forEntry entryID: String) -> Set<String> {
        let sql = "SELECT tag_id FROM entry_tags WHERE entry_id = ?"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, entryID)

        var ids: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let id = db.col(stmt, 0) { ids.insert(id) }
        }
        return ids
    }

    func entryCount(withTag tagID: String) -> Int {
        let sql = "SELECT COUNT(*) FROM entry_tags WHERE tag_id = ?"
        guard let stmt = db.prepare(sql) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, tagID)
        return sqlite3_step(stmt) == SQLITE_ROW ? db.colInt(stmt, 0) : 0
    }
}
