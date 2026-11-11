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

extension HotKeyCombination {
    private enum Key {
        static let keyCode = "hotKeyKeyCode"
        static let modifiers = "hotKeyModifiers"
    }

    /// Reads a stored combination, or nil when there is none or what is there
    /// cannot be used. These are ordinary defaults keys and anything at all
    /// can have written them.
    init?(defaults: UserDefaults) {
        guard defaults.object(forKey: Key.keyCode) != nil,
              defaults.object(forKey: Key.modifiers) != nil else { return nil }
        let stored = HotKeyCombination(
            keyCode: UInt16(truncatingIfNeeded: defaults.integer(forKey: Key.keyCode)),
            modifiers: NSEvent.ModifierFlags(
                rawValue: UInt(bitPattern: defaults.integer(forKey: Key.modifiers))
            )
        )
        guard stored.isUsableAsHotKey else { return nil }
        self = stored
    }

    func write(to defaults: UserDefaults) {
        defaults.set(Int(keyCode), forKey: Key.keyCode)
        defaults.set(Int(bitPattern: modifiers.rawValue), forKey: Key.modifiers)
    }

    /// Shift alone does not count: ⇧V is a capital V, so such a hotkey would
    /// fire whenever the user typed that letter, in any application, and they
    /// could never type it again.
    var isUsableAsHotKey: Bool {
        !modifiers.intersection([.command, .control, .option]).isEmpty
    }

    /// As a Mac shortcut is always written: ⌃⌥⇧⌘ and then the key.
    var displayString: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + Self.keyName(for: keyCode)
    }

    /// The keys that carry no character of their own.
    private static let specialKeyNames: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_ANSI_KeypadEnter: "Enter",
        kVK_Tab: "Tab", kVK_Escape: "Escape", kVK_Delete: "Delete",
        kVK_ForwardDelete: "⌦", kVK_Home: "Home", kVK_End: "End",
        kVK_PageUp: "Page Up", kVK_PageDown: "Page Down",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12",
    ]

    /// Names a key by asking the keyboard layout the user is actually using.
    ///
    /// A key code is a physical position — the limitation the design spec
    /// records for the paste keystroke — so a fixed table would name the key
    /// wrongly for anyone not on ANSI. This asks what that position produces.
    private static func keyName(for keyCode: UInt16) -> String {
        if let special = specialKeyNames[Int(keyCode)] { return special }
        return translated(keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    private static func translated(_ keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layout = Unmanaged<CFData>.fromOpaque(data).takeUnretainedValue() as Data
        return layout.withUnsafeBytes { raw -> String? in
            guard let header = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                header, keyCode, UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeys, characters.count, &length, &characters
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length)
        }
    }
}
