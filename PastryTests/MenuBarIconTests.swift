import AppKit
import Testing
@testable import Pastry

@Suite("MenuBarIcon")
struct MenuBarIconTests {
    @Test("resolves the system symbol on this OS")
    func resolvesSymbol() {
        #expect(MenuBarIcon.image() != nil)
    }

    @Test("is a template image so it follows menu bar appearance")
    func isTemplate() {
        #expect(MenuBarIcon.image()?.isTemplate == true)
    }
}
