import Foundation

/// Fires timestamped events on one dedicated queue, every deadline computed as an
/// absolute offset from a single captured start time.
///
/// Not `Timer`, and not chained relative `asyncAfter`: both accumulate error per
/// hop, and at ~33 taps a second a long message desyncs from the sidetone audibly
/// inside twenty seconds. Absolute deadlines mean a late tap is late once, not
/// late forever.
public final class PlaybackClock {

    public struct Event {
        public let time: TimeInterval
        public let action: () -> Void
        public init(time: TimeInterval, action: @escaping () -> Void) {
            self.time = time
            self.action = action
        }
    }

    private let queue = DispatchQueue(label: "app.thrum.clock", qos: .userInteractive)
    private let lock = NSLock()
    private var generation = 0

    public init() {}

    public var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }
    private var running = false

    /// - Parameters:
    ///   - events: must be sorted by `time`.
    ///   - onFinish: `true` if the run completed, `false` if it was stopped.
    ///
    /// Each event's action runs on the clock queue. Keep them short — they run
    /// between taps, and anything slow here shows up as jitter you can feel.
    public func run(events: [Event],
                    duration: TimeInterval,
                    onFinish: @escaping (Bool) -> Void) {
        lock.lock()
        generation += 1
        let myGeneration = generation
        running = true
        lock.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            let base = DispatchTime.now()

            func cancelled() -> Bool {
                self.lock.lock(); defer { self.lock.unlock() }
                return self.generation != myGeneration
            }

            for event in events {
                if cancelled() { onFinish(false); return }
                self.wait(until: base, offset: event.time)
                if cancelled() { onFinish(false); return }
                event.action()
            }
            // Hold for the tail of the last token so `elapsed` reaches `duration`.
            self.wait(until: base, offset: duration)

            self.lock.lock()
            let stillMine = self.generation == myGeneration
            if stillMine { self.running = false }
            self.lock.unlock()
            onFinish(stillMine)
        }
    }

    public func stop() {
        lock.lock()
        generation += 1
        running = false
        lock.unlock()
    }

    /// Sleep most of the way, then spin the last 2ms. `usleep` alone overshoots by
    /// a millisecond or two per call, which is fine once and visible 2000 times.
    private func wait(until base: DispatchTime, offset: TimeInterval) {
        let deadline = base.uptimeNanoseconds + UInt64(max(0, offset) * 1_000_000_000)
        while true {
            let now = DispatchTime.now().uptimeNanoseconds
            guard deadline > now else { return }
            let remaining = deadline - now
            if remaining > 2_000_000 {
                usleep(useconds_t((remaining - 2_000_000) / 1000))
            }
        }
    }
}
