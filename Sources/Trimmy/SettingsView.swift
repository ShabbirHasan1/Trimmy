import KeyboardShortcuts
import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        Form {
            Picker("Aggressiveness", selection: self.$settings.aggressiveness) {
                ForEach(Aggressiveness.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            Toggle("Keep blank lines", isOn: self.$settings.preserveBlankLines)
            Toggle("Auto-trim enabled", isOn: self.$settings.autoTrimEnabled)
            Toggle("Remove box drawing chars (│ │)", isOn: self.$settings.removeBoxDrawing)
            Toggle("Enable global “Type Trimmed” hotkey", isOn: self.$settings.hotkeyEnabled)
            KeyboardShortcuts.Recorder("Shortcut", name: .typeTrimmed)
        }
        .padding()
        .frame(width: 320)
        .onChange(of: self.settings.hotkeyEnabled) { _, _ in
            self.hotkeyManager.refreshRegistration()
        }
    }
}

extension Aggressiveness {}
