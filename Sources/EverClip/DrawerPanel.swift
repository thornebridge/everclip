import AppKit

/// Borderless floating panel that can become key (receive keyboard events).
final class DrawerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
