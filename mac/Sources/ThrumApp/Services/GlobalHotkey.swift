import AppKit
import Carbon.HIToolbox

/// One system-wide hotkey. Carbon's RegisterEventHotKey is still the only API that
/// fires without Accessibility permission, which matters: the daily loop is
/// "select text anywhere, press the key, feel it" and a permission wall kills that.
final class GlobalHotkey {

    static let shared = GlobalHotkey()

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var action: (() -> Void)?

    private init() {}

    /// Default is ⌃⌥⌘M.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_M),
                  modifiers: UInt32 = UInt32(controlKey | optionKey | cmdKey),
                  action: @escaping () -> Void) {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            if id.signature == GlobalHotkey.signature {
                DispatchQueue.main.async { GlobalHotkey.shared.action?() }
            }
            return noErr
        }, 1, &eventType, nil, &handler)

        let id = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    private static let signature: OSType = 0x5448524D  // 'THRM'
}
