import Foundation
import CSQLite

final class CredentialStore {
    private let db: DatabaseConnection

    init(db: DatabaseConnection) {
        self.db = db
    }

    func save(_ cred: Credential) {
        let sql = """
            INSERT OR REPLACE INTO credentials
                (id, platform, username, password, created_at)
            VALUES (?,?,?,?,?)
        """
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, cred.id)
        db.bind(stmt, 2, cred.platform)
        db.bind(stmt, 3, cred.username)
        db.bind(stmt, 4, cred.password)
        db.bindDouble(stmt, 5, cred.createdAt.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func loadAll() -> [Credential] {
        let sql = "SELECT id, platform, username, password, created_at FROM credentials ORDER BY platform ASC, created_at DESC"
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        var creds: [Credential] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            creds.append(Credential(
                id: db.col(stmt, 0) ?? UUID().uuidString,
                platform: db.col(stmt, 1) ?? "",
                username: db.col(stmt, 2),
                password: db.col(stmt, 3),
                createdAt: Date(timeIntervalSince1970: db.colDouble(stmt, 4))
            ))
        }
        return creds
    }

    func delete(id: String) {
        guard let stmt = db.prepare("DELETE FROM credentials WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, id)
        sqlite3_step(stmt)
    }

    func deleteAll() {
        db.exec("DELETE FROM credentials")
    }

    func count() -> Int {
        guard let stmt = db.prepare("SELECT COUNT(*) FROM credentials") else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? db.colInt(stmt, 0) : 0
    }
}
