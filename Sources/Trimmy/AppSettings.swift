import ServiceManagement
import SwiftUI

enum Aggressiveness: String, CaseIterable, Identifiable, Codable {
    case low, normal, high
    var id: String { rawValue }

    var scoreThreshold: Int {
        switch self {
        case .low: 3
        case .normal: 2
        case .high: 1
        }
    }
}

extension Aggressiveness {
    var title: String {
        switch self {
        case .low: "Low (safer)"
        case .normal: "Normal"
        case .high: "High (more eager)"
        }
    }

    var titleShort: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("aggressiveness") var aggressiveness: Aggressiveness = .normal
    @AppStorage("preserveBlankLines") var preserveBlankLines: Bool = false
    @AppStorage("autoTrimEnabled") var autoTrimEnabled: Bool = true
    @AppStorage("removeBoxDrawing") var removeBoxDrawing: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { LaunchAtLoginManager.setEnabled(self.launchAtLogin) }
    }
    @AppStorage("hotkeyEnabled") var hotkeyEnabled: Bool = true {
        didSet { self.hotkeyEnabledChanged?(self.hotkeyEnabled) }
    }

    /// Invoked whenever `hotkeyEnabled` flips; wired by `HotkeyManager`.
    var hotkeyEnabledChanged: ((Bool) -> Void)?

    init() {
        LaunchAtLoginManager.setEnabled(self.launchAtLogin)
    }
}

enum LaunchAtLoginManager {
    @MainActor
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        if enabled {
            try? service.register()
        } else {
            try? service.unregister()
        }
    }
}
