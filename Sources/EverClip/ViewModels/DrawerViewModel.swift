import SwiftUI
import Combine

enum SidebarFilter: Hashable {
    case all
    case favorites
    case pinboard(id: String)
    case tag(id: String)
}

final class DrawerViewModel: ObservableObject {
    // MARK: - Filter State
    @Published var searchText = ""
    @Published var sidebarFilter: SidebarFilter = .all
    @Published var contentTypeFilter: ContentType? = nil
    @Published var isSidebarVisible = true
    @Published var selectedIndex = 0

    // MARK: - Collections
    @Published var pinboards: [Pinboard] = []
    @Published var tags: [Tag] = []

    // MARK: - UI State
    @Published var showPinboardEditor = false
    @Published var editingPinboard: Pinboard? = nil
    @Published var showNewTagField = false
    @Published var quickLookEntry: ClipboardEntry? = nil

    // MARK: - Callbacks (set by DrawerWindowController)
    var onSelect: ((ClipboardEntry, Bool) -> Void)?
    var onSelectTransformed: ((ClipboardEntry, PasteTransformation) -> Void)?
    var onDismiss: (() -> Void)?

    let monitor: ClipboardMonitor
    let storage: StorageManager

    init(monitor: ClipboardMonitor, storage: StorageManager) {
        self.monitor = monitor
        self.storage = storage
        reloadCollections()
    }

    func reloadCollections() {
        pinboards = storage.pinboards.loadAll()
        tags = storage.tags.loadAll()
    }

    // MARK: - Filtered entries

    var filteredEntries: [ClipboardEntry] {
        var result = monitor.entries

        switch sidebarFilter {
        case .all:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        case .pinboard(let id):
            let entryIDs = storage.pinboards.entryIDs(inPinboard: id)
            result = result.filter { entryIDs.contains($0.id) }
        case .tag(let id):
            let entryIDs = storage.tags.entryIDs(withTag: id)
            result = result.filter { entryIDs.contains($0.id) }
        }

        if let type = contentTypeFilter {
            result = result.filter { $0.contentType == type }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { entry in
                entry.textContent?.lowercased().contains(q) ?? false
                    || entry.contentType.displayName.lowercased().contains(q)
                    || entry.sourceApp?.lowercased().contains(q) ?? false
                    || entry.title?.lowercased().contains(q) ?? false
            }
        }

        return result
    }

    // MARK: - Entry Actions

    func select(_ entry: ClipboardEntry, paste: Bool) {
        onSelect?(entry, paste)
    }

    func selectTransformed(_ entry: ClipboardEntry, transform: PasteTransformation) {
        onSelectTransformed?(entry, transform)
    }

    func dismiss() { onDismiss?() }

    func move(_ delta: Int) {
        let entries = filteredEntries
        guard !entries.isEmpty else { return }
        selectedIndex = max(0, min(entries.count - 1, selectedIndex + delta))
    }

    func toggleFavorite(_ entry: ClipboardEntry) {
        guard let idx = monitor.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        monitor.entries[idx].isFavorite.toggle()
        storage.entries.updateFavorite(id: entry.id, isFavorite: monitor.entries[idx].isFavorite)
    }

    func deleteEntry(_ entry: ClipboardEntry) {
        monitor.entries.removeAll { $0.id == entry.id }
        storage.entries.delete(id: entry.id)
        storage.entries.deleteImageIfNeeded(entry)
    }

    func updateTitle(_ entry: ClipboardEntry, title: String) {
        guard let idx = monitor.entries.firstIndex(where: { $0.id == entry.id }) else { return }
        monitor.entries[idx].title = title
        storage.entries.updateTitle(id: entry.id, title: title.isEmpty ? nil : title)
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

    // MARK: - Counts

    func favoriteCount() -> Int {
        monitor.entries.filter { $0.isFavorite }.count
    }

    func pinboardEntryCount(_ id: String) -> Int {
        storage.pinboards.entryCount(inPinboard: id)
    }

    func tagEntryCount(_ id: String) -> Int {
        storage.tags.entryCount(withTag: id)
    }
}
