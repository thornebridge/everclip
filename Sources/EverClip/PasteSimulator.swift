import CoreGraphics
import ApplicationServices
import AppKit

enum PasteSimulator {
    /// Simulates Cmd+V into the frontmost application. Returns true if posted successfully.
    @discardableResult
    static func paste() -> Bool {
        guard AXIsProcessTrusted() else {
            promptAccessibility()
            return false
        }

        let src = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09

        guard let down = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) else {
            return false
        }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    /// Paste as plain text: writes plain text to pasteboard then simulates Cmd+V.
    static func pasteAsPlainText(monitor: ClipboardMonitor) {
        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string) {
            monitor.suppressNext()
            pb.clearContents()
            pb.setString(str, forType: .string)
        }
        paste()
    }

    /// Direct paste: writes entry to pasteboard, pastes, then restores original clipboard.
    static func directPaste(entry: ClipboardEntry, monitor: ClipboardMonitor) {
        let pb = NSPasteboard.general

        let savedTypes = pb.types ?? []
        var savedData: [(NSPasteboard.PasteboardType, Data)] = []
        for type in savedTypes {
            if let data = pb.data(forType: type) {
                savedData.append((type, data))
            }
        }

        monitor.suppressNext()
        pb.clearContents()
        if entry.contentType == .image, let path = entry.imagePath,
           let image = NSImage(contentsOfFile: path) {
            pb.writeObjects([image])
        } else if let text = entry.textContent {
            pb.setString(text, forType: .string)
        }

        paste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            monitor.suppressNext()
            pb.clearContents()
            for (type, data) in savedData {
                pb.setData(data, forType: type)
            }
        }
    }

    /// Checks accessibility and prompts if not granted. Returns current status.
    @discardableResult
    static func ensureAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            promptAccessibility()
        }
        return trusted
    }

    private static func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
