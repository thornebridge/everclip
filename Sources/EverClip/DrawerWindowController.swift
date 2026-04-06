import AppKit
import SwiftUI

final class DrawerWindowController {
    private var panel: DrawerPanel?
    private let monitor: ClipboardMonitor
    private let storage: StorageManager
    private var viewModel: DrawerViewModel?
    private var previousApp: NSRunningApplication?
    private var clickMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    private let drawerHeight: CGFloat = 260
    private let edgePadding: CGFloat = 12

    init(monitor: ClipboardMonitor) {
        self.monitor = monitor
        self.storage = monitor.storage
    }

    // MARK: - Show / Hide

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication

        let screen = screenUnderMouse()
        let frame = screen.frame
        let width = frame.width - edgePadding * 2
        let startY = frame.origin.y - drawerHeight
        let endY = frame.origin.y + edgePadding
        let x = frame.origin.x + edgePadding

        let startFrame = NSRect(x: x, y: startY, width: width, height: drawerHeight)
        let endFrame   = NSRect(x: x, y: endY,   width: width, height: drawerHeight)

        if panel == nil { buildPanel(frame: startFrame) }

        viewModel?.reloadCollections()

        guard let panel else { return }

        panel.setFrame(startFrame, display: false)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(endFrame, display: true)
        }

        installClickOutsideMonitor()
    }

    func hide(andPaste: Bool = false) {
        removeClickOutsideMonitor()

        guard let panel, let screen = NSScreen.main else { return }

        let hideFrame = NSRect(
            x: panel.frame.origin.x,
            y: screen.frame.origin.y - drawerHeight,
            width: panel.frame.width,
            height: drawerHeight
        )

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(hideFrame, display: true)
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            if andPaste { self?.activateAndPaste() }
        })
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    // MARK: - Selection Handling

    func select(entry: ClipboardEntry, paste: Bool) {
        let pb = NSPasteboard.general
        monitor.suppressNext()
        pb.clearContents()

        if entry.contentType == .image, let path = entry.imagePath,
           let image = NSImage(contentsOfFile: path) {
            pb.writeObjects([image])
        } else if let text = entry.textContent {
            pb.setString(text, forType: .string)
        }

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

        let vibrancy = NSVisualEffectView(frame: p.contentView!.bounds)
        vibrancy.autoresizingMask = [.width, .height]
        vibrancy.material = .hudWindow
        vibrancy.state = .active
        vibrancy.wantsLayer = true
        vibrancy.layer?.cornerRadius = 16
        vibrancy.layer?.masksToBounds = true
        p.contentView?.addSubview(vibrancy)

        let vm = DrawerViewModel(monitor: monitor, storage: storage)
        vm.onSelect = { [weak self] entry, paste in self?.select(entry: entry, paste: paste) }
        vm.onSelectTransformed = { [weak self] entry, transform in
            self?.selectTransformed(entry: entry, transform: transform)
        }
        vm.onDismiss = { [weak self] in self?.hide() }
        viewModel = vm

        let contentView = DrawerContentView(viewModel: vm)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = p.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        p.contentView?.addSubview(hosting)

        panel = p
    }

    private func activateAndPaste() {
        previousApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            PasteSimulator.paste()
        }
    }

    private func screenUnderMouse() -> NSScreen {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(loc, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
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
