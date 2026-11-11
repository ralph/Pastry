import AppKit

/// The glyph shown in the menu bar.
///
/// Rendered from an SF Symbol as a template image so it tracks light and dark
/// mode, menu bar tinting and accessibility sizes without shipping bitmaps.
enum MenuBarIcon {
    static let symbolName = "scissors"

    static func image() -> NSImage? {
        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Pastry"
        )
        image?.isTemplate = true
        return image
    }
}
