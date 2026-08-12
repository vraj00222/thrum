import AppKit

/// Reads what's on the pasteboard when the hotkey fires.
///
/// The brief says "grabs the current *selection*". There is no way to read another
/// app's selection without Accessibility permission, so we synthesise a Copy first
/// and fall back to whatever is already on the pasteboard if that yields nothing.
/// The common case — you already hit Cmd-C — works either way. See DECISIONS.md.
enum PasteboardWatcher {

    static func currentText(preferSelection: Bool = true) -> String? {
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount

        if preferSelection, AXIsProcessTrusted() {
            synthesiseCopy()
            // Give the frontmost app a moment to service the copy.
            let deadline = Date().addingTimeInterval(0.25)
            while pasteboard.changeCount == before && Date() < deadline {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
            }
        }

        let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (text?.isEmpty == false) ? text : nil
    }

    /// True when we're allowed to synthesise the copy. The UI uses this to explain
    /// why the hotkey is reading the clipboard instead of the selection.
    static var canReadSelection: Bool { AXIsProcessTrusted() }

    static func requestSelectionAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private static func synthesiseCopy() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let c: CGKeyCode = 8
        let down = CGEvent(keyboardEventSource: source, virtualKey: c, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: c, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
