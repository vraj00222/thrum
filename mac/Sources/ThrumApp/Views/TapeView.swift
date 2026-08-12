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
struct TapeView: View {

    let tokens: [MorseToken]
    let timing: MorseTiming
    let elapsed: TimeInterval
    let isPlaying: Bool
    /// When text was last extended, for the stagger-in.
    let revealAnchor: Date
    let revealFrom: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pxPerSecond: Double = 92
    private let barHeight: CGFloat = 46
    private let revealDuration = 0.18
    private let staggerStep = 0.018

    var body: some View {
        GeometryReader { geo in
            let playheadX = geo.size.width / 3
            TimelineView(.animation(minimumInterval: isPlaying ? 1.0 / 60 : nil, paused: !isAnimating)) { context in
                Canvas { ctx, size in
                    draw(ctx: &ctx, size: size, playheadX: playheadX, now: context.date)
                }
            }
        }
        .frame(height: 92)
        .background(Theme.tape)
        .overlay(alignment: .leading) { edgeFade(.leading) }
        .overlay(alignment: .trailing) { edgeFade(.trailing) }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.rule, lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("Morse tape")
        .accessibilityValue(tokens.isEmpty ? "Empty" : morseDescription)
    }

    /// VoiceOver reads the pattern itself: "dot dot dot, dash dash dash".
    private var morseDescription: String {
        tokens.compactMap { token in
            switch token {
            case .dit: return "dot"
            case .dah: return "dash"
            case .charGap: return ","
            case .wordGap: return "."
            case .intraGap: return nil
            }
        }.joined(separator: " ")
    }

    private var isAnimating: Bool {
        if isPlaying && !reduceMotion { return true }
        return Date().timeIntervalSince(revealAnchor) < 2
    }

    private func draw(ctx: inout GraphicsContext, size: CGSize, playheadX: CGFloat, now: Date) {
        let midY = size.height / 2
        // Reduced motion: the tape holds still and the highlight steps token to token.
        let scroll = reduceMotion
            ? snappedElapsed()
            : elapsed
        let originX = playheadX - CGFloat(scroll * pxPerSecond)

        var t: TimeInterval = 0
        let revealAge = now.timeIntervalSince(revealAnchor)

        for (index, token) in tokens.enumerated() {
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

            let live = isLive(index: index, start: t, duration: duration, scroll: scroll)
            let scale = live ? 1.15 : 1.0
            let height = barHeight * eased * scale
            let rect = CGRect(x: x, y: midY - height / 2, width: width, height: height)

            ctx.fill(
                Path(roundedRect: rect, cornerRadius: min(4, width / 2)),
                with: .color(live ? Theme.signal : Theme.ink.opacity(0.86 * eased))
            )
        }

        // Playhead last, so it sits over the tape.
        let pulse = isPlaying && !reduceMotion ? 1 + 0.12 * sin(now.timeIntervalSince1970 * 6) : 1
        let headHeight = 70.0 * pulse
        ctx.fill(
            Path(roundedRect: CGRect(x: playheadX - 1, y: midY - headHeight / 2, width: 2, height: headHeight),
                 cornerRadius: 1),
            with: .color(Theme.signal)
        )
    }

    /// Under reduced motion the tape sits on token boundaries instead of sliding.
    private func snappedElapsed() -> TimeInterval {
        var t: TimeInterval = 0
        for token in tokens {
            let next = t + timing.duration(of: token)
            if next > elapsed { return t }
            t = next
        }
        return t
    }

    private func isLive(index: Int, start: TimeInterval, duration: TimeInterval, scroll: TimeInterval) -> Bool {
        isPlaying && scroll >= start && scroll < start + duration
    }

    /// Slight overshoot on the way in.
    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    private func edgeFade(_ edge: HorizontalAlignment) -> some View {
        LinearGradient(
            colors: [Theme.tape, Theme.tape.opacity(0)],
            startPoint: edge == .leading ? .leading : .trailing,
            endPoint: edge == .leading ? .trailing : .leading
        )
        .frame(width: 28)
        .allowsHitTesting(false)
    }
}
