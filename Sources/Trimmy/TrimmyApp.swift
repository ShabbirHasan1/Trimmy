import Sparkle
import SwiftUI

@main
@MainActor
struct TrimmyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var monitor: ClipboardMonitor
    @StateObject private var hotkeyManager: HotkeyManager

    init() {
        let settings = AppSettings()
        let monitor = ClipboardMonitor(settings: settings)
        monitor.start()
        let hotkeyManager = HotkeyManager(settings: settings, monitor: monitor)
        _settings = StateObject(wrappedValue: settings)
        _monitor = StateObject(wrappedValue: monitor)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)
    }

    var body: some Scene {
        MenuBarExtra("Trimmy", systemImage: "scissors") {
            MenuContentView(
                monitor: self.monitor,
                settings: self.settings,
                hotkeyManager: self.hotkeyManager,
                updater: self.appDelegate.updaterController)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        Settings {
            SettingsView(settings: self.settings, hotkeyManager: self.hotkeyManager)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil)
}
