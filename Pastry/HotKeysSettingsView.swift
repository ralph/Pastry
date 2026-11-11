import SwiftUI

/// The Hotkeys tab: one recorder, for the combination that summons the bezel.
struct HotKeysSettingsView: View {
    @Bindable var preferences: Preferences

    /// Set when a keystroke was refused, and cleared by the next recording.
    /// Separate from `preferences.hotKeyIsUnavailable`, which is about a
    /// combination Carbon would not give us rather than one we would not
    /// accept.
    @State private var rejection: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Summon the bezel") {
                    KeyRecorder(title: preferences.hotKey.displayString, onOutcome: handle)
                        .frame(width: 160, height: 24)
                }
            } footer: {
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var footerText: String {
        if let rejection { return rejection }
        if preferences.hotKeyIsUnavailable {
            return "Another app is already using that combination, so the previous one is still in use."
        }
        return "Hold the modifiers and tap the key to walk back through the history. Let go to paste."
    }

    private func handle(_ outcome: HotKeyRecordingOutcome) {
        switch outcome {
        case .recorded(let combination):
            rejection = nil
            preferences.hotKey = combination
        case .cancelled:
            rejection = nil
        case .needsAModifier:
            rejection = "A hotkey needs ⌘, ⌃ or ⌥ — without one it would fire as you type."
        case .ignored:
            break
        }
    }
}
