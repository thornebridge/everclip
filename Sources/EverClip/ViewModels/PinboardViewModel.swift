import SwiftUI

final class PinboardViewModel: ObservableObject {
    @Published var pinboards: [Pinboard] = []
    @Published var isEditorPresented = false
    @Published var editingPinboard: Pinboard?

    private let storage: StorageManager

    init(storage: StorageManager) {
        self.storage = storage
        reload()
    }

    func reload() {
        pinboards = storage.pinboards.loadAll()
    }

    func create(name: String, color: String, icon: String) {
        let maxOrder = pinboards.map(\.sortOrder).max() ?? -1
        let pb = Pinboard(name: name, color: color, icon: icon, sortOrder: maxOrder + 1)
        storage.pinboards.save(pb)
        reload()
    }

    func update(_ pinboard: Pinboard) {
        storage.pinboards.save(pinboard)
        reload()
    }

    func delete(id: String) {
        storage.pinboards.delete(id: id)
        reload()
    }

    func addEntry(entryID: String, toPinboard pinboardID: String) {
        storage.pinboards.addEntry(entryID: entryID, toPinboard: pinboardID)
    }

    func removeEntry(entryID: String, fromPinboard pinboardID: String) {
        storage.pinboards.removeEntry(entryID: entryID, fromPinboard: pinboardID)
    }

    func pinboardIDs(forEntry entryID: String) -> Set<String> {
        storage.pinboards.pinboardIDs(forEntry: entryID)
    }
}
