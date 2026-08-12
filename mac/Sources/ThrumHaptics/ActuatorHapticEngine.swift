import Foundation

/// Private API: MultitouchSupport's MTActuator. Actuation IDs have genuinely
/// different textures, which is what lets dit and dah *feel* different rather than
/// merely differ in length.
///
/// Symbols are resolved with dlsym rather than linked, so a rename on some future
/// macOS point release degrades to `init` returning nil — and the resolver falls
/// back to the public engine — instead of failing to launch. See DECISIONS.md.
public final class ActuatorHapticEngine: HapticEngine {

    private typealias FnDeviceCreate = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias FnDeviceID = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
    private typealias FnActuatorCreate = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias FnActuatorOpen = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias FnActuate = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32
    private typealias FnActuatorClose = @convention(c) (UnsafeMutableRawPointer) -> Int32

    /// Valid actuation IDs. 1–3 are light, 4–6 heavier, 15/16 distinct again.
    public static let actuationIDs: [Int32] = [1, 2, 3, 4, 5, 6, 15, 16]

    public var ditActuationID: Int32 = 3
    public var dahActuationID: Int32 = 6
    public var accentActuationID: Int32 = 16

    private let actuator: UnsafeMutableRawPointer
    private let actuateFn: FnActuate
    private let closeFn: FnActuatorClose
    private var open = false
    public let deviceID: UInt64

    public init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let lib = dlopen(path, RTLD_LAZY) else { return nil }
        func sym<T>(_ name: String, _ type: T.Type) -> T? {
            dlsym(lib, name).map { unsafeBitCast($0, to: type) }
        }
        guard let deviceCreate = sym("MTDeviceCreateDefault", FnDeviceCreate.self),
              let getID = sym("MTDeviceGetDeviceID", FnDeviceID.self),
              let actCreate = sym("MTActuatorCreateFromDeviceID", FnActuatorCreate.self),
              let actOpen = sym("MTActuatorOpen", FnActuatorOpen.self),
              let act = sym("MTActuatorActuate", FnActuate.self),
              let actClose = sym("MTActuatorClose", FnActuatorClose.self),
              let device = deviceCreate()
        else { return nil }

        var id: UInt64 = 0
        guard getID(device, &id) == 0, id != 0,
              let handle = actCreate(id),
              actOpen(handle) == 0
        else { return nil }

        self.actuator = handle
        self.actuateFn = act
        self.closeFn = actClose
        self.deviceID = id
        self.open = true
    }

    public var isAvailable: Bool { open }
    public var descriptor: String { "Taptic Engine (MTActuator)" }

    /// The first actuation after opening costs 5–9ms; every one after is ~0.2ms.
    /// Burn that cost here so the first dit of a message doesn't land late.
    public func prepare() throws {
        guard open else { throw HapticEngineError.actuatorUnavailable("actuator closed") }
        _ = actuateFn(actuator, ditActuationID, 0, 0, 0)
    }

    public func tap(style: TapStyle) {
        guard open else { return }
        let id: Int32
        switch style {
        case .dit: id = ditActuationID
        case .dah: id = dahActuationID
        case .accent: id = accentActuationID
        }
        _ = actuateFn(actuator, id, 0, 0, 0)
    }

    public func teardown() {
        guard open else { return }
        open = false
        _ = closeFn(actuator)
    }

    deinit { teardown() }
}
