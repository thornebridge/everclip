import CSQLite

final class MigrationManager {
    private let db: DatabaseConnection

    init(db: DatabaseConnection) {
        self.db = db
    }

    func migrate() {
        // Bootstrap: create V1 entries table if fresh install
        db.exec("""
            CREATE TABLE IF NOT EXISTS entries (
                id           TEXT PRIMARY KEY,
                content_type TEXT NOT NULL,
                text_content TEXT,
                image_path   TEXT,
                source_app   TEXT,
                created_at   REAL NOT NULL,
                content_hash TEXT NOT NULL
            )
        """)
        db.exec("CREATE INDEX IF NOT EXISTS idx_entries_created ON entries(created_at DESC)")
        db.exec("CREATE INDEX IF NOT EXISTS idx_entries_hash    ON entries(content_hash)")

        // Version tracking
        db.exec("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)")

        let current = currentVersion()
        let migrations: [(Int, () -> Void)] = [
            (1, migration1),
            (2, migration2),
            (3, migration3),
            (4, migration4),
            (5, migration5),
        ]

        for (version, run) in migrations where version > current {
            db.exec("BEGIN TRANSACTION")
            run()
            if current == 0 && version == 1 {
                db.exec("INSERT INTO schema_version (version) VALUES (\(version))")
            } else {
                db.exec("UPDATE schema_version SET version = \(version)")
            }
            db.exec("COMMIT")
        }
    }

    private func currentVersion() -> Int {
        guard let stmt = db.prepare("SELECT version FROM schema_version LIMIT 1") else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? db.colInt(stmt, 0) : 0
    }

    // MARK: - Migration 1: V2 columns + Pinboards

    private func migration1() {
        db.exec("ALTER TABLE entries ADD COLUMN title TEXT")
        db.exec("ALTER TABLE entries ADD COLUMN source_bundle_id TEXT")
        db.exec("ALTER TABLE entries ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0")
        db.exec("ALTER TABLE entries ADD COLUMN rtf_data BLOB")

        db.exec("""
            CREATE TABLE pinboards (
                id         TEXT PRIMARY KEY,
                name       TEXT NOT NULL,
                color      TEXT NOT NULL DEFAULT '#3B82F6',
                icon       TEXT NOT NULL DEFAULT 'pin',
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL
            )
        """)

        db.exec("""
            CREATE TABLE entry_pinboards (
                entry_id    TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
                pinboard_id TEXT NOT NULL REFERENCES pinboards(id) ON DELETE CASCADE,
                sort_order  INTEGER NOT NULL DEFAULT 0,
                pinned_at   REAL NOT NULL,
                PRIMARY KEY (entry_id, pinboard_id)
            )
        """)
        db.exec("CREATE INDEX idx_ep_pinboard ON entry_pinboards(pinboard_id)")
    }

    // MARK: - Migration 2: Tags + Smart Rules

    private func migration2() {
        db.exec("""
            CREATE TABLE tags (
                id         TEXT PRIMARY KEY,
                name       TEXT NOT NULL UNIQUE,
                color      TEXT NOT NULL DEFAULT '#6B7280',
                created_at REAL NOT NULL
            )
        """)
        db.exec("""
            CREATE TABLE entry_tags (
                entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE CASCADE,
                tag_id   TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
                PRIMARY KEY (entry_id, tag_id)
            )
        """)
        db.exec("CREATE INDEX idx_et_tag ON entry_tags(tag_id)")

        db.exec("""
            CREATE TABLE smart_rules (
                id                 TEXT PRIMARY KEY,
                name               TEXT NOT NULL,
                target_pinboard_id TEXT REFERENCES pinboards(id) ON DELETE SET NULL,
                conditions_json    TEXT NOT NULL,
                is_enabled         INTEGER NOT NULL DEFAULT 1,
                sort_order         INTEGER NOT NULL DEFAULT 0,
                created_at         REAL NOT NULL
            )
        """)
    }

    // MARK: - Migration 3: Snippets + Preferences

    private func migration3() {
        db.exec("""
            CREATE TABLE snippets (
                id              TEXT PRIMARY KEY,
                abbreviation    TEXT NOT NULL UNIQUE,
                expansion_text  TEXT NOT NULL,
                is_enabled      INTEGER NOT NULL DEFAULT 1,
                use_count       INTEGER NOT NULL DEFAULT 0,
                created_at      REAL NOT NULL
            )
        """)
        db.exec("CREATE INDEX idx_snippets_abbr ON snippets(abbreviation)")

        db.exec("""
            CREATE TABLE preferences (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            )
        """)
    }

    // MARK: - Migration 4: Performance indexes for 1M-entry scale

    private func migration4() {
        db.exec("CREATE INDEX IF NOT EXISTS idx_entries_favorite ON entries(is_favorite)")
        db.exec("CREATE INDEX IF NOT EXISTS idx_entries_content_type ON entries(content_type)")
        db.exec("CREATE INDEX IF NOT EXISTS idx_entries_source_bundle ON entries(source_bundle_id)")
        db.exec("CREATE INDEX IF NOT EXISTS idx_entries_text_search ON entries(text_content COLLATE NOCASE)")
        db.exec("CREATE INDEX IF NOT EXISTS idx_ep_entry ON entry_pinboards(entry_id)")
        db.exec("CREATE INDEX IF NOT EXISTS idx_et_entry ON entry_tags(entry_id)")
    }

    // MARK: - Migration 5: Credentials vault

    private func migration5() {
        db.exec("""
            CREATE TABLE credentials (
                id         TEXT PRIMARY KEY,
                platform   TEXT NOT NULL,
                username   TEXT,
                password   TEXT,
                created_at REAL NOT NULL
            )
        """)
        db.exec("CREATE INDEX idx_creds_platform ON credentials(platform)")
    }
}
