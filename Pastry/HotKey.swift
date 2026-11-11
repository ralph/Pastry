import AppKit
import Carbon.HIToolbox

/// A key together with the modifiers held down with it.
///
/// One value for the whole combination, because three parts of the app need
/// to agree on it: Carbon registers it, the bezel treats taps of its key as
/// "one clip older", and letting go of its modifiers is what pastes. Feature
/// 9 lets the user change it, and a hand-written copy of ⇧⌘V anywhere else
/// would go on answering for a combination nobody chose any more.
struct HotKeyCombination: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    /// The combination Flycut used, and Pastry's default.
    static let commandShiftV = HotKeyCombination(
        keyCode: UInt16(kVK_ANSI_V),
        modifiers: [.command, .shift]
    )

    /// The same modifiers as Carbon's bits, which are not AppKit's.
    var carbonModifiers: UInt32 {
        var bits: UInt32 = 0
        if modifiers.contains(.command) { bits |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { bits |= UInt32(shiftKey) }
        if modifiers.contains(.option) { bits |= UInt32(optionKey) }
        if modifiers.contains(.control) { bits |= UInt32(controlKey) }
        return bits
    }
}

/// A system-wide hotkey.
///
/// Carbon rather than an `NSEvent` global monitor: registering needs no
/// Accessibility permission, and the key arrives before other applications
/// see it, so ⌘⇧V does not also reach whatever the user is typing in.
@MainActor
final class HotKey {
    /// The Carbon handler is a plain C function and cannot capture anything,
    /// so registered keys are looked up here by id.
    private static var registry: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private let id: UInt32
    private var reference: EventHotKeyRef?

    init?(combination: HotKeyCombination, onPress: @escaping () -> Void) {
        guard Self.installHandlerIfNeeded() else { return nil }

        id = Self.nextID
        Self.nextID += 1

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(combination.keyCode),
            combination.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            // Most often because another application already owns the
            // combination; nothing can be done about that from here.
            Log.clipboard.error("could not register the hotkey: status \(status)")
            return nil
        }

        self.reference = reference
        Self.registry[id] = onPress
    }

    /// Releases the key back to the system.
    ///
    /// There is no `deinit` doing this: Swift 6 will not let a nonisolated
    /// deinit touch the non-Sendable Carbon reference. In practice the hotkey
    /// is registered once and lives for the process, and the system reclaims
    /// it on exit; this exists for feature 9, which re-registers when the
    /// user changes the combination.
    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
        Self.registry[id] = nil
    }

    /// 'PSTR'. Carbon wants a four-character code and Swift has no literal
    /// for one.
    private static let signature = OSType(0x5053_5452)

    /// - Returns: whether the shared handler is installed. Without it a
    ///   registration still succeeds and then never fires, so a failure here
    ///   has to stop the caller rather than be noted and passed over.
    private static func installHandlerIfNeeded() -> Bool {
        guard !handlerInstalled else { return true }

        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var pressed = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressed
                )
                guard status == noErr else { return status }

                // The handler runs on the main thread; hop onto the main actor
                // so the callback can touch main-actor state.
                let id = pressed.id
                MainActor.assumeIsolated { HotKey.registry[id]?() }
                return noErr
            },
            1,
            &type,
            nil,
            nil
        )
        guard status == noErr else {
            Log.clipboard.error("could not install the hotkey handler: status \(status)")
            return false
        }

        handlerInstalled = true
        return true
    }
}
