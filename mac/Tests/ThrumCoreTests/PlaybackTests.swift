import XCTest
@testable import ThrumCore
@testable import ThrumHaptics
@testable import ThrumPlayback

final class PlaybackClockTests: XCTestCase {

    /// The acceptance criterion: a 60-second message ends within 50ms of its
    /// computed duration. This runs in real time — it is the slow test, and it is
    /// the one that catches the drift the whole clock design exists to prevent.
    func testSixtySecondMessageFinishesWithin50ms() {
        let timing = MorseTiming(wpm: 5)
        // Repeat until the token stream is at least 60 seconds long.
        var text = ""
        var tokens = [MorseToken]()
        while timing.totalDuration(for: tokens) < 60 {
            text += "the quick brown fox jumps over the lazy dog "
            tokens = MorseCode.tokenize(text)
        }
        let total = timing.totalDuration(for: tokens)
        XCTAssertGreaterThan(total, 60)

        // One event per tap, exactly as playback would schedule them.
        let shaper = PulseShaper(tapInterval: 0.030)
        var events = [PlaybackClock.Event]()
        var t: TimeInterval = 0
        var fired = 0
        let counter = NSLock()
        for token in tokens {
            for offset in shaper.offsets(for: token, timing: timing) {
                events.append(PlaybackClock.Event(time: t + offset) {
                    counter.lock(); fired += 1; counter.unlock()
                })
            }
            t += timing.duration(of: token)
        }
        XCTAssertGreaterThan(events.count, 1000, "not enough taps to expose drift")

        let clock = PlaybackClock()
        let done = expectation(description: "clock finished")
        let start = DispatchTime.now()
        var wall: TimeInterval = 0
        clock.run(events: events, duration: total) { completed in
            wall = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e9
            XCTAssertTrue(completed)
            done.fulfill()
        }
        wait(for: [done], timeout: total + 10)

        XCTAssertEqual(wall, total, accuracy: 0.050,
                       "clock drifted \(String(format: "%.1f", (wall - total) * 1000))ms over \(Int(total))s")
        counter.lock()
        XCTAssertEqual(fired, events.count)
        counter.unlock()
    }

    func testStopEndsRunEarlyAndReportsIncomplete() {
        let clock = PlaybackClock()
        let done = expectation(description: "stopped")
        let events = (0..<100).map { i in PlaybackClock.Event(time: Double(i) * 0.05) {} }
        clock.run(events: events, duration: 5) { completed in
            XCTAssertFalse(completed)
            done.fulfill()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { clock.stop() }
        wait(for: [done], timeout: 3)
    }

    func testEventsFireInOrder() {
        let clock = PlaybackClock()
        let done = expectation(description: "ordered")
        var seen = [Int]()
        let lock = NSLock()
        let events = (0..<20).map { i in
            PlaybackClock.Event(time: Double(i) * 0.01) {
                lock.lock(); seen.append(i); lock.unlock()
            }
        }
        clock.run(events: events, duration: 0.2) { _ in done.fulfill() }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(seen, Array(0..<20))
    }
}

final class HapticEngineResolverTests: XCTestCase {

    /// With the private actuator out of the picture, resolution must still produce a
    /// usable engine rather than nil — a silent no-op is the one outcome we forbid.
    func testFallsBackToSystemEngineWhenActuatorUnavailable() {
        let outcome = HapticEngineResolver.resolve(preferPrivateAPI: false)
        switch outcome {
        case .system(let engine):
            XCTAssertEqual(engine.descriptor.isEmpty, false)
        case .none(let reason):
            XCTAssertFalse(reason.isEmpty, "a dead end must still explain itself")
        case .actuator:
            XCTFail("should not reach the private API when it was not preferred")
        }
        // Whatever we got, the UI has something honest to display.
        XCTAssertFalse(outcome.descriptor.isEmpty)
    }

    func testResolverPrefersActuatorWhenPresent() throws {
        let outcome = HapticEngineResolver.resolve(preferPrivateAPI: true)
        if case .actuator(let engine) = outcome {
            XCTAssertEqual(engine.descriptor, "Taptic Engine (MTActuator)")
            XCTAssertTrue(engine.isAvailable)
            XCTAssertNil(outcome.warning, "the good path shows no banner")
            XCTAssertNotEqual(engine.ditActuationID, engine.dahActuationID,
                              "dit and dah must differ in texture, not only length")
            engine.teardown()
            XCTAssertFalse(engine.isAvailable)
        } else {
            throw XCTSkip("no trackpad actuator on this machine — fallback path covered above")
        }
    }

    func testEveryOutcomeExceptActuatorExplainsItself() {
        let system = HapticEngineResolver.Outcome.system(SystemHapticEngine())
        XCTAssertNotNil(system.warning)
        XCTAssertNotNil(HapticEngineResolver.Outcome.none(reason: "no trackpad").warning)
    }
}

final class MorsePlayerTests: XCTestCase {

    func testLoadBuildsTokensAndStaysIdle() {
        let player = MorsePlayer(engine: nil)
        player.load("SOS")
        XCTAssertEqual(player.tokens, MorseCode.tokenize("SOS"))
        XCTAssertEqual(player.state, .idle)
        XCTAssertEqual(player.tokenIndex, -1)
        XCTAssertEqual(player.totalDuration, MorseTiming(wpm: 5).totalDuration(for: player.tokens))
    }

    func testEmptyTextDoesNotPlay() {
        let player = MorsePlayer(engine: nil)
        player.load("")
        player.play()
        XCTAssertEqual(player.state, .idle)
    }

    func testPlayReachesFinished() {
        let player = MorsePlayer(engine: nil)
        player.sidetoneEnabled = false
        player.timing = MorseTiming(wpm: 13)
        player.load("E")
        let done = expectation(description: "finished")
        withObservationTracking { _ = player.state } onChange: { }
        player.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(player.state, .finished)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }
}
