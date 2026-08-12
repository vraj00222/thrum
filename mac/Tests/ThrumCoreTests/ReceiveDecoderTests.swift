import XCTest
@testable import ThrumCore

final class ReceiveDecoderTests: XCTestCase {

    /// Taps a message at a given speed with a jitter factor applied to every
    /// interval, the way a person actually keys.
    private func tap(_ text: String, wpm: Double, jitter: Double = 0) -> ReceiveDecoder {
        let timing = MorseTiming(wpm: wpm)
        let decoder = ReceiveDecoder(timing: timing)
        var wobble = 0
        func skew(_ t: TimeInterval) -> TimeInterval {
            wobble += 1
            let sign: Double = wobble % 2 == 0 ? 1 : -1
            return t * (1 + sign * jitter)
        }
        var pendingGap: TimeInterval?
        for token in MorseCode.tokenize(text) {
            if token.isPulse {
                if let gap = pendingGap { decoder.gap(skew(gap)); pendingGap = nil }
                decoder.press(duration: skew(timing.duration(of: token)))
            } else {
                pendingGap = timing.duration(of: token)
            }
        }
        decoder.flush()
        return decoder
    }

    func testDecodesCleanSOS() {
        XCTAssertEqual(tap("SOS", wpm: 5).text, "SOS")
    }

    /// The acceptance criterion: spacebar tapping of SOS at 5 WPM decodes.
    func testDecodesSOSAt5WPMWithHumanJitter() {
        for jitter in [0.0, 0.1, 0.2, 0.3] {
            XCTAssertEqual(tap("SOS", wpm: 5, jitter: jitter).text, "SOS",
                           "failed at \(Int(jitter * 100))% jitter")
        }
    }

    func testDecodesWordsAndSpaces() {
        XCTAssertEqual(tap("HELLO WORLD", wpm: 5, jitter: 0.15).text, "HELLO WORLD")
    }

    func testDecodesAtOtherSpeeds() {
        for wpm in [5.0, 8.0, 13.0] {
            XCTAssertEqual(tap("CQ DE THRUM", wpm: wpm, jitter: 0.15).text, "CQ DE THRUM",
                           "failed at \(wpm) WPM")
        }
    }

    /// Someone who sets 5 WPM but actually keys at 9 should still be understood.
    func testAdaptsWhenOperatorTapsFasterThanConfigured() {
        let timing = MorseTiming(wpm: 5)
        let actual = MorseTiming(wpm: 9)
        let decoder = ReceiveDecoder(timing: timing)
        var pendingGap: TimeInterval?
        for token in MorseCode.tokenize("SOS") {
            if token.isPulse {
                if let gap = pendingGap { decoder.gap(gap); pendingGap = nil }
                decoder.press(duration: actual.duration(of: token))
            } else {
                pendingGap = actual.duration(of: token)
            }
        }
        decoder.flush()
        XCTAssertEqual(decoder.text, "SOS")
        XCTAssertGreaterThan(decoder.estimatedWPM, 5)
    }

    func testResetClearsEverything() {
        let decoder = tap("SOS", wpm: 5)
        decoder.reset()
        XCTAssertTrue(decoder.tokens.isEmpty)
        XCTAssertEqual(decoder.text, "")
    }

    func testUndoRemovesOneSymbolAndItsGap() {
        let decoder = tap("E", wpm: 5)
        XCTAssertEqual(decoder.text, "E")
        decoder.undoLast()
        XCTAssertTrue(decoder.tokens.isEmpty)
    }

    /// A stray two-second press must not poison the envelope for everything after.
    func testWildPressDoesNotDestroyReference() {
        let decoder = ReceiveDecoder(timing: MorseTiming(wpm: 5))
        decoder.press(duration: 2.0)
        XCTAssertLessThanOrEqual(decoder.ditReference, 0.240 * 4)
        XCTAssertGreaterThanOrEqual(decoder.ditReference, 0.240 / 4)
    }
}
