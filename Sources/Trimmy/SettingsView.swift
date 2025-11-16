import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: AppSettings

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
        }
        .padding()
        .frame(width: 320)
    }
}

extension Aggressiveness {}
