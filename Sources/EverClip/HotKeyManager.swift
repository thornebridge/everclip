import Carbon
import AppKit

enum HotKeyAction: UInt32 {
    case showDrawer      = 1
    case togglePasteStack = 2
    case pasteAsPlainText = 3
}

final class HotKeyManager {
    private var hotKeyRefs: [HotKeyAction: EventHotKeyRef] = [:]
    private static var callbacks: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    func register(action: HotKeyAction, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        Self.callbacks[action.rawValue] = callback

        if !Self.handlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, _ -> OSStatus in
                    var hotKeyID = EventHotKeyID()
                    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                      EventParamType(typeEventHotKeyID), nil,
                                      MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                    if let cb = HotKeyManager.callbacks[hotKeyID.id] {
                        DispatchQueue.main.async { cb() }
                    }
                    return noErr
                },
                1, &eventType, nil, nil
            )
            Self.handlerInstalled = true
        }

        let hotKeyID = EventHotKeyID(signature: 0x4556434C, id: action.rawValue)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if let ref { hotKeyRefs[action] = ref }
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        Self.callbacks.removeAll()
    }

    deinit { unregisterAll() }
}
