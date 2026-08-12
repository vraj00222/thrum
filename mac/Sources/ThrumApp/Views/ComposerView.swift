import SwiftUI
import ThrumCore
import ThrumPlayback

struct ComposerView: View {
    @Bindable var player: MorsePlayer
    @Bindable var settings: PlaybackSettings
    let engineWarning: String?

    @State private var text = ""
    @State private var revealAnchor = Date()
    @State private var revealFrom = 0
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let engineWarning {
                banner(engineWarning)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Type something. It'll be in your palm in a second.")
                        .font(Theme.ui(15))
                        .foregroundStyle(Theme.graphite)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Theme.ui(15))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .frame(minHeight: 78)
                    .accessibilityLabel("Message to send")
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.rule, lineWidth: 1))

            if !unsupported.isEmpty {
                // Inline and quiet. A modal for a stray character would be absurd.
                Text("Morse has no \(unsupported.map(String.init).sorted().joined(separator: " ")). Those will be skipped.")
                    .font(Theme.ui(11))
                    .foregroundStyle(Theme.graphite)
                    .transition(.opacity)
            }

            TapeView(tokens: player.tokens,
                     timing: settings.timing,
                     elapsed: player.state == .playing ? player.liveElapsed : player.elapsed,
                     isPlaying: player.state == .playing,
                     revealAnchor: revealAnchor,
                     revealFrom: revealFrom)

            if !player.tokens.isEmpty {
                Text(MorseCode.encodeToString(text))
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.graphite)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            TransportBar(player: player, settings: settings)

            Divider().overlay(Theme.rule)

            SpeedDial(settings: settings)
        }
        .padding(22)
        .background(Theme.tape)
        .onChange(of: text) { old, new in
            // Bars added by this keystroke stagger in; everything already on the
            // tape stays put.
            revealFrom = MorseCode.tokenize(String(new.prefix(commonPrefix(old, new)))).count
            revealAnchor = Date()
            player.load(new)
        }
        .onAppear { editorFocused = true }
        .onChange(of: settings.wpm) { _, _ in player.timing = settings.timing }
        .onChange(of: settings.farnsworthEnabled) { _, _ in player.timing = settings.timing }
        .onChange(of: settings.characterWPM) { _, _ in player.timing = settings.timing }
        .onChange(of: settings.sidetoneEnabled) { _, v in player.sidetoneEnabled = v }
        .onChange(of: settings.hapticsEnabled) { _, v in player.hapticsEnabled = v }
        .onChange(of: settings.tapIntervalMS) { _, v in player.tapInterval = v / 1000 }
    }

    private var unsupported: Set<Character> { MorseCode.unsupported(in: text) }

    private func commonPrefix(_ a: String, _ b: String) -> Int {
        zip(a, b).prefix { $0 == $1 }.count
    }

    private func banner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Theme.ink)
            Text(message)
                .font(Theme.ui(12))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.signalWash))
        .accessibilityElement(children: .combine)
    }
}
