import Foundation

/// One element of a Morse stream: a pulse you feel, or a gap you don't.
public enum MorseToken: Equatable, Sendable {
    case dit, dah
    case intraGap, charGap, wordGap

    public var isPulse: Bool { self == .dit || self == .dah }

    /// Length in dit-units. The whole timing model is this table times `unit`.
    public var units: Double {
        switch self {
        case .dit, .intraGap: return 1
        case .dah, .charGap: return 3
        case .wordGap: return 7
        }
    }

    public var symbol: Character? {
        switch self {
        case .dit: return "."
        case .dah: return "-"
        default: return nil
        }
    }
}
