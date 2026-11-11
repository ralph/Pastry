import AppKit
import Testing
@testable import Pastry

@Suite("MenuBarIcon")
struct MenuBarIconTests {
    @Test("resolves to a template image on this OS")
    func resolvesTemplateImage() {
        let image = MenuBarIcon.image()
        #expect(image != nil)
        #expect(image?.isTemplate == true)
    }
}
