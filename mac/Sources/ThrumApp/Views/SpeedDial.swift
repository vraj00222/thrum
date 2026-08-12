import SwiftUI
import ThrumCore

struct SpeedDial: View {
    @Bindable var settings: PlaybackSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Speed")
                    .font(Theme.ui(12, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                // The number that actually matters: how long one dit lasts in your hand.
                Text(String(format: "dit = %.0fms", settings.ditMilliseconds))
                    .font(Theme.mono(11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.graphite)
            }

            HStack(spacing: 12) {
                Slider(value: $settings.wpm,
                       in: PlaybackSettings.minWPM...PlaybackSettings.maxWPM,
                       step: 1)
                    .tint(Theme.signalWash)
                    .accessibilityLabel("Words per minute")
                    .accessibilityValue("\(Int(settings.wpm)) words per minute")

                Text("\(Int(settings.wpm)) WPM")
                    .font(Theme.mono(12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .frame(width: 62, alignment: .trailing)
            }

            Toggle(isOn: $settings.farnsworthEnabled) {
                Text("Farnsworth spacing")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.ink)
            }
            .toggleStyle(.switch)
            .tint(Theme.signal)
            .accessibilityHint("Sends characters fast and stretches the gaps, for learning")

            if settings.farnsworthEnabled {
                HStack(spacing: 12) {
                    Slider(value: $settings.characterWPM, in: 13...25, step: 1)
                        .tint(Theme.signalWash)
                        .accessibilityLabel("Character speed")
                        .accessibilityValue("\(Int(settings.characterWPM)) words per minute")
                    Text("\(Int(settings.characterWPM)) char")
                        .font(Theme.mono(12))
                        .monospacedDigit()
                        .foregroundStyle(Theme.graphite)
                        .frame(width: 62, alignment: .trailing)
                }
                Text("Characters at \(Int(settings.characterWPM)) WPM, arriving at \(Int(settings.wpm)) WPM overall.")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.graphite)
            }

            if settings.wpm >= 11 {
                Text("Above about 10 WPM a dit is only a few taps. You'll hear it before you feel it.")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.graphite)
            }
        }
    }
}
