import AppKit
import Carbon
import SwiftUI
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotKeyManager: HotKeyManager!
    private(set) var storage: StorageManager!
    private(set) var monitor: ClipboardMonitor!
    private var drawer: DrawerWindowController!
    private var pasteStack: PasteStackManager!
    private var updateChecker: UpdateChecker!
    private var pauseMenuItem: NSMenuItem!
    private var updateMenuItem: NSMenuItem!
    private var stackPanel: NSPanel?
    private var preferencesWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        storage = StorageManager()
        ThemeManager.shared.load(from: storage.preferences)
        monitor = ClipboardMonitor(storage: storage)
        pasteStack = PasteStackManager()
        updateChecker = UpdateChecker()
        let vault = VaultManager(store: storage.credentials)
        drawer = DrawerWindowController(monitor: monitor, vault: vault)

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

        // Prompt for launch at login on first run
        promptLoginItemIfNeeded()

        // Check for updates
        updateChecker.checkIfNeeded()
        updateChecker.$updateAvailable
            .receive(on: RunLoop.main)
            .sink { [weak self] available in
                self?.updateMenuItem?.isHidden = !available
                if available, let btn = self?.statusItem.button {
                    btn.image = NSImage(systemSymbolName: "clipboard.fill", accessibilityDescription: "EverClip — Update available")
                }
            }
            .store(in: &cancellables)
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
            .environmentObject(ThemeManager.shared)
        let hosting = NSHostingView(rootView: prefsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 480),
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

        updateMenuItem = NSMenuItem(title: "Update Available — Download", action: #selector(openUpdate), keyEquivalent: "")
        updateMenuItem.isHidden = true
        menu.addItem(updateMenuItem)
        menu.addItem(.separator())

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

    // MARK: - Launch at Login

    private func promptLoginItemIfNeeded() {
        let key = "hasPromptedLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let alert = NSAlert()
            alert.messageText = "Launch at Login?"
            alert.informativeText = "EverClip works best when it's always running. Start it automatically when you log in?"
            alert.addButton(withTitle: "Enable")
            alert.addButton(withTitle: "Not Now")
            alert.alertStyle = .informational
            if alert.runModal() == .alertFirstButtonReturn {
                try? SMAppService.mainApp.register()
            }
        }
    }

    @objc private func openUpdate() {
        updateChecker.openReleasePage()
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
