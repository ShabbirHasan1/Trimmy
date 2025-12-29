import AppKit
import SwiftUI

@MainActor
struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: AccessibilityPermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !self.permissions.isTrusted {
                AccessibilityPermissionCallout(permissions: self.permissions)
            }
            PreferenceToggleRow(
                title: "Auto-trim enabled",
                subtitle: "Automatically trim clipboard content when it looks like a command.",
                binding: self.$settings.autoTrimEnabled)

            PreferenceToggleRow(
                title: "Context-aware trimming",
                subtitle: "Be more eager for Terminal/iTerm/kitty/Warp copies (Cmd-C detection + app snapshot).",
                binding: self.$settings.contextAwareTrimmingEnabled)

            PreferenceToggleRow(
                title: "Keep blank lines",
                subtitle: "Preserve intentional blank lines instead of collapsing them.",
                binding: self.$settings.preserveBlankLines)

            PreferenceToggleRow(
                title: "Remove box drawing chars (│┃)",
                subtitle: "Strip prompt-style box gutters (any count, leading/trailing) before trimming.",
                binding: self.$settings.removeBoxDrawing)

            Divider()
                .padding(.vertical, 4)

            PreferenceToggleRow(
                title: "Start at Login",
                subtitle: "Automatically opens the app when you start your Mac.",
                binding: self.$settings.launchAtLogin)

            HStack {
                Spacer()
                Button("Quit Trimmy") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}
