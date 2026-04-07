import AppKit
import SwiftUI
import ApplicationServices

final class DrawerWindowController {
    private var panel: DrawerPanel?
    private let monitor: ClipboardMonitor
    private let storage: StorageManager
    private let vault: VaultManager
    private var viewModel: DrawerViewModel?
    private var previousApp: NSRunningApplication?
    private var clickMonitor: Any?
    private var vibrancyView: NSVisualEffectView?
    private let theme = ThemeManager.shared

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Dynamic drawer height: card height + filter bar + status bar + padding
    private var drawerHeight: CGFloat {
        let cardH = theme.cardSize.height * theme.uiScale
        let chrome: CGFloat = 90
        return cardH + chrome
    }
    private let edgePadding: CGFloat = 12

    init(monitor: ClipboardMonitor, vault: VaultManager) {
        self.monitor = monitor
        self.storage = monitor.storage
        self.vault = vault
    }

    deinit {
        theme.onMaterialChange = nil
        removeClickOutsideMonitor()
    }

    // MARK: - Show / Hide

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        let screen = screenUnderMouse()
        let visible = screen.visibleFrame
        let height = drawerHeight
        let width = visible.width - edgePadding * 2
        let startY = visible.origin.y - height
        let endY = visible.origin.y + edgePadding
        let x = visible.origin.x + edgePadding

        let startFrame = NSRect(x: x, y: startY, width: width, height: height)
        let endFrame   = NSRect(x: x, y: endY,   width: width, height: height)

        if panel == nil { buildPanel(frame: startFrame) }

        guard let panel else { return }

        removeClickOutsideMonitor()

        // Position off-screen and show immediately (no data loading yet)
        panel.setFrame(startFrame, display: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Data is already live via Combine subscriptions — just animate
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(endFrame, display: true)
        }

        installClickOutsideMonitor()
    }

    func hide(andPaste: Bool = false) {
        removeClickOutsideMonitor()

        guard let panel else { return }
        let screen = screenUnderMouse()

        let hideFrame = NSRect(
            x: panel.frame.origin.x,
            y: screen.visibleFrame.origin.y - drawerHeight,
            width: panel.frame.width,
            height: panel.frame.height
        )

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hideFrame, display: true)
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            if andPaste { self?.activateAndPaste() }
        })

        // Safety: ensure panel is hidden even if animation completion doesn't fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak panel] in
            if panel?.isVisible == true { panel?.orderOut(nil) }
        }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Selection Handling

    /// Called by the panel's Return key handler — always works regardless of SwiftUI focus.
    func pasteSelectedEntry() {
        guard let vm = viewModel else { return }
        let entries = vm.filteredEntries
        guard !entries.isEmpty else { return }
        let idx = max(0, min(entries.count - 1, vm.selectedIndex))
        let entry = entries[idx]
        select(entry: entry, paste: true)
    }

    func select(entry: ClipboardEntry, paste: Bool) {
        let pb = NSPasteboard.general
        monitor.suppressNext()
        pb.clearContents()

        var didWrite = false
        if entry.contentType == .image, let path = entry.imagePath,
           let image = NSImage(contentsOfFile: path) {
            pb.writeObjects([image])
            didWrite = true
        } else if let text = entry.textContent {
            pb.setString(text, forType: .string)
            didWrite = true
        }

        guard didWrite else { return }

        if paste {
            hide(andPaste: true)
        }
    }

    func selectTransformed(entry: ClipboardEntry, transform: PasteTransformation) {
        guard let text = entry.textContent else { return }
        let transformed = transform.apply(text)

        let pb = NSPasteboard.general
        monitor.suppressNext()
        pb.clearContents()
        pb.setString(transformed, forType: .string)

        hide(andPaste: true)
    }

    // MARK: - Private

    private func buildPanel(frame: NSRect) {
        let p = DrawerPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.animationBehavior = .utilityWindow

        // Return/Enter key — paste selected entry (bypasses SwiftUI focus issues)
        p.onReturnKey = { [weak self] in
            self?.pasteSelectedEntry()
        }

        guard let contentView = p.contentView else { return }

        let vibrancy = NSVisualEffectView(frame: contentView.bounds)
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.material = theme.drawerMaterial.nsMaterial
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = theme.drawerCornerRadius
        vibrancy.layer?.masksToBounds = true
        contentView.addSubview(vibrancy)
        vibrancyView = vibrancy

        theme.onMaterialChange = { [weak self] in
            self?.vibrancyView?.material = ThemeManager.shared.drawerMaterial.nsMaterial
            self?.vibrancyView?.layer?.cornerRadius = ThemeManager.shared.drawerCornerRadius
        }

        let vm = DrawerViewModel(monitor: monitor, storage: storage, vault: vault)
        vm.controller = self
        viewModel = vm

        let swiftUIContent = DrawerContentView(viewModel: vm)
            .environmentObject(theme)
        let hosting = NSHostingView(rootView: swiftUIContent)
        hosting.frame = contentView.bounds
        hosting.autoresizingMask = [.width, .height]
        contentView.addSubview(hosting)

        panel = p
    }

    private static var hasShownAccessibilityAlert = false

    private func activateAndPaste() {
        // Check accessibility ONCE — show clear instructions if not granted
        if !AXIsProcessTrusted() && !Self.hasShownAccessibilityAlert {
            Self.hasShownAccessibilityAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "EverClip needs Accessibility access to paste into other apps.\n\n1. Open System Settings → Privacy & Security → Accessibility\n2. Remove EverClip if it's already listed\n3. Click + and add EverClip.app from Applications\n4. Make sure the toggle is ON"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "OK")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            return
        }

        if let prev = previousApp, !prev.isTerminated {
            prev.activate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            PasteSimulator.paste()
        }
    }

    private func screenUnderMouse() -> NSScreen {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(loc, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? NSScreen()
    }

    private func installClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self, self.isVisible, let panel = self.panel else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                self.hide()
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
    }
}
