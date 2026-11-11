import Testing
@testable import Pastry

@Suite("BezelSelection")
struct BezelSelectionTests {
    @Test("starts at the newest clip")
    func startsAtNewest() {
        #expect(BezelSelection(count: 5).position == 0)
    }

    @Test("older walks towards the end")
    func olderWalksForward() {
        var selection = BezelSelection(count: 3)
        selection.older()
        #expect(selection.position == 1)
        selection.older()
        #expect(selection.position == 2)
    }

    /// Wraparound is off by specification, so the ends are walls.
    @Test("older stops at the oldest clip")
    func olderStopsAtEnd() {
        var selection = BezelSelection(count: 2)
        selection.older()
        selection.older()
        selection.older()
        #expect(selection.position == 1)
    }

    @Test("newer stops at the newest clip")
    func newerStopsAtStart() {
        var selection = BezelSelection(count: 3)
        selection.newer()
        #expect(selection.position == 0)
    }

    @Test("ten at a time clamps rather than overshooting")
    func tenAtATimeClamps() {
        var selection = BezelSelection(count: 5)
        selection.tenOlder()
        #expect(selection.position == 4)
        selection.tenNewer()
        #expect(selection.position == 0)
    }

    @Test("first and last jump to the ends")
    func firstAndLast() {
        var selection = BezelSelection(count: 7)
        selection.last()
        #expect(selection.position == 6)
        selection.first()
        #expect(selection.position == 0)
    }

    @Test("jumps to a position, ignoring one out of range")
    func jumping() {
        var selection = BezelSelection(count: 4)
        selection.jump(to: 2)
        #expect(selection.position == 2)
        selection.jump(to: 9)
        #expect(selection.position == 2)
        selection.jump(to: -1)
        #expect(selection.position == 2)
    }

    /// A clip can be deleted from under the bezel, and capture continues
    /// while it is open.
    @Test("clamps when the history shrinks underneath it")
    func clampsWhenHistoryShrinks() {
        var selection = BezelSelection(count: 5)
        selection.last()
        selection.count = 2
        selection.clamp()
        #expect(selection.position == 1)
    }

    @Test("an empty history leaves no position")
    func emptyHistory() {
        var selection = BezelSelection(count: 0)
        #expect(selection.position == 0)
        selection.older()
        #expect(selection.position == 0)
        selection.clamp()
        #expect(selection.position == 0)
    }
}
