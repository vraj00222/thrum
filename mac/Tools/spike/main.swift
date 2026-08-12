// Thrum Phase 0 spike: fire a train of trackpad taps so a human can tell us
// whether a 24-tap train reads as one pulse or as a machine gun.
//
// usage: swift run spike --taps 24 --interval 30 --actuation 1
//        swift run spike --sweep            # every actuation ID, announced
//        swift run spike --morse            # dit/dah/dit at 5 WPM
import AppKit
import Darwin

// MARK: - MultitouchSupport, resolved at runtime

// ponytail: dlsym instead of a bridging header + -framework link. Same six
// symbols, but a missing/renamed one degrades to a printed reason instead of a
// link error, which is exactly the fallback behaviour the real app needs.
private typealias FnDeviceCreate = @convention(c) () -> UnsafeMutableRawPointer?
private typealias FnDeviceID = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
private typealias FnActuatorCreate = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
private typealias FnActuatorOpen = @convention(c) (UnsafeMutableRawPointer) -> Int32
private typealias FnActuate = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32
private typealias FnActuatorClose = @convention(c) (UnsafeMutableRawPointer) -> Int32

final class Actuator {
    private let handle: UnsafeMutableRawPointer
    private let actuator: UnsafeMutableRawPointer
    private let actuate: FnActuate
    private let closeFn: FnActuatorClose
    let deviceID: UInt64

    init?() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let lib = dlopen(path, RTLD_LAZY) else {
            print("  dlopen failed: \(String(cString: dlerror()))")
            return nil
        }
        func sym<T>(_ name: String, _ type: T.Type) -> T? {
            guard let p = dlsym(lib, name) else { print("  missing symbol \(name)"); return nil }
            return unsafeBitCast(p, to: type)
        }
        guard let deviceCreate = sym("MTDeviceCreateDefault", FnDeviceCreate.self),
              let getID = sym("MTDeviceGetDeviceID", FnDeviceID.self),
              let actCreate = sym("MTActuatorCreateFromDeviceID", FnActuatorCreate.self),
              let actOpen = sym("MTActuatorOpen", FnActuatorOpen.self),
              let act = sym("MTActuatorActuate", FnActuate.self),
              let actClose = sym("MTActuatorClose", FnActuatorClose.self)
        else { return nil }

        guard let device = deviceCreate() else { print("  no multitouch device"); return nil }
        var id: UInt64 = 0
        let idResult = getID(device, &id)
        guard idResult == 0, id != 0 else { print("  MTDeviceGetDeviceID -> \(idResult)"); return nil }
        guard let a = actCreate(id) else { print("  MTActuatorCreateFromDeviceID(\(id)) -> null"); return nil }
        let openResult = actOpen(a)
        guard openResult == 0 else { print("  MTActuatorOpen -> \(openResult)"); return nil }

        self.handle = lib
        self.actuator = a
        self.actuate = act
        self.closeFn = actClose
        self.deviceID = id
    }

    func tap(_ actuationID: Int32) {
        _ = actuate(actuator, actuationID, 0, 0.0, 0.0)
    }

    deinit { _ = closeFn(actuator) }
}

// MARK: - Tap train

/// Absolute-deadline scheduling. Relative sleeps accumulate drift; a 24-tap
/// train at 30ms would land measurably long by the end of a word.
func train(taps: Int, intervalMS: Double, actuationID: Int32, actuator: Actuator?) {
    let start = DispatchTime.now().uptimeNanoseconds
    let step = intervalMS * 1_000_000
    for i in 0..<taps {
        let target = start + UInt64(Double(i) * step)
        let now = DispatchTime.now().uptimeNanoseconds
        if target > now { usleep(useconds_t((target - now) / 1000)) }
        if let actuator {
            actuator.tap(actuationID)
        } else {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    let expected = Double(taps - 1) * intervalMS
    print(String(format: "  %d taps @ %.0fms id=%d — %.1fms (drift %+.1fms)",
                 taps, intervalMS, actuationID, elapsed, elapsed - expected))
}

func arg(_ name: String, _ fallback: Double) -> Double {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--\(name)"), i + 1 < args.count,
          let v = Double(args[i + 1]) else { return fallback }
    return v
}

// MARK: - Main

let flags = Set(CommandLine.arguments)
let actuator = Actuator()
if let actuator {
    print("engine: MTActuator (device \(actuator.deviceID))")
} else {
    print("engine: NSHapticFeedbackManager fallback — private actuator unavailable")
    print("        (if System Settings > Trackpad > 'Force Click and haptic feedback' is off, you'll feel nothing)")
}
print("put a finger on the trackpad now.\n")
usleep(1_500_000)

if flags.contains("--sweep") {
    for id: Int32 in [1, 2, 3, 4, 5, 6, 15, 16] {
        print("actuation \(id):")
        train(taps: 24, intervalMS: 30, actuationID: id, actuator: actuator)
        usleep(1_200_000)
    }
} else if flags.contains("--morse") {
    // 5 WPM: unit = 240ms. dit = 8 taps, dah = 24 taps, intra-char gap = 8 slots.
    let id = Int32(arg("actuation", 1))
    for (name, taps) in [("dit", 8), ("dah", 24), ("dit", 8)] {
        print("\(name):")
        train(taps: taps, intervalMS: 30, actuationID: id, actuator: actuator)
        usleep(240_000)
    }
} else {
    train(taps: Int(arg("taps", 8)),
          intervalMS: arg("interval", 30),
          actuationID: Int32(arg("actuation", 1)),
          actuator: actuator)
}
