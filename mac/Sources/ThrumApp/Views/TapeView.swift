import SwiftUI
import ThrumCore
import ThrumPlayback

/// A paper-tape strip. Each pulse is a bar whose width is its real duration, gaps
/// are real negative space, and the playhead is pinned a third from the left while
/// the tape scrolls beneath it at exactly playback speed.
///
/// Everything is laid out in *time*, not in units — so a bar's width and the tape's
/// scroll rate come from the same number and cannot drift apart. Under Farnsworth
/// the gaps visibly stretch, which is the honest picture of what you're hearing.
///
/// The scroll position is recomputed from `context.date` inside the draw call. Reading
/// the player's `elapsed` property instead would redraw at 60fps against a value that
/// only changes once per token, which is what made the tape step rather than glide.
struct TapeView: View {

    @Bindable var player: MorsePlayer
    let timing: MorseTiming
    let revealAnchor: Date
    let revealFrom: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealing = false
    @State private var hovering = false

    private let pxPerSecond: Double = 92
    private let barHeight: CGFloat = 46
    private let revealDuration = 0.18
    private let staggerStep = 0.018

    private var isPlaying: Bool { player.state == .playing }

    var body: some View {
        GeometryReader { geo in
            let playheadX = geo.size.width / 3
            TimelineView(.animation(paused: !isPlaying && !revealing)) { context in
                Canvas { ctx, size in
                    draw(ctx: &ctx, size: size, playheadX: playheadX, now: context.date)
                }
                .contentShape(Rectangle())
                .onTapGesture { location in
                    // Scrub: the tape under the pointer becomes the tape under the head.
                    let delta = Double(location.x - playheadX) / pxPerSecond
                    player.seek(to: player.elapsed(at: context.date) + delta)
                }
            }
        }
        .frame(height: 92)
        .background(Theme.tape)
        .overlay(alignment: .leading) { edgeFade(leading: true) }
        .overlay(alignment: .trailing) { edgeFade(leading: false) }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(hovering && !player.tokens.isEmpty ? Theme.graphite.opacity(0.5) : Theme.rule, lineWidth: 1)
        )
        .onHover { hovering = $0 }
        .onContinuousHover { phase in
            if case .active = phase, !player.tokens.isEmpty { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
        // The reveal animates for exactly as long as it needs, then the timeline
        // parks itself instead of burning a frame budget on a static tape.
        .task(id: revealAnchor) {
            revealing = true
            try? await Task.sleep(for: .seconds(1.2))
            revealing = false
        }
        .accessibilityElement()
        .accessibilityLabel("Morse tape")
        .accessibilityValue(player.tokens.isEmpty ? "Empty" : morseDescription)
        .accessibilityHint(player.tokens.isEmpty ? "" : "Click to jump to a point in the message")
    }

    /// VoiceOver reads the pattern itself: "dot dot dot, dash dash dash".
    private var morseDescription: String {
        player.tokens.compactMap { token in
            switch token {
            case .dit: return "dot"
            case .dah: return "dash"
            case .charGap: return ","
            case .wordGap: return "."
            case .intraGap: return nil
            }
        }.joined(separator: " ")
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, playheadX: CGFloat, now: Date) {
        let midY = size.height / 2
        let live = player.elapsed(at: now)
        // Reduced motion: the tape holds still and the highlight steps token to token.
        let scroll = reduceMotion ? snapped(live) : live
        let originX = playheadX - CGFloat(scroll * pxPerSecond)

        var t: TimeInterval = 0
        let revealAge = now.timeIntervalSince(revealAnchor)

        for (index, token) in player.tokens.enumerated() {
            let duration = timing.duration(of: token)
            defer { t += duration }
            guard token.isPulse else { continue }

            let x = originX + CGFloat(t * pxPerSecond)
            let width = CGFloat(duration * pxPerSecond)
            guard x + width > -20, x < size.width + 20 else { continue }

            // Stagger: bars added since the last edit fade and slide in, left to right.
            var reveal = 1.0
            if index >= revealFrom {
                let delay = Double(index - revealFrom) * staggerStep
                reveal = min(1, max(0, (revealAge - delay) / revealDuration))
                if reveal <= 0 { continue }
            }
            let eased = reduceMotion ? (reveal > 0 ? 1 : 0) : easeOutBack(reveal)

            let firing = isPlaying && scroll >= t && scroll < t + duration
            let height = barHeight * eased * (firing ? 1.15 : 1)
            let played = scroll > t
            let rect = CGRect(x: x, y: midY - height / 2, width: width, height: height)

            ctx.fill(
                Path(roundedRect: rect, cornerRadius: min(4, width / 2)),
                with: .color(firing ? Theme.signal
                                    : Theme.ink.opacity((played ? 0.35 : 0.86) * eased))
            )
        }

        // Playhead last, so it sits over the tape.
        let pulse = isPlaying && !reduceMotion ? 1 + 0.1 * sin(now.timeIntervalSince1970 * 7) : 1
        let headHeight = 70.0 * pulse
        ctx.fill(
            Path(roundedRect: CGRect(x: playheadX - 1, y: midY - headHeight / 2, width: 2, height: headHeight),
                 cornerRadius: 1),
            with: .color(Theme.signal)
        )
    }

    /// Under reduced motion the tape sits on token boundaries instead of sliding.
    private func snapped(_ time: TimeInterval) -> TimeInterval {
        var t: TimeInterval = 0
        for token in player.tokens {
            let next = t + timing.duration(of: token)
            if next > time { return t }
            t = next
        }
        return t
    }

    /// Slight overshoot on the way in.
    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    private func edgeFade(leading: Bool) -> some View {
        LinearGradient(
            colors: [Theme.tape, Theme.tape.opacity(0)],
            startPoint: leading ? .leading : .trailing,
            endPoint: leading ? .trailing : .leading
        )
        .frame(width: 28)
        .allowsHitTesting(false)
    }
}
