import Foundation

/// PARIS-standard timing, with optional Farnsworth spacing.
///
/// `wpm` is always the *character* speed. `farnsworthWPM`, when set and slower,
/// is the effective speed: characters stay crisp and only the gaps between them
/// stretch. That's what makes it a learning tool rather than just a slow sender.
public struct MorseTiming: Equatable, Sendable {
    public var wpm: Double
    public var farnsworthWPM: Double?

    public init(wpm: Double = 5, farnsworthWPM: Double? = nil) {
        self.wpm = wpm
        self.farnsworthWPM = farnsworthWPM
    }

    /// One dit, in seconds. 1.2 because PARIS is 50 units and 60/50 = 1.2.
    public var unit: TimeInterval { 1.2 / wpm }

    /// The speed a whole message actually lands at.
    public var effectiveWPM: Double {
        guard let f = farnsworthWPM, f < wpm else { return wpm }
        return f
    }

    public var isFarnsworth: Bool {
        guard let f = farnsworthWPM else { return false }
        return f < wpm
    }

    /// ARRL Farnsworth: total padding per average word, spread over the 19 units
    /// of spacing in PARIS (4 inter-character gaps of 3 + one word gap of 7).
    /// Degrades exactly to standard timing when character and effective speed match.
    private var spacingUnit: TimeInterval {
        guard isFarnsworth, let s = farnsworthWPM else { return unit }
        let c = wpm
        let totalDelay = (60 * c - 37.2 * s) / (s * c)
        return totalDelay / 19
    }

    public func duration(of token: MorseToken) -> TimeInterval {
        switch token {
        case .dit, .dah, .intraGap:
            return token.units * unit          // inside a character: never stretched
        case .charGap, .wordGap:
            return token.units * spacingUnit
        }
    }

    public func totalDuration(for tokens: [MorseToken]) -> TimeInterval {
        tokens.reduce(0) { $0 + duration(of: $1) }
    }
}
