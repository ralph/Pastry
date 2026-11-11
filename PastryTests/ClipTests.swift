import Foundation
import Testing
@testable import Pastry

@Suite("Clip")
struct ClipTests {
    @Test("shows short text unchanged")
    func shortTextUnchanged() {
        #expect(Clip.fixture("hello world").displayText == "hello world")
    }

    @Test("collapses newlines and tabs into single spaces")
    func collapsesWhitespace() {
        #expect(Clip.fixture("one\n\ttwo   three").displayText == "one two three")
    }

    @Test("trims surrounding whitespace")
    func trimsEnds() {
        #expect(Clip.fixture("  padded  ").displayText == "padded")
    }

    @Test("truncates long text to the display length, ellipsis included")
    func truncatesLongText() {
        let display = Clip.fixture(String(repeating: "a", count: 100)).displayText
        #expect(display.count == Clip.displayLength)
        #expect(display.hasSuffix("…"))
    }

    @Test("leaves text of exactly the display length alone")
    func exactLengthUntouched() {
        let text = String(repeating: "b", count: Clip.displayLength)
        #expect(Clip.fixture(text).displayText == text)
    }

    @Test("truncates text one character over the limit")
    func oneOverTheLimit() {
        let text = String(repeating: "c", count: Clip.displayLength + 1)
        let display = Clip.fixture(text).displayText
        #expect(display.count == Clip.displayLength)
        #expect(display.hasSuffix("…"))
    }

    @Test("counts a collapsed run of whitespace towards the limit, not the original")
    func collapsedLengthDrivesTruncation() {
        // 40 words of one letter collapse to 79 characters, so this truncates
        // even though no single word is long.
        let text = (0..<40).map { _ in "x" }.joined(separator: "     ")
        let display = Clip.fixture(text).displayText
        #expect(display.count == Clip.displayLength)
        #expect(display.hasPrefix("x x x"))
    }

    /// A combining mark that lands straight after an inserted space joins it
    /// into one grapheme, so counting appends rather than the string itself
    /// over-counted and truncated text that actually fitted.
    @Test("does not truncate text that fits once combining marks are joined")
    func combiningMarkAfterCollapsedSpace() {
        let text = "a\n\u{0301}" + String(repeating: "b", count: 38)
        let display = Clip.fixture(text).displayText
        #expect(display.count == Clip.displayLength)
        #expect(!display.hasSuffix("…"))
    }

    @Test("renders whitespace-only text as empty")
    func whitespaceOnly() {
        #expect(Clip.fixture(" \n\t ").displayText.isEmpty)
    }

    @Test("builds its source fields from a SourceApp")
    func buildsFromSourceApp() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let clip = Clip(
            text: "hi",
            source: SourceApp(name: "Safari", bundleURL: url),
            date: Date(timeIntervalSince1970: 0)
        )
        #expect(clip.appName == "Safari")
        #expect(clip.appBundleURL == url)
    }

    @Test("tolerates an unidentifiable source application")
    func buildsFromMissingSourceApp() {
        let clip = Clip(text: "hi", source: nil, date: Date(timeIntervalSince1970: 0))
        #expect(clip.appName == nil)
        #expect(clip.appBundleURL == nil)
    }

    @Test("survives a Codable round trip")
    func codableRoundTrip() throws {
        let original = Clip.fixture(
            "round trip",
            bundleURL: URL(fileURLWithPath: "/Applications/Safari.app"),
            at: 1_700_000_000
        )
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(Clip.self, from: data) == original)
    }
}
