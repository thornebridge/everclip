import SwiftUI
import Combine

enum SidebarFilter: Hashable {
    case all
    case favorites
    case pinboard(id: String)
    case tag(id: String)
    case vault
}

final class DrawerViewModel: ObservableObject {
    // MARK: - Filter State
    @Published var searchText = ""
    @Published var sidebarFilter: SidebarFilter = .all
    @Published var contentTypeFilter: ContentType? = nil
    @Published var isSidebarVisible = true
    @Published var selectedIndex = 0

    // MARK: - DB-backed filtered results
    @Published var filteredEntries: [ClipboardEntry] = []

    // MARK: - Collections
    @Published var pinboards: [Pinboard] = []
    @Published var tags: [Tag] = []

    // MARK: - Cached sidebar counts (refreshed on reload, not per-render)
    @Published var cachedAllCount = 0
    @Published var cachedFavCount = 0
    @Published var cachedVaultCount = 0
    @Published var cachedPinboardCounts: [String: Int] = [:]
    @Published var cachedTagCounts: [String: Int] = [:]

    // MARK: - UI State
    @Published var showPinboardEditor = false
    @Published var editingPinboard: Pinboard? = nil
    @Published var showNewTagField = false
    @Published var quickLookEntry: ClipboardEntry? = nil
    @Published var credentialSaveEntry: ClipboardEntry? = nil
    @Published var credentialSaveField: CredentialField? = nil
    var showCredentialSave: Bool {
        get { credentialSaveEntry != nil }
        set { if !newValue { credentialSaveEntry = nil; credentialSaveField = nil } }
    }

    // MARK: - Direct reference (no closure chain)
    weak var controller: DrawerWindowController?

    let monitor: ClipboardMonitor
    let storage: StorageManager
    let vault: VaultManager
    private var cancellables = Set<AnyCancellable>()

    init(monitor: ClipboardMonitor, storage: StorageManager, vault: VaultManager) {
        self.monitor = monitor
        self.storage = storage
        self.vault = vault
        reloadCollections()

        // Debounce search text for responsive typing
        $searchText
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reloadFilteredEntries() }
            .store(in: &cancellables)

