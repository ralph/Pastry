import Carbon.HIToolbox

/// A system-wide hotkey.
///
/// Carbon rather than an `NSEvent` global monitor: registering needs no
/// Accessibility permission, and the key arrives before other applications
/// see it, so ⌘⇧V does not also reach whatever the user is typing in.
@MainActor
final class HotKey {
    /// Carbon's modifier bits, which are not AppKit's.
    enum Modifiers {
        static let commandShift = UInt32(cmdKey | shiftKey)
    }

    /// The Carbon handler is a plain C function and cannot capture anything,
    /// so registered keys are looked up here by id.
    private static var registry: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private let id: UInt32
    private var reference: EventHotKeyRef?

    init?(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void) {
        Self.installHandlerIfNeeded()

        id = Self.nextID
        Self.nextID += 1

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetEventDispatcherTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
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

    private static let signature: OSType = {
        let characters = Array("PSTR".utf8)
        return characters.reduce(OSType(0)) { ($0 << 8) | OSType($1) }
    }()

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
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
    }
}
