import Foundation
import Observation
import ThrumCore

/// Everything the user can turn. Persisted on write, restored at launch.
@Observable
final class PlaybackSettings {

    /// Haptically, past ~13 WPM a dit is two taps and a dah is six — the skin can't
    /// tell them apart. The cap is a real limit of the hardware, not a preference.
    static let minWPM = 3.0
    static let maxWPM = 13.0

    var wpm: Double = 5 { didSet { save() } }
    var farnsworthEnabled = false { didSet { save() } }
    /// Character speed under Farnsworth. Characters stay crisp; the gaps stretch.
    var characterWPM: Double = 15 { didSet { save() } }
    var sidetoneEnabled = true { didSet { save() } }
    var hapticsEnabled = true { didSet { save() } }
    var tapIntervalMS: Double = 30 { didSet { save() } }
    var ditActuationID: Int = 3 { didSet { save() } }
    var dahActuationID: Int = 6 { didSet { save() } }
    var flashEnabled = true { didSet { save() } }

    /// Under Farnsworth, `wpm` is the effective speed and characters ride at
    /// `characterWPM`. Without it, both are the same.
    var timing: MorseTiming {
        farnsworthEnabled
            ? MorseTiming(wpm: max(characterWPM, wpm), farnsworthWPM: wpm)
            : MorseTiming(wpm: wpm)
    }

    var ditMilliseconds: Double { timing.unit * 1000 }

    private var loading = false

    init() {
        loading = true
        let d = UserDefaults.standard
        if d.object(forKey: "wpm") != nil {
            wpm = d.double(forKey: "wpm")
            farnsworthEnabled = d.bool(forKey: "farnsworthEnabled")
            characterWPM = d.double(forKey: "characterWPM")
            sidetoneEnabled = d.bool(forKey: "sidetoneEnabled")
            hapticsEnabled = d.bool(forKey: "hapticsEnabled")
            tapIntervalMS = d.double(forKey: "tapIntervalMS")
            ditActuationID = d.integer(forKey: "ditActuationID")
            dahActuationID = d.integer(forKey: "dahActuationID")
            flashEnabled = d.bool(forKey: "flashEnabled")
        }
        loading = false
    }

    private func save() {
        guard !loading else { return }
        let d = UserDefaults.standard
        d.set(wpm, forKey: "wpm")
        d.set(farnsworthEnabled, forKey: "farnsworthEnabled")
        d.set(characterWPM, forKey: "characterWPM")
        d.set(sidetoneEnabled, forKey: "sidetoneEnabled")
        d.set(hapticsEnabled, forKey: "hapticsEnabled")
        d.set(tapIntervalMS, forKey: "tapIntervalMS")
        d.set(ditActuationID, forKey: "ditActuationID")
        d.set(dahActuationID, forKey: "dahActuationID")
        d.set(flashEnabled, forKey: "flashEnabled")
    }
}
