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
    private var recentHashes: Set<String> = []

    init(storage: StorageManager) {
        self.storage = storage
        self.entries = storage.entries.loadAll(limit: 200)
        self.recentHashes = Set(entries.map { $0.contentHash })
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

        // O(1) dedup via hash set, with DB fallback for entries outside the window
        if recentHashes.contains(entry.contentHash) || storage.entries.existsWithHash(entry.contentHash) {
            return
        }

        recentHashes.insert(entry.contentHash)
        entries.insert(entry, at: 0)

        // Cap in-memory array to 500 (DB is the source of truth for older entries)
        if entries.count > 500 {
            entries = Array(entries.prefix(500))
        }

        // Cap hash set to prevent unbounded growth
        if recentHashes.count > 10_000 {
            recentHashes = Set(entries.map { $0.contentHash })
        }

        storage.entries.save(entry)

        // Batch prune via preference-based retention
        let maxDays = storage.preferences.getInt("retentionDays", default: 0)
        if maxDays > 0 {
            storage.entries.pruneOlderThan(days: maxDays)
        }

        // Evaluate smart rules for auto-pinboard assignment (enabled only)
        let rules = storage.smartRules.loadEnabled()
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
