import SwiftUI
import ThrumPlayback

struct TransportBar: View {
    @Bindable var player: MorsePlayer
    @Bindable var settings: PlaybackSettings

    var body: some View {
        VStack(spacing: 12) {
            Scrubber(player: player)

            HStack(spacing: 8) {
                TransportButton(
                    title: player.state == .playing ? "Pause" : "Play",
                    icon: player.state == .playing ? "pause.fill" : "play.fill",
                    prominent: true,
                    action: player.toggle
                )
                .disabled(player.tokens.isEmpty)

                TransportButton(title: "Stop", icon: "stop.fill", action: player.stop)
                    .disabled(player.state == .idle)

                TransportButton(
                    title: settings.sidetoneEnabled ? "Sound on" : "Sound off",
                    icon: settings.sidetoneEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    muted: !settings.sidetoneEnabled,
                    action: { settings.sidetoneEnabled.toggle() }
                )
                .accessibilityLabel(settings.sidetoneEnabled ? "Turn sound off" : "Turn sound on")

                Spacer()

                // Live clock, interpolated so it counts rather than jumps.
                TimelineView(.periodic(from: .now, by: player.state == .playing ? 0.05 : 3600)) { context in
                    Text(clock(at: context.date))
                        .font(Theme.mono(11))
                        .monospacedDigit()
                        .foregroundStyle(Theme.graphite)
                        .accessibilityLabel(accessibleClock(at: context.date))
                }
            }
        }
    }

    private func clock(at now: Date) -> String {
        guard !player.tokens.isEmpty else { return "" }
        let elapsed = player.elapsed(at: now)
        return String(format: "%@  %.1f / %.1fs", stateWord, elapsed, player.totalDuration)
    }

    /// Active voice on the control, so the button names the action and the readout
    /// names the state it produced.
    private var stateWord: String {
        switch player.state {
        case .idle: return "Ready"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .finished: return "Finished"
        }
    }

    private func accessibleClock(at now: Date) -> String {
        guard !player.tokens.isEmpty else { return "Nothing loaded" }
        return String(format: "%@, %.0f of %.0f seconds", stateWord,
                      player.elapsed(at: now), player.totalDuration)
    }
}

/// Drag or click anywhere on the line to move through the message.
private struct Scrubber: View {
    @Bindable var player: MorsePlayer
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: player.state != .playing)) { context in
                let fraction = player.totalDuration > 0
                    ? player.elapsed(at: context.date) / player.totalDuration
                    : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.rule)
                    Capsule().fill(Theme.signal)
                        .frame(width: max(0, geo.size.width * fraction))
                    Circle()
                        .fill(Theme.signal)
                        .frame(width: dragging ? 12 : 9, height: dragging ? 12 : 9)
                        .offset(x: max(0, geo.size.width * fraction - 4.5))
                        .opacity(player.tokens.isEmpty ? 0 : 1)
                }
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !player.tokens.isEmpty else { return }
                        dragging = true
                        seek(to: value.location.x, width: geo.size.width)
                    }
                    .onEnded { value in
                        dragging = false
                        seek(to: value.location.x, width: geo.size.width)
                    }
            )
        }
        .frame(height: 14)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Int(player.progress * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step = player.totalDuration / 20
            player.seek(to: player.elapsed + (direction == .increment ? step : -step))
        }
    }

    private func seek(to x: CGFloat, width: CGFloat) {
        guard width > 0 else { return }
        player.seek(to: player.totalDuration * Double(min(max(0, x / width), 1)))
    }
}

private struct TransportButton: View {
    let title: String
    let icon: String
    var prominent = false
    var muted = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
                Text(title).font(Theme.ui(12, weight: prominent ? .medium : .regular))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(prominent ? Theme.signalWash : Color.white.opacity(hovering ? 0.9 : 0.45))
            )
            .overlay(Capsule().stroke(prominent ? .clear : Theme.rule, lineWidth: 1))
            .foregroundStyle(muted ? Theme.graphite : Theme.ink)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(hovering && isEnabled ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .accessibilityLabel(title)
    }
}
