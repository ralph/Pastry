import Foundation

/// Where the bezel is looking in the history.
///
/// Lives here rather than in `ClipStore` — contrary to the spec's first
/// sketch — because it is one piece of UI's cursor, not a property of the
/// history: the menu has no such position, and the store would otherwise grow
/// clamping rules that exist only for the bezel.
struct BezelSelection: Equatable {
    private(set) var position = 0

    /// How many clips there are. Set it when the history changes, then
    /// `clamp()`.
    var count: Int

    init(count: Int) {
        self.count = count
    }

    private var lastIndex: Int { max(0, count - 1) }

    // Wraparound is off by specification, so every move stops at the ends.
    mutating func older() { position = min(position + 1, lastIndex) }
    mutating func newer() { position = max(position - 1, 0) }
    mutating func tenOlder() { position = min(position + 10, lastIndex) }
    mutating func tenNewer() { position = max(position - 10, 0) }
    mutating func first() { position = 0 }
    mutating func last() { position = lastIndex }

    mutating func jump(to index: Int) {
        guard (0..<count).contains(index) else { return }
        position = index
    }

    /// Call after the history changes underneath the bezel: a clip can be
    /// deleted from it, and capture continues while it is open.
    mutating func clamp() { position = min(position, lastIndex) }
}
