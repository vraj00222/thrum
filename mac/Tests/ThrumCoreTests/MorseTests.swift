import XCTest
@testable import ThrumCore

/// Both this suite and web/lib/morse.test.ts read fixtures/morse-cases.json.
/// Divergence between the app and the web demo fails here or there.
struct Fixtures {
    static let json: [String: Any] = {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ThrumCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // mac
            .deletingLastPathComponent()   // repo root
        let url = root.appendingPathComponent("fixtures/morse-cases.json")
        let data = try! Data(contentsOf: url)
        return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    }()

    static func cases(_ key: String) -> [[String: Any]] {
        json[key] as? [[String: Any]] ?? []
    }
}

final class MorseCodeTests: XCTestCase {

    func testEncodeMatchesFixtures() {
        for c in Fixtures.cases("roundTrip") + Fixtures.cases("lowercaseInput") + Fixtures.cases("prosigns") {
            let text = c["text"] as! String
            XCTAssertEqual(MorseCode.encodeToString(text), c["morse"] as! String, "encoding \(text)")
        }
    }

    func testRoundTrip() {
        for c in Fixtures.cases("roundTrip") + Fixtures.cases("lowercaseInput") {
            let text = c["text"] as! String
            XCTAssertEqual(MorseCode.decode(MorseCode.encodeToString(text)), text.uppercased())
        }
    }

    func testTokenStream() {
        let names: [String: MorseToken] = [
            "dit": .dit, "dah": .dah,
            "intraGap": .intraGap, "charGap": .charGap, "wordGap": .wordGap
        ]
        for c in Fixtures.cases("tokenCounts") {
            let expected = (c["tokens"] as! [String]).map { names[$0]! }
            XCTAssertEqual(MorseCode.tokenize(c["text"] as! String), expected, "tokenizing \(c["text"]!)")
        }
    }

    /// A prosign is one character: no charGap may appear inside it.
    func testProsignsHaveNoInternalCharacterGap() {
        for prosign in ["<SOS>", "<AR>", "<BT>", "<KN>"] {
            let tokens = MorseCode.tokenize(prosign)
            XCTAssertFalse(tokens.contains(.charGap), "\(prosign) contains a character gap")
            XCTAssertFalse(tokens.contains(.wordGap), "\(prosign) contains a word gap")
        }
        // Same token count as the spelled-out version — a charGap is swapped for an
        // intraGap, not added — so the difference shows up in time, not in length.
        let timing = MorseTiming(wpm: 5)
        let prosign = timing.totalDuration(for: MorseCode.tokenize("<SOS>"))
        let spelled = timing.totalDuration(for: MorseCode.tokenize("SOS"))
        XCTAssertEqual(spelled - prosign, 4 * timing.unit, accuracy: 1e-12,
                       "two charGaps become intraGaps: 2 x (3 - 1) units saved")
    }

    func testUnsupportedCharacters() {
        for c in Fixtures.cases("unsupported") {
            let expected = Set((c["chars"] as! [String]).map { Character($0) })
            XCTAssertEqual(MorseCode.unsupported(in: c["text"] as! String), expected, "\(c["text"]!)")
        }
    }

    func testUnsupportedCharactersAreDroppedNotEncoded() {
        XCTAssertEqual(MorseCode.encodeToString("A%B"), ".- -...")
    }
}

final class MorseTimingTests: XCTestCase {

    func testStandardTimingMatchesFixtures() {
        for c in Fixtures.cases("timing") {
            let t = MorseTiming(wpm: c["wpm"] as! Double)
            let ms = { (token: MorseToken) in t.duration(of: token) * 1000 }
            XCTAssertEqual(t.unit * 1000, c["unitMS"] as! Double, accuracy: 0.001)
            XCTAssertEqual(ms(.dit), c["ditMS"] as! Double, accuracy: 0.001)
            XCTAssertEqual(ms(.dah), c["dahMS"] as! Double, accuracy: 0.001)
            XCTAssertEqual(ms(.charGap), c["charGapMS"] as! Double, accuracy: 0.001)
            XCTAssertEqual(ms(.wordGap), c["wordGapMS"] as! Double, accuracy: 0.001)
        }
    }

