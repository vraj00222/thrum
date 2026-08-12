import Foundation

public enum TapStyle: Equatable, Sendable {
    case dit, dah, accent
}

public protocol HapticEngine: AnyObject {
    var isAvailable: Bool { get }
    /// Shown verbatim in Settings, so it has to name the real mechanism.
    var descriptor: String { get }
    func prepare() throws
    func tap(style: TapStyle)
    func teardown()
}

public enum HapticEngineError: LocalizedError {
    case actuatorUnavailable(String)
    case noTrackpad

    public var errorDescription: String? {
        switch self {
        case .actuatorUnavailable(let why):
            return "The Taptic Engine didn't open: \(why)"
        case .noTrackpad:
            return "This Mac has no trackpad. Thrum will play sound and light instead."
        }
    }
}
