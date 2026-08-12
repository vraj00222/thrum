import SwiftUI
import ThrumPlayback

struct TransportBar: View {
    @Bindable var player: MorsePlayer
    @Bindable var settings: PlaybackSettings

    var body: some View {
        HStack(spacing: 10) {
            Button(action: player.toggle) {
                Label(playLabel, systemImage: player.state == .playing ? "pause.fill" : "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(Theme.ui(13, weight: .medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.signalWash))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .disabled(player.tokens.isEmpty)
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(playLabel)
            .accessibilityHint("Plays the message through the trackpad")

            Button(action: player.stop) {
                Label("Stop", systemImage: "stop.fill")
                    .font(Theme.ui(13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().stroke(Theme.rule, lineWidth: 1))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .disabled(player.state == .idle)
            .accessibilityLabel("Stop")

            Toggle(isOn: $settings.sidetoneEnabled) {
                Label("Sound", systemImage: settings.sidetoneEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(Theme.ui(13))
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .foregroundStyle(settings.sidetoneEnabled ? Theme.ink : Theme.graphite)
            .accessibilityLabel(settings.sidetoneEnabled ? "Turn sound off" : "Turn sound on")

            Spacer()

            Text(status)
                .font(Theme.mono(11))
                .foregroundStyle(Theme.graphite)
                .monospacedDigit()
                .accessibilityLabel(statusAccessibility)
        }
    }

    /// Active voice on the control, so the button names the action and the readout
    /// names the state it produced.
    private var playLabel: String { player.state == .playing ? "Pause" : "Play" }

    private var status: String {
        guard !player.tokens.isEmpty else { return "" }
        let total = player.totalDuration
        switch player.state {
        case .idle:     return String(format: "%.1fs", total)
        case .playing:  return "Playing  " + String(format: "%.1fs / %.1fs", player.elapsed, total)
        case .paused:   return "Paused  " + String(format: "%.1fs / %.1fs", player.elapsed, total)
        case .finished: return "Finished  " + String(format: "%.1fs", total)
        }
    }

    private var statusAccessibility: String {
        status.replacingOccurrences(of: "/", with: "of")
    }
}
