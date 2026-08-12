import SwiftUI
import ThrumCore

/// Tap the spacebar in rhythm; Thrum reads it back. The half of the loop that
/// turns this from a novelty into practice.
struct ReceiveView: View {
    @Bindable var settings: PlaybackSettings

    @State private var decoder = ReceiveDecoder()
    @State private var decoded = ""
    @State private var morse = ""
    @State private var estimatedWPM: Double = 5
    @State private var isDown = false
    @State private var pressStart = Date()
    @State private var lastRelease: Date?
    @State private var flushTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Receive")
                    .font(Theme.ui(12, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("Hold space for a dit, hold longer for a dah. Pause to end a letter.")
                    .font(Theme.ui(12))
                    .foregroundStyle(Theme.graphite)
            }

            KeyCatcher(isDown: $isDown)
                .frame(height: 128)
                .background(RoundedRectangle(cornerRadius: 10).fill(isDown ? Theme.signalWash : .white.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isDown ? Theme.signal : Theme.rule, lineWidth: 1))
                .overlay {
                    Text(decoded.isEmpty ? "Tap here, then key with the spacebar." : decoded)
                        .font(decoded.isEmpty ? Theme.ui(13) : Theme.display(44))
                        .foregroundStyle(decoded.isEmpty ? Theme.graphite : Theme.ink)
                        .padding(.horizontal, 16)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
                .accessibilityLabel("Morse key")
                .accessibilityValue(decoded.isEmpty ? "Nothing received yet" : decoded)
                .accessibilityHint("Hold the spacebar to send dits and dahs")

            HStack {
                Text(morse.isEmpty ? " " : morse)
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.graphite)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "you're keying %.0f WPM", estimatedWPM))
                    .font(Theme.mono(11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.graphite)
            }

            HStack(spacing: 10) {
                Button("Clear") { reset() }
                    .font(Theme.ui(12))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().stroke(Theme.rule, lineWidth: 1))
                    .foregroundStyle(Theme.ink)
                Button("Undo") { decoder.undoLast(); refresh() }
                    .font(Theme.ui(12))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().stroke(Theme.rule, lineWidth: 1))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.tape)
        .onChange(of: isDown) { _, down in down ? keyDown() : keyUp() }
        .onAppear { reset() }
    }

    private func keyDown() {
        flushTask?.cancel()
        if let last = lastRelease {
            decoder.gap(Date().timeIntervalSince(last))
        }
        pressStart = Date()
    }

    private func keyUp() {
        decoder.press(duration: Date().timeIntervalSince(pressStart))
        lastRelease = Date()
        refresh()

        // Close the character once the operator stops for longer than a word gap,
        // otherwise the final letter never resolves.
        flushTask = Task {
            try? await Task.sleep(for: .seconds(decoder.ditReference * 7))
            guard !Task.isCancelled else { return }
            decoder.flush()
            refresh()
        }
    }

    private func refresh() {
        decoded = decoder.text
        morse = decoder.morse
        estimatedWPM = decoder.estimatedWPM
    }

    private func reset() {
        flushTask?.cancel()
        decoder = ReceiveDecoder(timing: settings.timing)
        lastRelease = nil
        refresh()
    }
}

/// A focusable NSView that reports spacebar down/up. SwiftUI has no key-up event,
/// and press *duration* is the entire signal here.
private struct KeyCatcher: NSViewRepresentable {
    @Binding var isDown: Bool

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.onChange = { isDown = $0 }
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.onChange = { isDown = $0 }
    }

    final class KeyView: NSView {
        var onChange: ((Bool) -> Void)?
        private var down = false

        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

        override func keyDown(with event: NSEvent) {
            guard event.keyCode == 49 else { super.keyDown(with: event); return }
            guard !event.isARepeat, !down else { return }   // key repeat is not a new press
            down = true
            onChange?(true)
        }

        override func keyUp(with event: NSEvent) {
            guard event.keyCode == 49 else { super.keyUp(with: event); return }
            down = false
            onChange?(false)
        }

        override func drawFocusRingMask() { bounds.fill() }
        override var focusRingMaskBounds: NSRect { bounds }
        override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    }
}
