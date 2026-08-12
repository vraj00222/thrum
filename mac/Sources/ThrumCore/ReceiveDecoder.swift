import Foundation

/// Decodes a human tapping in rhythm back into text. This is what makes Thrum a
/// trainer rather than a toy: you can send, and you can be heard.
///
/// Nobody taps a clean 240ms. The reference dit length starts at the configured
/// speed and then chases what you actually do, so the envelope drifts with you
/// instead of rejecting you for being human.
public final class ReceiveDecoder {

    public private(set) var tokens: [MorseToken] = []
    /// Reference dit length, in seconds. Adapts as you tap.
    public private(set) var ditReference: TimeInterval

    private let configured: TimeInterval
    /// Widens or narrows every threshold at once. 1.0 is the classic 2x/5x envelope.
    public var tolerance: Double = 1.0

    public init(timing: MorseTiming = MorseTiming(wpm: 5)) {
        self.configured = timing.unit
        self.ditReference = timing.unit
    }

    public var estimatedWPM: Double { 1.2 / ditReference }

    /// Morse string built so far, e.g. "... --- ...".
    public var morse: String {
        var out = ""
        for token in tokens {
            switch token {
            case .dit: out += "."
            case .dah: out += "-"
            case .intraGap: break
            case .charGap: out += " "
            case .wordGap: out += " / "
            }
        }
        return out
    }

    public var text: String { MorseCode.decode(morse) }

    /// One key press, held for `duration`.
    public func press(duration: TimeInterval) {
        let isDah = duration > ditReference * 2 * tolerance
        tokens.append(isDah ? .dah : .dit)

        // Only dits refine the reference — dahs are 3x and would drag it long.
        // Clamped so one accidental 2-second press can't destroy the envelope.
        if !isDah {
            let blended = ditReference * 0.7 + duration * 0.3
            ditReference = min(max(blended, configured / 4), configured * 4)
        }
    }

    /// The silence before the next press.
    public func gap(_ duration: TimeInterval) {
        guard !tokens.isEmpty, tokens.last?.isPulse == true || tokens.last != nil else { return }
        if duration > ditReference * 5 * tolerance {
            tokens.append(.wordGap)
        } else if duration > ditReference * 2 * tolerance {
            tokens.append(.charGap)
        } else {
            tokens.append(.intraGap)
        }
    }

    /// Call when the operator stops tapping for longer than a word gap, to close
    /// the final character. Without this the last letter never resolves.
    public func flush() {
        if tokens.last?.isPulse == true { tokens.append(.charGap) }
    }

    public func reset() {
        tokens.removeAll()
        ditReference = configured
    }

    public func undoLast() {
        while let last = tokens.last, !last.isPulse { tokens.removeLast() }
        if !tokens.isEmpty { tokens.removeLast() }
    }
}
