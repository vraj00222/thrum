import Foundation

/// Picks the best engine that actually works and never leaves the caller holding nil.
/// Order: private actuator, public system haptics, silent. A Mac mini lands on
/// `.none` and the UI is required to say so rather than no-op quietly.
public enum HapticEngineResolver {

    public enum Outcome {
        case actuator(ActuatorHapticEngine)
        case system(SystemHapticEngine)
        case none(reason: String)

        public var engine: HapticEngine? {
            switch self {
            case .actuator(let e): return e
            case .system(let e): return e
            case .none: return nil
            }
        }

        public var descriptor: String {
            switch self {
            case .actuator(let e): return e.descriptor
            case .system(let e): return e.descriptor
            case .none: return "No haptics"
            }
        }

        /// Copy for the banner. States what happened and what to do; no apology.
        public var warning: String? {
            switch self {
            case .actuator: return nil
            case .system(let e):
                return e.isAvailable
                    ? "Using system haptics. Dits and dahs differ in length but not in texture."
                    : "Haptic feedback is off. Turn on Force Click and haptic feedback in System Settings > Trackpad."
            case .none(let reason):
                return reason
            }
        }
    }

    public static func resolve(preferPrivateAPI: Bool = true) -> Outcome {
        if preferPrivateAPI, let actuator = ActuatorHapticEngine() {
            do {
                try actuator.prepare()
                return .actuator(actuator)
            } catch {
                actuator.teardown()
            }
        }
        let system = SystemHapticEngine()
        if system.isAvailable {
            return .system(system)
        }
        if SystemHapticEngine.hapticsSuppressedInSystemSettings {
            return .system(system)   // present but muted — warning explains the fix
        }
        return .none(reason: "This Mac has no trackpad to tap. Playing sound and light instead.")
    }
}
