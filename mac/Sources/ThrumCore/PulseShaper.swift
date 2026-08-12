import Foundation

/// The trackpad has a linear resonant actuator: discrete taps, no sustain. A dah
/// isn't a longer buzz, it's more taps. This turns a token's duration into the
/// tap offsets that simulate it.
public final class PulseShaper {
    /// Time between taps within one pulse. The knob that decides whether a train
    /// fuses into one sensation or reads as a machine gun — tune by feel, not theory.
    public var tapInterval: TimeInterval

    public init(tapInterval: TimeInterval = 0.030) {
        self.tapInterval = tapInterval
    }

    public func tapCount(for duration: TimeInterval) -> Int {
        max(1, Int((duration / tapInterval).rounded()))
    }

    /// Offsets from the start of the token. Gaps produce nothing.
    public func offsets(for token: MorseToken, timing: MorseTiming) -> [TimeInterval] {
        guard token.isPulse else { return [] }
        let count = tapCount(for: timing.duration(of: token))
        return (0..<count).map { Double($0) * tapInterval }
    }
}
