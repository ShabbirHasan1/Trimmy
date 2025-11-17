import AppKit
import Sparkle
import SwiftUI

@MainActor
struct MenuContentView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var settings: AppSettings
    let updater: SPUStandardUpdaterController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auto-Trim", isOn: self.$settings.autoTrimEnabled)
            Button("Trim Clipboard Now") {
                self.monitor.trimClipboardIfNeeded(force: true)
            }
            Text(self.lastText)
                .foregroundStyle(.secondary)
                .font(.caption)
            Divider()
            Menu("Settings") {
                Menu("Aggressiveness: \(self.settings.aggressiveness.titleShort)") {
                    ForEach(Aggressiveness.allCases) { level in
                        Button {
                            self.settings.aggressiveness = level
                        } label: {
                            if self.settings.aggressiveness == level {
                                Label(level.title, systemImage: "checkmark")
                            } else {
                                Text(level.title)
                            }
                        }
                    }
                }
                Toggle("Keep blank lines", isOn: self.$settings.preserveBlankLines)
                Toggle("Remove box drawing chars (│ │)", isOn: self.$settings.removeBoxDrawing)
                Toggle("Launch at login", isOn: self.$settings.launchAtLogin)
                Button("Trim Clipboard Now") {
                    self.monitor.trimClipboardIfNeeded(force: true)
                }
                Toggle("Automatically check for updates", isOn: self.autoUpdateBinding)
                Button("Check for Updates…") {
                    self.updater.checkForUpdates(nil)
                }
            }
            Button("About Trimmy") {
                self.showAbout()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    private var lastText: String {
        self.monitor.lastSummary.isEmpty ? "No trims yet" : "Last: \(self.monitor.lastSummary)"
    }

    private var autoUpdateBinding: Binding<Bool> {
        Binding(
            get: { self.updater.updater.automaticallyChecksForUpdates },
            set: { self.updater.updater.automaticallyChecksForUpdates = $0 })
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let versionString = build.isEmpty ? version : "\(version) (\(build))"
        let credits = NSMutableAttributedString(string: "Peter Steinberger — MIT License\n")
        credits.append(self.makeLink("GitHub", urlString: "https://github.com/steipete/Trimmy"))
        credits.append(self.separator)
        credits.append(self.makeLink("Website", urlString: "https://steipete.me"))
        credits.append(self.separator)
        credits.append(self.makeLink("Twitter", urlString: "https://twitter.com/steipete"))
        credits.append(self.separator)
        credits.append(self.makeLink("Email", urlString: "mailto:peter@steipete.me"))

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Trimmy",
            .applicationVersion: versionString,
            .version: versionString,
            .credits: credits,
            .applicationIcon: (NSApplication.shared.applicationIconImage ?? NSImage()) as Any,
        ]

        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
    }

    private func makeLink(_ title: String, urlString: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .link: URL(string: urlString) as Any,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ]
        return NSAttributedString(string: title, attributes: attributes)
    }

    private var separator: NSAttributedString {
        NSAttributedString(string: " · ", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ])
    }
}
