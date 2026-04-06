import AppKit

final class PasteStackManager: ObservableObject {
    @Published var isCollecting = false
    @Published var stack: [ClipboardEntry] = []

    func toggle(monitor: ClipboardMonitor) {
        if isCollecting {
            // Stop collecting and paste all
            isCollecting = false
            if !stack.isEmpty {
                pasteAll(monitor: monitor)
            }
        } else {
            // Start collecting
            stack.removeAll()
            isCollecting = true
        }
    }

    func addToStack(_ entry: ClipboardEntry) {
        guard isCollecting else { return }
        stack.append(entry)
    }

    func cancel() {
        isCollecting = false
        stack.removeAll()
    }

    private func pasteAll(monitor: ClipboardMonitor) {
        let items = stack
        stack.removeAll()

        let pb = NSPasteboard.general
        var idx = 0

        func pasteNext() {
            guard idx < items.count else { return }
            let entry = items[idx]
            idx += 1

            monitor.suppressNext()
            pb.clearContents()

            if entry.contentType == .image, let path = entry.imagePath,
               let image = NSImage(contentsOfFile: path) {
                pb.writeObjects([image])
            } else if let text = entry.textContent {
                pb.setString(text, forType: .string)
            }

            PasteSimulator.paste()

            if idx < items.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    pasteNext()
                }
            }
        }

        pasteNext()
    }
}
