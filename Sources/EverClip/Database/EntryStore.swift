import Foundation
import CSQLite
import AppKit

final class EntryStore {
    private let db: DatabaseConnection
    let imagesDir: String

    init(db: DatabaseConnection, imagesDir: String) {
        self.db = db
        self.imagesDir = imagesDir
        try? FileManager.default.createDirectory(atPath: imagesDir, withIntermediateDirectories: true)
    }

    // MARK: - CRUD

    func save(_ entry: ClipboardEntry) {
        let sql = """
            INSERT OR REPLACE INTO entries
                (id, content_type, text_content, image_path, source_app, created_at, content_hash,
                 title, source_bundle_id, is_favorite, rtf_data)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)
        """
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }

        db.bind(stmt, 1, entry.id)
        db.bind(stmt, 2, entry.contentType.rawValue)
        db.bind(stmt, 3, entry.textContent)
        db.bind(stmt, 4, entry.imagePath)
        db.bind(stmt, 5, entry.sourceApp)
        db.bindDouble(stmt, 6, entry.createdAt.timeIntervalSince1970)
        db.bind(stmt, 7, entry.contentHash)
        db.bind(stmt, 8, entry.title)
        db.bind(stmt, 9, entry.sourceAppBundleID)
        db.bindInt(stmt, 10, entry.isFavorite ? 1 : 0)
        db.bindBlob(stmt, 11, entry.rtfData)
        sqlite3_step(stmt)
    }

    func loadAll(limit: Int = 1000) -> [ClipboardEntry] {
        let sql = """
            SELECT id, content_type, text_content, image_path, source_app, created_at, content_hash,
                   title, source_bundle_id, is_favorite, rtf_data
            FROM entries ORDER BY created_at DESC LIMIT ?
        """
        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }
        db.bindInt(stmt, 1, limit)

        var entries: [ClipboardEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(readEntry(from: stmt))
        }
        return entries
    }

    // MARK: - Search & Filtering (DB-level)

    /// Full-text search at DB level — replaces in-memory filtering for scale.
    func search(query: String? = nil, contentType: String? = nil,
                isFavorite: Bool? = nil, pinboardID: String? = nil,
                tagID: String? = nil, limit: Int = 200, offset: Int = 0) -> [ClipboardEntry] {
        var clauses: [String] = []
        var binds: [(Int32, Any)] = []
        var paramIdx: Int32 = 1

        if let q = query, !q.isEmpty {
            clauses.append("(text_content LIKE ? OR title LIKE ? OR source_app LIKE ?)")
            let pattern = "%\(q)%"
            binds.append((paramIdx, pattern)); paramIdx += 1
            binds.append((paramIdx, pattern)); paramIdx += 1
            binds.append((paramIdx, pattern)); paramIdx += 1
        }
        if let ct = contentType {
            clauses.append("content_type = ?")
            binds.append((paramIdx, ct)); paramIdx += 1
        }
        if let fav = isFavorite, fav {
            clauses.append("is_favorite = 1")
        }
        if let pbID = pinboardID {
            clauses.append("id IN (SELECT entry_id FROM entry_pinboards WHERE pinboard_id = ?)")
            binds.append((paramIdx, pbID)); paramIdx += 1
        }
        if let tID = tagID {
            clauses.append("id IN (SELECT entry_id FROM entry_tags WHERE tag_id = ?)")
            binds.append((paramIdx, tID)); paramIdx += 1
        }

        var sql = "SELECT id, content_type, text_content, image_path, source_app, created_at, content_hash, title, source_bundle_id, is_favorite, rtf_data FROM entries"
        if !clauses.isEmpty {
            sql += " WHERE " + clauses.joined(separator: " AND ")
        }
        sql += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
        binds.append((paramIdx, limit)); paramIdx += 1
        binds.append((paramIdx, offset))

        guard let stmt = db.prepare(sql) else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (idx, value) in binds {
            if let s = value as? String { db.bind(stmt, idx, s) }
            else if let i = value as? Int { db.bindInt(stmt, idx, i) }
        }

        var entries: [ClipboardEntry] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            entries.append(readEntry(from: stmt))
        }
        return entries
    }

    func countAll() -> Int {
        guard let stmt = db.prepare("SELECT COUNT(*) FROM entries") else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? db.colInt(stmt, 0) : 0
    }

    func countFavorites() -> Int {
        guard let stmt = db.prepare("SELECT COUNT(*) FROM entries WHERE is_favorite = 1") else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? db.colInt(stmt, 0) : 0
    }

    func existsWithHash(_ hash: String) -> Bool {
        guard let stmt = db.prepare("SELECT 1 FROM entries WHERE content_hash = ? LIMIT 1") else { return false }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, hash)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    func updateTitle(id: String, title: String?) {
        guard let stmt = db.prepare("UPDATE entries SET title = ? WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, title)
        db.bind(stmt, 2, id)
        sqlite3_step(stmt)
    }

    func updateFavorite(id: String, isFavorite: Bool) {
        guard let stmt = db.prepare("UPDATE entries SET is_favorite = ? WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bindInt(stmt, 1, isFavorite ? 1 : 0)
        db.bind(stmt, 2, id)
        sqlite3_step(stmt)
    }

    func delete(id: String) {
        guard let stmt = db.prepare("DELETE FROM entries WHERE id = ?") else { return }
        defer { sqlite3_finalize(stmt) }
        db.bind(stmt, 1, id)
        sqlite3_step(stmt)
    }

    func clearAll() {
        db.exec("DELETE FROM entries")
        clearImages()
    }

    func pruneOlderThan(days: Int) {
        guard days > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400).timeIntervalSince1970
        // Don't prune favorites or pinned items — NOT EXISTS scales better than NOT IN
        let sql = """
            DELETE FROM entries WHERE created_at < ? AND is_favorite = 0
            AND NOT EXISTS (SELECT 1 FROM entry_pinboards WHERE entry_pinboards.entry_id = entries.id)
        """
        guard let stmt = db.prepare(sql) else { return }
        defer { sqlite3_finalize(stmt) }
        db.bindDouble(stmt, 1, cutoff)
        sqlite3_step(stmt)
    }

    // MARK: - Images

    func saveImage(data: Data, id: String) -> String {
        let path = "\(imagesDir)/\(id).png"
        try? data.write(to: URL(fileURLWithPath: path))
        return path
    }

    func deleteImageIfNeeded(_ entry: ClipboardEntry) {
        guard let path = entry.imagePath else { return }
        try? FileManager.default.removeItem(atPath: path)
    }

    func clearImages() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDir) else { return }
        for file in files {
            try? FileManager.default.removeItem(atPath: "\(imagesDir)/\(file)")
        }
    }

    // MARK: - Row Reader

    private func readEntry(from stmt: OpaquePointer?) -> ClipboardEntry {
        ClipboardEntry(
            id:                db.col(stmt, 0) ?? UUID().uuidString,
            contentType:       ContentType(rawValue: db.col(stmt, 1) ?? "text") ?? .text,
            textContent:       db.col(stmt, 2),
            imagePath:         db.col(stmt, 3),
            sourceApp:         db.col(stmt, 4),
            createdAt:         Date(timeIntervalSince1970: db.colDouble(stmt, 5)),
            contentHash:       db.col(stmt, 6) ?? "",
            title:             db.col(stmt, 7),
            sourceAppBundleID: db.col(stmt, 8),
            isFavorite:        db.colInt(stmt, 9) != 0,
            rtfData:           db.colBlob(stmt, 10)
        )
    }
}
