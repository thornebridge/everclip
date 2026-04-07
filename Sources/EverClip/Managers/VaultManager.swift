import Foundation
import AppKit

/// Persistent credential vault backed by SQLite.
/// All data stays local on your Mac — never transmitted, never synced.
/// Passwords auto-clear from clipboard after 30 seconds.
final class VaultManager: ObservableObject {
    @Published private(set) var credentials: [Credential] = []
    private let store: CredentialStore

    init(store: CredentialStore) {
        self.store = store
        self.credentials = store.loadAll()
    }

    // MARK: - CRUD

    func save(_ credential: Credential) {
        store.save(credential)
        credentials = store.loadAll()
    }

    func delete(id: String) {
        store.delete(id: id)
        credentials = store.loadAll()
    }

    func deleteAll() {
        store.deleteAll()
        credentials.removeAll()
    }

    func reload() {
        credentials = store.loadAll()
    }

    // MARK: - Queries

    var count: Int { credentials.count }

    var platforms: [String] {
        let unique = Set(credentials.map { $0.platform })
        return unique.sorted()
    }

    func credentials(forPlatform platform: String) -> [Credential] {
        credentials.filter { $0.platform == platform }
    }

    // MARK: - Secure Clipboard Actions

    func copyUsername(_ credential: Credential, monitor: ClipboardMonitor) {
        guard let username = credential.username else { return }
        monitor.suppressNext()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(username, forType: .string)
    }

    func copyPassword(_ credential: Credential, monitor: ClipboardMonitor) {
        guard let password = credential.password else { return }
        monitor.suppressNext()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(password, forType: .string)

        // Auto-clear password from clipboard after 30 seconds
        let snapshot = NSPasteboard.general.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if NSPasteboard.general.changeCount == snapshot {
                NSPasteboard.general.clearContents()
            }
        }
    }
}
