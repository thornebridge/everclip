import Foundation
import CSQLite

final class SnippetStore {
    private let db: DatabaseConnection

    init(db: DatabaseConnection) {
        self.db = db
    }

    func save(_ snippet: Snippet) {
        let sql = """
            INSERT OR REPLACE INTO snippets
                (id, abbreviation, expansion_text, is_enabled, use_count, created_at)
            VALUES (?,?,?,?,?,?)
        """
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, snippet.id)
        db.bind(stmt, 2, snippet.abbreviation)
        db.bind(stmt, 3, snippet.expansionText)
        db.bindInt(stmt, 4, snippet.isEnabled ? 1 : 0)
        db.bindInt(stmt, 5, snippet.useCount)
        db.bindDouble(stmt, 6, snippet.createdAt.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func loadAll() -> [Snippet] {
        let sql = "SELECT id, abbreviation, expansion_text, is_enabled, use_count, created_at FROM snippets ORDER BY abbreviation ASC"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var snippets: [Snippet] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            snippets.append(Snippet(
                id: db.col(stmt, 0) ?? UUID().uuidString,
                abbreviation: db.col(stmt, 1) ?? "",
                expansionText: db.col(stmt, 2) ?? "",
                isEnabled: db.colInt(stmt, 3) != 0,
                useCount: db.colInt(stmt, 4),
                createdAt: Date(timeIntervalSince1970: db.colDouble(stmt, 5))
            ))
        }
        return snippets
    }

    func delete(id: String) {
        guard let stmt = db.prepare("DELETE FROM snippets WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, id)
        sqlite3_step(stmt)
    }

    func incrementUseCount(id: String) {
        db.exec("UPDATE snippets SET use_count = use_count + 1 WHERE id = '\(id)'")
    }

    func findByAbbreviation(_ abbrev: String) -> Snippet? {
        let sql = "SELECT id, abbreviation, expansion_text, is_enabled, use_count, created_at FROM snippets WHERE abbreviation = ? AND is_enabled = 1"
        guard let stmt = db.prepare(sql) else { return nil }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, abbrev)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Snippet(
            id: db.col(stmt, 0) ?? UUID().uuidString,
            abbreviation: db.col(stmt, 1) ?? "",
            expansionText: db.col(stmt, 2) ?? "",
            isEnabled: db.colInt(stmt, 3) != 0,
            useCount: db.colInt(stmt, 4),
            createdAt: Date(timeIntervalSince1970: db.colDouble(stmt, 5))
        )
    }
}
