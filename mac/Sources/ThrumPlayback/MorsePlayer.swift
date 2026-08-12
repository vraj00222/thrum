import Foundation
import Observation
import ThrumCore
import ThrumHaptics

/// Turns text into a scheduled stream of taps, sidetone gates and UI updates.
@Observable
public final class MorsePlayer {

    public enum State: Equatable { case idle, playing, paused, finished }

    public private(set) var state: State = .idle
    /// Index into `tokens`. -1 before the first token fires.
    public private(set) var tokenIndex: Int = -1
    public private(set) var elapsed: TimeInterval = 0
    public private(set) var text: String = ""
    public private(set) var tokens: [MorseToken] = []

    public var timing = MorseTiming(wpm: 5) { didSet { if state != .playing { rebuild() } } }
    public var sidetoneEnabled = true
    public var hapticsEnabled = true

    /// Set by the app so the tape can flash in step with the taps.
    public var onPulse: ((Int, MorseToken) -> Void)?

    @ObservationIgnored private let clock = PlaybackClock()
    @ObservationIgnored private let shaper: PulseShaper
    @ObservationIgnored private let engine: HapticEngine?
    @ObservationIgnored private let sidetone: SidetoneGenerator
    @ObservationIgnored private var resumeAt: TimeInterval = 0
    @ObservationIgnored private var startedAt: Date?

    public var totalDuration: TimeInterval { timing.totalDuration(for: tokens) }

    /// Interpolated playhead position. `elapsed` only moves when a token fires, which
    /// is once every 240ms at 5 WPM — far too coarse to scroll a tape against.
    public var liveElapsed: TimeInterval {
        guard state == .playing, let started = startedAt else { return elapsed }
        return min(totalDuration, resumeAt + Date().timeIntervalSince(started))
    }

    public var tapInterval: TimeInterval {
        get { shaper.tapInterval }
        set { shaper.tapInterval = newValue }
    }

    public init(engine: HapticEngine?,
                sidetone: SidetoneGenerator = SidetoneGenerator(),
                shaper: PulseShaper = PulseShaper()) {
        self.engine = engine
        self.sidetone = sidetone
        self.shaper = shaper
    }

    public func load(_ text: String) {
        stop()
        self.text = text
        rebuild()
    }

    private func rebuild() {
        tokens = MorseCode.tokenize(text)
        tokenIndex = -1
        elapsed = 0
        resumeAt = 0
        state = tokens.isEmpty ? .idle : (state == .finished ? .idle : state)
    }

    public func play() {
        guard !tokens.isEmpty else { return }
        if state == .playing { return }
        if state == .finished { resumeAt = 0 }

        if sidetoneEnabled { try? sidetone.start() }
        state = .playing
        startedAt = Date()

        let from = resumeAt
        let events = buildEvents(startingAt: from)
        let total = totalDuration

        clock.run(events: events, duration: max(0, total - from)) { [weak self] completed in
            guard let self else { return }
            DispatchQueue.main.async {
                self.sidetone.off()
                if completed {
                    self.state = .finished
                    self.elapsed = total
                    self.resumeAt = 0
                }
            }
        }
    }

    public func pause() {
        guard state == .playing else { return }
        clock.stop()
        sidetone.off()
        resumeAt += Date().timeIntervalSince(startedAt ?? Date())
        elapsed = min(resumeAt, totalDuration)
        state = .paused
    }

    public func stop() {
        clock.stop()
        sidetone.off()
        sidetone.stop()
        state = tokens.isEmpty ? .idle : .idle
        tokenIndex = -1
        elapsed = 0
        resumeAt = 0
    }

    public func toggle() {
        switch state {
        case .playing: pause()
        case .idle, .paused, .finished: play()
        }
    }

    /// Flattens tokens into absolute-time events. Everything downstream of here is
    /// just "fire this at t seconds"; the clock owns the accuracy.
    private func buildEvents(startingAt offset: TimeInterval) -> [PlaybackClock.Event] {
        var events = [PlaybackClock.Event]()
        var t: TimeInterval = 0

        for (index, token) in tokens.enumerated() {
            let start = t
            let duration = timing.duration(of: token)
            t += duration
            if t <= offset { continue }

            let localStart = start - offset
            events.append(PlaybackClock.Event(time: max(0, localStart)) { [weak self] in
                guard let self else { return }
                if token.isPulse && self.sidetoneEnabled { self.sidetone.on() }
                DispatchQueue.main.async {
                    self.tokenIndex = index
                    self.elapsed = start
                    self.onPulse?(index, token)
                }
            })

            if token.isPulse {
                if hapticsEnabled, let engine {
                    let style: TapStyle = token == .dit ? .dit : .dah
                    for tap in shaper.offsets(for: token, timing: timing) {
                        let at = localStart + tap
                        guard at >= 0 else { continue }
                        events.append(PlaybackClock.Event(time: at) { engine.tap(style: style) })
                    }
                }
                events.append(PlaybackClock.Event(time: localStart + duration) { [weak self] in
                    self?.sidetone.off()
                })
            }
        }
        return events.sorted { $0.time < $1.time }
    }
}
