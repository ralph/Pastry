import Foundation
import Testing
@testable import Pastry

@Suite("Clip")
struct ClipTests {
    private func clip(_ text: String) -> Clip {
        Clip(text: text, appName: "Safari", appBundleURL: nil, date: Date(timeIntervalSince1970: 0))
    }

    @Test("shows short text unchanged")
    func shortTextUnchanged() {
        #expect(clip("hello world").displayText == "hello world")
    }

    @Test("collapses newlines and tabs into single spaces")
    func collapsesWhitespace() {
        #expect(clip("one\n\ttwo   three").displayText == "one two three")
    }

    @Test("trims surrounding whitespace")
    func trimsEnds() {
        #expect(clip("  padded  ").displayText == "padded")
    }

    @Test("truncates long text to the display length, ellipsis included")
    func truncatesLongText() {
        let display = clip(String(repeating: "a", count: 100)).displayText
        #expect(display.count == Clip.displayLength)
        #expect(display.hasSuffix("…"))
    }

    @Test("leaves text of exactly the display length alone")
    func exactLengthUntouched() {
        let text = String(repeating: "b", count: Clip.displayLength)
        #expect(clip(text).displayText == text)
    }

    @Test("renders whitespace-only text as empty")
    func whitespaceOnly() {
        #expect(clip(" \n\t ").displayText.isEmpty)
    }

    @Test("survives a Codable round trip")
    func codableRoundTrip() throws {
        let original = Clip(
            text: "round trip",
            appName: "Safari",
            appBundleURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            date: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Clip.self, from: data) == original)
    }
}
