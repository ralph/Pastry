import SwiftUI

/// The Preferences window's content.
struct PreferencesView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        TabView {
            GeneralSettingsView(preferences: preferences)
                .tabItem { Label("General", systemImage: "gearshape") }
            HotKeysSettingsView(preferences: preferences)
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
        }
        .padding(20)
        .frame(width: 440)
    }
}

struct GeneralSettingsView: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Form {
            Section {
                // Steppers rather than free text fields: the range is the
                // whole of the validation, and a stepper cannot express a
                // value outside it.
                Stepper(value: $preferences.rememberCount, in: Preferences.countRange) {
                    LabeledContent("Remember", value: "\(preferences.rememberCount) clippings")
                }
                Stepper(value: $preferences.displayCount, in: Preferences.countRange) {
                    LabeledContent("Display in menu", value: "\(preferences.displayCount) clippings")
                }
            } footer: {
                Text("Lowering Remember discards the oldest clippings straight away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch Pastry at login", isOn: $preferences.launchAtLogin)
                if preferences.loginItemNeedsApproval {
                    // macOS answers register() with "waiting for approval"
                    // rather than an error, and nothing happens at login
                    // until the user allows it — so say so rather than
                    // showing a toggle that looks done.
                    HStack(spacing: 8) {
                        Text("Waiting for your approval in System Settings.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("Open…") { preferences.openLoginItemSettings() }
                            .buttonStyle(.link)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
