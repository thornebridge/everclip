import Foundation

/// Facade that owns the database connection and exposes typed sub-stores.
final class StorageManager {
    let entries: EntryStore
    let pinboards: PinboardStore
    let tags: TagStore
    let smartRules: SmartRuleStore
    let snippets: SnippetStore
    let preferences: PreferencesStore

    private let connection: DatabaseConnection

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("EverClip")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let dbPath = appDir.appendingPathComponent("everclip.db").path
        let imagesDir = appDir.appendingPathComponent("images").path

        connection = DatabaseConnection(path: dbPath)

        // Run all pending migrations before creating stores
        MigrationManager(db: connection).migrate()

        entries     = EntryStore(db: connection, imagesDir: imagesDir)
        pinboards   = PinboardStore(db: connection)
        tags        = TagStore(db: connection)
        smartRules  = SmartRuleStore(db: connection)
        snippets    = SnippetStore(db: connection)
        preferences = PreferencesStore(db: connection)
    }
}
