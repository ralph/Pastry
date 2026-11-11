import AppKit
import Testing
@testable import Pastry

@Suite("StatusMenu")
@MainActor
struct StatusMenuTests {
    @Test("offers a single Quit item wired to terminate on Command-Q")
    func quitItem() {
        let menu = StatusMenu.make()
        #expect(menu.items.count == 1)

        let item = menu.items.first
        #expect(item?.title == "Quit Pastry")
        #expect(item?.action == #selector(NSApplication.terminate(_:)))
        #expect(item?.keyEquivalent == "q")
    }
}