        // Debounce sidebar/content filters to avoid thrashing on rapid changes
        $sidebarFilter
            .removeDuplicates()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reloadFilteredEntries() }
            .store(in: &cancellables)
        $contentTypeFilter
            .removeDuplicates()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reloadFilteredEntries() }
            .store(in: &cancellables)

        // Reload when new clipboard entries arrive (debounced to match 0.3s poll)
        monitor.$entries
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reloadFilteredEntries() }
            .store(in: &cancellables)

        reloadFilteredEntries()
    }

    func reloadCollections() {
        pinboards = storage.pinboards.loadAll()
        tags = storage.tags.loadAll()
        refreshCounts()
    }

    // MARK: - Filtered entries (DB-backed)

    func reloadFilteredEntries() {
        let query = searchText.isEmpty ? nil : searchText
        let ct = contentTypeFilter?.rawValue

        let fav: Bool?
        if case .favorites = sidebarFilter { fav = true } else { fav = nil }

        let pbID: String?
        if case .pinboard(let id) = sidebarFilter { pbID = id } else { pbID = nil }

        let tID: String?
        if case .tag(let id) = sidebarFilter { tID = id } else { tID = nil }

        filteredEntries = storage.entries.search(
            query: query, contentType: ct, isFavorite: fav,
            pinboardID: pbID, tagID: tID, limit: 200
        )
        refreshCounts()
    }

    private func refreshCounts() {
        cachedAllCount = storage.entries.countAll()
        cachedFavCount = storage.entries.countFavorites()
        cachedVaultCount = storage.credentials.count()
        cachedPinboardCounts = Dictionary(uniqueKeysWithValues:
            pinboards.map { ($0.id, storage.pinboards.entryCount(inPinboard: $0.id)) })
        cachedTagCounts = Dictionary(uniqueKeysWithValues:
            tags.map { ($0.id, storage.tags.entryCount(withTag: $0.id)) })
    }

    // MARK: - Entry Actions

    func select(_ entry: ClipboardEntry, paste: Bool) {
        controller?.select(entry: entry, paste: paste)
    }

    func selectTransformed(_ entry: ClipboardEntry, transform: PasteTransformation) {
        controller?.selectTransformed(entry: entry, transform: transform)
    }

    func dismiss() { controller?.hide() }

    func move(_ delta: Int) {
        let entries = filteredEntries
        guard !entries.isEmpty else { return }
        selectedIndex = max(0, min(entries.count - 1, selectedIndex + delta))
    }

    func toggleFavorite(_ entry: ClipboardEntry) {
        let newValue = !entry.isFavorite
        storage.entries.updateFavorite(id: entry.id, isFavorite: newValue)
        // Update in-memory monitor array if present
        if let idx = monitor.entries.firstIndex(where: { $0.id == entry.id }) {
            monitor.entries[idx].isFavorite = newValue
        }
        reloadFilteredEntries()
    }

    func deleteEntry(_ entry: ClipboardEntry) {
        storage.entries.delete(id: entry.id)
        storage.entries.deleteImageIfNeeded(entry)
        monitor.entries.removeAll { $0.id == entry.id }
        reloadFilteredEntries()
    }

    func updateTitle(_ entry: ClipboardEntry, title: String) {
        storage.entries.updateTitle(id: entry.id, title: title.isEmpty ? nil : title)
        if let idx = monitor.entries.firstIndex(where: { $0.id == entry.id }) {
            monitor.entries[idx].title = title
        }
        reloadFilteredEntries()
    }

    // MARK: - Pinboard Actions

    func createPinboard(name: String, color: String) {
        let maxOrder = pinboards.map(\.sortOrder).max() ?? -1
        let pb = Pinboard(name: name, color: color, sortOrder: maxOrder + 1)
        storage.pinboards.save(pb)
        reloadCollections()
    }

    func deletePinboard(_ id: String) {
        storage.pinboards.delete(id: id)
        if case .pinboard(let current) = sidebarFilter, current == id {
            sidebarFilter = .all
        }
        reloadCollections()
    }

    func togglePinboard(entryID: String, pinboardID: String) {
        let current = storage.pinboards.pinboardIDs(forEntry: entryID)
        if current.contains(pinboardID) {
            storage.pinboards.removeEntry(entryID: entryID, fromPinboard: pinboardID)
        } else {
            storage.pinboards.addEntry(entryID: entryID, toPinboard: pinboardID)
        }
    }

    func isPinned(entryID: String, pinboardID: String) -> Bool {
        storage.pinboards.pinboardIDs(forEntry: entryID).contains(pinboardID)
    }

    // MARK: - Tag Actions

    func createTag(name: String, color: String = "#6B7280") {
        let tag = Tag(name: name, color: color)
        storage.tags.save(tag)
        reloadCollections()
    }

    func deleteTag(_ id: String) {
        storage.tags.delete(id: id)
        if case .tag(let current) = sidebarFilter, current == id {
            sidebarFilter = .all
        }
        reloadCollections()
    }

    func toggleTag(entryID: String, tagID: String) {
        let current = storage.tags.tagIDs(forEntry: entryID)
        if current.contains(tagID) {
            storage.tags.removeTag(tagID: tagID, fromEntry: entryID)
        } else {
            storage.tags.addTag(tagID: tagID, toEntry: entryID)
        }
    }

    func hasTag(entryID: String, tagID: String) -> Bool {
        storage.tags.tagIDs(forEntry: entryID).contains(tagID)
    }

    // MARK: - Counts (cached)

    func favoriteCount() -> Int { cachedFavCount }
    func allItemsCount() -> Int { cachedAllCount }
    func vaultCount() -> Int { cachedVaultCount }
    func pinboardEntryCount(_ id: String) -> Int { cachedPinboardCounts[id] ?? 0 }
    func tagEntryCount(_ id: String) -> Int { cachedTagCounts[id] ?? 0 }
}
