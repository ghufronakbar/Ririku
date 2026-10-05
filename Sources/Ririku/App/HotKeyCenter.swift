import AppKit
import Carbon.HIToolbox
import RirikuCore

/// Registers the global shortcut that opens the panel through the Carbon hot key API,
/// which needs no Accessibility permission (R-UI-17).
@MainActor
final class HotKeyCenter {
    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Registers `hotKey`, or only removes the current one when it is nil.
    /// Returns false when macOS refuses the combination, for example because another app holds it.
    @discardableResult
    func register(_ hotKey: HotKey?) -> Bool {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        guard let hotKey else { return true }
        guard hotKey.isValid else { return false }
        installHandler()
        let identifier = EventHotKeyID(signature: 0x52726B75, id: 1)
        return RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, identifier, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
    }

    private func installHandler() {
        guard handlerRef == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
            // Carbon delivers application events on the main thread.
            MainActor.assumeIsolated { center.onPress?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }

    /// Carbon modifier flags for the modifier keys held in an AppKit event.
    static func modifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= HotKey.command }
        if flags.contains(.shift) { result |= HotKey.shift }
        if flags.contains(.option) { result |= HotKey.option }
        if flags.contains(.control) { result |= HotKey.control }
        return result
    }
}
