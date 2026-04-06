import AppKit
import CryptoKit

final class ClipboardMonitor: ObservableObject {
    @Published var entries: [ClipboardEntry] = []
    @Published var isPaused: Bool = false

    let storage: StorageManager
    private let detector = ContentDetector()
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var suppressNextChange = false

    init(storage: StorageManager) {
        self.storage = storage
        self.entries = storage.entries.loadAll()
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call before writing to the system pasteboard so the monitor ignores our own write.
    func suppressNext() {
        suppressNextChange = true
    }

    // MARK: - Polling

    private func poll() {
        guard !isPaused else { return }

        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if suppressNextChange {
            suppressNextChange = false
            return
        }

        // App exclusion check
        let excludedIDs = storage.preferences.getStringArray("excludedBundleIDs")
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           excludedIDs.contains(bundleID) {
            return
        }

        guard let entry = extract(from: pb) else { return }

        // Deduplicate — if the newest entry has the same hash, skip
        if entries.first?.contentHash == entry.contentHash { return }

        // Move duplicate to the front if it already exists deeper in history
        entries.removeAll { $0.contentHash == entry.contentHash }
        entries.insert(entry, at: 0)

        // Prune old entries
        let maxEntries = storage.preferences.getInt("maxEntries", default: 1000)
        while entries.count > maxEntries {
            let old = entries.removeLast()
            storage.entries.delete(id: old.id)
            storage.entries.deleteImageIfNeeded(old)
        }

        storage.entries.save(entry)

        // Evaluate smart rules for auto-pinboard assignment
        let rules = storage.smartRules.loadAll()
        let pinboardIDs = SmartRuleEngine.evaluate(entry: entry, rules: rules)
        for pbID in pinboardIDs {
            storage.pinboards.addEntry(entryID: entry.id, toPinboard: pbID)
        }
    }

    // MARK: - Extraction

    private func extract(from pb: NSPasteboard) -> ClipboardEntry? {
        let types = pb.types ?? []
        let frontApp = NSWorkspace.shared.frontmostApplication
        let sourceApp = frontApp?.localizedName
        let bundleID = frontApp?.bundleIdentifier

        // Image
        if types.contains(.tiff) || types.contains(.png) {
            if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
                let id = UUID().uuidString
                let path = storage.entries.saveImage(data: data, id: id)
                return ClipboardEntry(
                    id: id, contentType: .image,
                    textContent: nil, imagePath: path,
                    sourceApp: sourceApp, createdAt: Date(),
                    contentHash: sha256(data),
                    sourceAppBundleID: bundleID
                )
            }
        }

        // File URL
        if types.contains(.fileURL),
           let urlStr = pb.string(forType: .fileURL),
           let url = URL(string: urlStr) {
            return ClipboardEntry(
                id: UUID().uuidString, contentType: .file,
                textContent: url.lastPathComponent, imagePath: nil,
                sourceApp: sourceApp, createdAt: Date(),
                contentHash: sha256(Data(url.absoluteString.utf8)),
                sourceAppBundleID: bundleID
            )
        }

        // String (text / url / code / color)
        if let string = pb.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let type = detector.detect(string)
            return ClipboardEntry(
                id: UUID().uuidString, contentType: type,
                textContent: string, imagePath: nil,
                sourceApp: sourceApp, createdAt: Date(),
                contentHash: sha256(Data(string.utf8)),
                sourceAppBundleID: bundleID
            )
        }

        return nil
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
