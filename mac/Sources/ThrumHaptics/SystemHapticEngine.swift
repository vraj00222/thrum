import AppKit

/// Public API. App Store legal, no intensity control, and — the part that bites —
/// it silently does nothing when "Force Click and haptic feedback" is off. We check.
public final class SystemHapticEngine: HapticEngine {

    public init() {}

    /// The System Settings toggle writes `ForceSuppressed` into the trackpad prefs.
    /// True means the user turned haptics off and `perform` is a no-op.
    public static var hapticsSuppressedInSystemSettings: Bool {
        let domains = [
            "com.apple.AppleMultitouchTrackpad",
            "com.apple.driver.AppleBluetoothMultitouch.trackpad"
        ]
        return domains.contains { domain in
            UserDefaults.standard.persistentDomain(forName: domain)?["ForceSuppressed"] as? Bool == true
        }
    }

    public var isAvailable: Bool { !Self.hapticsSuppressedInSystemSettings }

    public var descriptor: String {
        isAvailable ? "System haptics (NSHapticFeedbackManager)"
                    : "System haptics — turned off in System Settings"
    }

    public func prepare() throws {
        if Self.hapticsSuppressedInSystemSettings {
            throw HapticEngineError.actuatorUnavailable(
                "Force Click and haptic feedback is off in System Settings > Trackpad")
        }
    }

    public func tap(style: TapStyle) {
        // No intensity control here — every style is the same generic tap, which is
        // exactly why the private engine is the default.
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    public func teardown() {}
}