    func testDitIs240msAt5WPM() {
        let t = MorseTiming(wpm: 5)
        XCTAssertEqual(t.duration(of: .dit) * 1000, 240, accuracy: 1)
        XCTAssertEqual(t.duration(of: .dah), t.duration(of: .dit) * 3, accuracy: 1e-12)
        XCTAssertEqual(t.duration(of: .wordGap), t.duration(of: .dit) * 7, accuracy: 1e-12)
    }

    func testFarnsworthStretchesOnlyGaps() {
        for c in Fixtures.cases("farnsworth") {
            let t = MorseTiming(wpm: c["wpm"] as! Double, farnsworthWPM: c["farnsworthWPM"] as! Double)
            XCTAssertEqual(t.duration(of: .dit) * 1000, c["ditMS"] as! Double, accuracy: 0.001)
            XCTAssertEqual(t.duration(of: .dah) * 1000, c["dahMS"] as! Double, accuracy: 0.001)
            XCTAssertEqual(t.duration(of: .charGap) * 1000, c["charGapMS"] as! Double, accuracy: 0.001)
            XCTAssertEqual(t.duration(of: .wordGap) * 1000, c["wordGapMS"] as! Double, accuracy: 0.001)

            // Character speed is genuinely untouched.
            let plain = MorseTiming(wpm: c["wpm"] as! Double)
            XCTAssertEqual(t.duration(of: .dit), plain.duration(of: .dit))
            XCTAssertEqual(t.duration(of: .intraGap), plain.duration(of: .intraGap))
            XCTAssertGreaterThan(t.duration(of: .charGap), plain.duration(of: .charGap))

            // And the whole thing lands at the effective speed: PARIS takes 12s at 5 WPM.
            let paris = MorseCode.tokenize("PARIS") + [MorseToken.wordGap]
            XCTAssertEqual(t.totalDuration(for: paris),
                           60 / (c["farnsworthWPM"] as! Double), accuracy: 0.001)
        }
    }

    func testFarnsworthIgnoredWhenNotSlower() {
        let a = MorseTiming(wpm: 10, farnsworthWPM: 20)
        let b = MorseTiming(wpm: 10)
        XCTAssertEqual(a.duration(of: .charGap), b.duration(of: .charGap))
        XCTAssertEqual(a.effectiveWPM, 10)
        XCTAssertFalse(a.isFarnsworth)
    }
}

final class PulseShaperTests: XCTestCase {

    func testDitAndDahTapCountsAt5WPM() {
        let shaper = PulseShaper(tapInterval: 0.030)
        let timing = MorseTiming(wpm: 5)
        XCTAssertEqual(shaper.offsets(for: .dit, timing: timing).count, 8)
        XCTAssertEqual(shaper.offsets(for: .dah, timing: timing).count, 24)
    }

    func testGapsProduceNoTaps() {
        let shaper = PulseShaper()
        let timing = MorseTiming(wpm: 5)
        for gap in [MorseToken.intraGap, .charGap, .wordGap] {
            XCTAssertTrue(shaper.offsets(for: gap, timing: timing).isEmpty)
        }
    }

    /// Even a pulse shorter than one tap interval must fire once — silence would
    /// drop the symbol entirely rather than just render it badly.
    func testShortPulseStillTapsOnce() {
        let shaper = PulseShaper(tapInterval: 0.030)
        XCTAssertEqual(shaper.tapCount(for: 0.001), 1)
        XCTAssertEqual(shaper.offsets(for: .dit, timing: MorseTiming(wpm: 60)).count, 1)
    }

    func testOffsetsAreEvenlySpacedFromZero() {
        let shaper = PulseShaper(tapInterval: 0.030)
        let offsets = shaper.offsets(for: .dah, timing: MorseTiming(wpm: 5))
        XCTAssertEqual(offsets.first, 0)
        for (i, o) in offsets.enumerated() {
            XCTAssertEqual(o, Double(i) * 0.030, accuracy: 1e-12)
        }
    }
}
