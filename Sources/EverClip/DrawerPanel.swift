import AppKit

/// Borderless floating panel that can become key (receive keyboard events).
/// Intercepts Return/Enter at the NSPanel level to guarantee paste works
/// regardless of SwiftUI focus state.
final class DrawerPanel: NSPanel {
    var onReturnKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        // Return (36) or Enter (76) — paste the selected entry
        if event.keyCode == 36 || event.keyCode == 76 {
            onReturnKey?()
            return
        }
        super.keyDown(with: event)
    }
}
