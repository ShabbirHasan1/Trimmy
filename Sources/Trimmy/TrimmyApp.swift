import Security
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
    let updaterController: UpdaterProviding = makeUpdaterController()
}

// MARK: - Sparkle gating (disable for unsigned/dev builds)

@MainActor
protocol UpdaterProviding: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var isAvailable: Bool { get }
    func checkForUpdates(_ sender: Any?)
}

// No-op updater used for debug/dev runs to suppress Sparkle dialogs.
final class DisabledUpdaterController: UpdaterProviding {
    var automaticallyChecksForUpdates: Bool = false
    let isAvailable: Bool = false
    func checkForUpdates(_: Any?) {}
}

#if canImport(Sparkle)
import Sparkle

extension SPUStandardUpdaterController: UpdaterProviding {
    var automaticallyChecksForUpdates: Bool {
        get { self.updater.automaticallyChecksForUpdates }
        set { self.updater.automaticallyChecksForUpdates = newValue }
    }

    var isAvailable: Bool { true }
}

private func isDeveloperIDSigned(bundleURL: URL) -> Bool {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
          let code = staticCode else { return false }

    var infoCF: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &infoCF) == errSecSuccess,
          let info = infoCF as? [String: Any],
          let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
          let leaf = certs.first else { return false }

    if let summary = SecCertificateCopySubjectSummary(leaf) as String? {
        return summary.hasPrefix("Developer ID Application:")
    }
    return false
}

private func makeUpdaterController() -> UpdaterProviding {
    let bundleURL = Bundle.main.bundleURL
    let isBundledApp = bundleURL.pathExtension == "app"
    guard isBundledApp, isDeveloperIDSigned(bundleURL: bundleURL) else { return DisabledUpdaterController() }

    let controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil)
    controller.updater.automaticallyChecksForUpdates = false
    controller.startUpdater()
    return controller
}
#else
private func makeUpdaterController() -> UpdaterProviding {
    DisabledUpdaterController()
}
#endif
