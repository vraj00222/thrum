import SwiftUI
import ThrumCore
import ThrumHaptics
import ThrumPlayback

@main
struct ThrumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Thrum", id: "composer") {
            RootView(model: model)
                .frame(minWidth: 560, minHeight: 620)
        }
        .defaultSize(width: 620, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Play") { model.player.toggle() }
                    .keyboardShortcut("p", modifiers: .command)
                Button("Stop") { model.player.stop() }
                    .keyboardShortcut(".", modifiers: .command)
            }
        }

        MenuBarExtra("Thrum", systemImage: "dot.radiowaves.left.and.right") {
            MenuBarContent(model: model)
        }

        Settings {
            SettingsView(settings: model.settings,
                         engineDescriptor: model.engineDescriptor,
                         engine: model.engine)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
    }
    /// The window is the workspace; the menu bar item is the daily loop. Closing one
    /// shouldn't quit the other.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@Observable
final class AppModel {
    let settings = PlaybackSettings()
    let player: MorsePlayer
    let engine: HapticEngine?
    let engineDescriptor: String
    let engineWarning: String?

    @ObservationIgnored private var outcome: HapticEngineResolver.Outcome

    init() {
        let resolved = HapticEngineResolver.resolve()
        outcome = resolved
        engine = resolved.engine
        engineDescriptor = resolved.descriptor
        engineWarning = resolved.warning

        let settings = self.settings
        if let actuator = resolved.engine as? ActuatorHapticEngine {
            actuator.ditActuationID = Int32(settings.ditActuationID)
            actuator.dahActuationID = Int32(settings.dahActuationID)
        }

        player = MorsePlayer(engine: resolved.engine,
                             shaper: PulseShaper(tapInterval: settings.tapIntervalMS / 1000))
        player.timing = settings.timing
        player.sidetoneEnabled = settings.sidetoneEnabled
        player.hapticsEnabled = settings.hapticsEnabled

        GlobalHotkey.shared.register { [weak self] in self?.playPasteboard() }
    }

    /// Hotkey path: grab text and play it with the window closed.
    func playPasteboard() {
        guard let text = PasteboardWatcher.currentText() else { return }
        player.load(text)
        player.play()
    }
}

struct RootView: View {
    @Bindable var model: AppModel
    @AppStorage("selectedTab") private var tab = "send"

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $tab) {
                Text("Send").tag("send")
                Text("Learn").tag("learn")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding(.top, 16)
            .padding(.bottom, 4)

            if tab == "send" {
                ComposerView(player: model.player,
                             settings: model.settings,
                             engineWarning: model.engineWarning)
            } else {
                ReceiveView(settings: model.settings)
            }
        }
        .background(Theme.tape)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MenuBarContent: View {
    @Bindable var model: AppModel

    var body: some View {
        Button("Play the clipboard") { model.playPasteboard() }
            .keyboardShortcut("m", modifiers: [.control, .option, .command])
        Button(model.player.state == .playing ? "Stop" : "Play again") {
            model.player.state == .playing ? model.player.stop() : model.player.play()
        }
        .disabled(model.player.tokens.isEmpty)

        Divider()

        Text(model.engineDescriptor)
        Text("\(Int(model.settings.wpm)) WPM · dit \(Int(model.settings.ditMilliseconds))ms")

        Divider()

        Button("Open Thrum") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.title == "Thrum" }?.makeKeyAndOrderFront(nil)
        }
        SettingsLink { Text("Settings…") }
        Button("Quit Thrum") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }
}
