import SwiftUI
import ThrumCore
import ThrumHaptics
import ThrumPlayback

struct SettingsView: View {
    @Bindable var settings: PlaybackSettings
    let engineDescriptor: String
    let engine: HapticEngine?

    var body: some View {
        Form {
            Section {
                LabeledContent("Engine") {
                    Text(engineDescriptor)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.graphite)
                }
                Toggle("Play haptics", isOn: $settings.hapticsEnabled)
                Toggle("Play sound", isOn: $settings.sidetoneEnabled)
                Toggle("Flash the screen", isOn: $settings.flashEnabled)
            }

            Section {
                // The knob that decides whether a tap train fuses into one pulse or
                // reads as a machine gun. It is a property of your hand, not of the
                // code, so it lives here rather than in a constant.
                VStack(alignment: .leading) {
                    HStack {
                        Text("Tap spacing")
                        Spacer()
                        Text("\(Int(settings.tapIntervalMS))ms")
                            .font(Theme.mono(11))
                            .monospacedDigit()
                            .foregroundStyle(Theme.graphite)
                    }
                    Slider(value: $settings.tapIntervalMS, in: 15...50, step: 1)
                        .accessibilityLabel("Tap spacing in milliseconds")
                    Text("Closer taps feel more like one continuous pulse. Wider taps feel like separate knocks.")
                        .font(Theme.ui(11))
                        .foregroundStyle(Theme.graphite)
                }

                Picker("Dit texture", selection: $settings.ditActuationID) {
                    ForEach(ActuatorHapticEngine.actuationIDs, id: \.self) { Text("\($0)").tag(Int($0)) }
                }
                Picker("Dah texture", selection: $settings.dahActuationID) {
                    ForEach(ActuatorHapticEngine.actuationIDs, id: \.self) { Text("\($0)").tag(Int($0)) }
                }

                HStack {
                    Text("Test feel")
                    Spacer()
                    Button("Dit") { demo(.dit) }
                    Button("Dah") { demo(.dah) }
                }
                Text("Pick the two that feel most different from each other.")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.graphite)
            } header: {
                Text("Feel")
            }

            Section {
                LabeledContent("Play the clipboard") {
                    Text("⌃⌥⌘M").font(Theme.mono(11)).foregroundStyle(Theme.graphite)
                }
                if !PasteboardWatcher.canReadSelection {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("The hotkey reads your clipboard. To read the current selection instead, give Thrum Accessibility access.")
                            .font(Theme.ui(11))
                            .foregroundStyle(Theme.graphite)
                        Button("Open Accessibility settings") {
                            PasteboardWatcher.requestSelectionAccess()
                        }
                    }
                }
            } header: {
                Text("Shortcut")
            }
        }
        .formStyle(.grouped)
        .font(Theme.ui(13))
        .frame(width: 440)
        .onChange(of: settings.ditActuationID) { _, v in
            (engine as? ActuatorHapticEngine)?.ditActuationID = Int32(v)
        }
        .onChange(of: settings.dahActuationID) { _, v in
            (engine as? ActuatorHapticEngine)?.dahActuationID = Int32(v)
        }
    }

    /// Fires a real pulse at the current settings so the pair can be judged by hand.
    private func demo(_ style: TapStyle) {
        guard let engine else { return }
        let timing = settings.timing
        let shaper = PulseShaper(tapInterval: settings.tapIntervalMS / 1000)
        let token: MorseToken = style == .dit ? .dit : .dah
        let offsets = shaper.offsets(for: token, timing: timing)
        let queue = DispatchQueue(label: "app.thrum.demo", qos: .userInteractive)
        let base = DispatchTime.now()
        for offset in offsets {
            queue.asyncAfter(deadline: base + offset) { engine.tap(style: style) }
        }
    }
}
