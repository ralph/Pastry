import AppKit

/// The glyph shown in the menu bar.
///
/// An SF Symbol rather than a bundled bitmap, so it tracks light and dark
/// mode, menu bar tinting and accessibility sizes on its own. Symbol images
/// are already template images, so nothing here sets `isTemplate`; the test
/// asserts it anyway, to catch a future swap to a non-template asset.
enum MenuBarIcon {
    static func image() -> NSImage? {
        NSImage(systemSymbolName: "scissors", accessibilityDescription: "Pastry")
    }
}
