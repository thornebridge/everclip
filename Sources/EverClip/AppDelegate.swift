import AppKit
import Carbon
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyManager: HotKeyManager!
    private(set) var storage: StorageManager!
    private(set) var monitor: ClipboardMonitor!
    private var drawer: DrawerWindowController!
    private var pasteStack: PasteStackManager!
    private var pauseMenuItem: NSMenuItem!
    private var stackPanel: NSPanel?
    private var preferencesWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        storage = StorageManager()
        monitor = ClipboardMonitor(storage: storage)
        pasteStack = PasteStackManager()
        drawer = DrawerWindowController(monitor: monitor)

        hotKeyManager = HotKeyManager()
        let cmdShift = UInt32(cmdKey | shiftKey)

        hotKeyManager.register(action: .showDrawer, keyCode: UInt32(kVK_ANSI_V), modifiers: cmdShift) { [weak self] in
            self?.drawer.toggle()
        }
        hotKeyManager.register(action: .togglePasteStack, keyCode: UInt32(kVK_ANSI_C), modifiers: cmdShift) { [weak self] in
            self?.togglePasteStack()
        }

        // Paste stack: add new captures to stack when collecting
        monitor.$entries
            .dropFirst()
            .sink { [weak self] entries in
                if let entry = entries.first {
                    self?.pasteStack.addToStack(entry)
                }
            }
            .store(in: &cancellables)

        pasteStack.$isCollecting
            .sink { [weak self] collecting in
                if collecting { self?.showStackOverlay() } else { self?.hideStackOverlay() }
            }
            .store(in: &cancellables)

        setupMenuBar()
        monitor.start()
        PasteSimulator.ensureAccessibility()
    }

    // MARK: - Paste Stack

    private func togglePasteStack() {
        pasteStack.toggle(monitor: monitor)
    }

    private func showStackOverlay() {
        guard stackPanel == nil, let screen = NSScreen.main else { return }

        let overlayView = PasteStackOverlayView(manager: pasteStack)
        let hosting = NSHostingView(rootView: overlayView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 50),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.contentView = hosting
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let x = screen.frame.maxX - 236
        let y = screen.frame.maxY - 70
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        stackPanel = panel
    }

    private func hideStackOverlay() {
        stackPanel?.orderOut(nil)
        stackPanel = nil
    }

    // MARK: - Preferences

    @objc private func showPreferences() {
        if let w = preferencesWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let prefsView = PreferencesView(storage: storage)
        let hosting = NSHostingView(rootView: prefsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = "EverClip Preferences"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        preferencesWindow = window
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "EverClip")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show History  ⌘⇧V", action: #selector(showHistory), keyEquivalent: "")
        menu.addItem(.separator())

        pauseMenuItem = NSMenuItem(title: "Pause Clipboard Capture", action: #selector(togglePause), keyEquivalent: "")
        menu.addItem(pauseMenuItem)

        menu.addItem(.separator())

        let countItem = NSMenuItem(title: "\(monitor.entries.count) items", action: nil, keyEquivalent: "")
        countItem.isEnabled = false
        countItem.tag = 100
        menu.addItem(countItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit EverClip", action: #selector(quit), keyEquivalent: "q")

        menu.delegate = self
        statusItem.menu = menu
    }

    @objc private func showHistory() { drawer.show() }

    @objc private func togglePause() {
        monitor.isPaused.toggle()
        pauseMenuItem.title = monitor.isPaused ? "Resume Clipboard Capture" : "Pause Clipboard Capture"
        if let btn = statusItem.button {
            btn.image = NSImage(
                systemSymbolName: monitor.isPaused ? "clipboard.fill" : "clipboard",
                accessibilityDescription: "EverClip"
            )
        }
    }

    @objc private func clearHistory() {
        monitor.entries.removeAll()
        storage.entries.clearAll()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let countItem = menu.item(withTag: 100) {
            countItem.title = "\(monitor.entries.count) items"
        }
    }
}
