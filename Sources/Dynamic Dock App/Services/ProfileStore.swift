import Foundation

final class ProfileStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var baseURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = support.appendingPathComponent("DynamicDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private var profilesURL: URL {
        baseURL.appendingPathComponent("profiles.json")
    }

    private var settingsURL: URL {
        baseURL.appendingPathComponent("settings.json")
    }

    func loadProfiles() -> [DockProfile] {
        guard let data = try? Data(contentsOf: profilesURL),
              let profiles = try? decoder.decode([DockProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    func saveProfiles(_ profiles: [DockProfile]) {
        guard let data = try? encoder.encode(profiles) else {
            return
        }
        try? data.write(to: profilesURL, options: .atomic)
    }

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? decoder.decode(AppSettings.self, from: data) else {
            return .init(autoModeEnabled: true, manualOverrideProfileID: nil)
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else {
            return
        }
        try? data.write(to: settingsURL, options: .atomic)
    }
}

struct AppSettings: Codable {
    var autoModeEnabled: Bool
    var manualOverrideProfileID: UUID?
}
