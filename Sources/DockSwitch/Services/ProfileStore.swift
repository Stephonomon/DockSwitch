import Foundation
import os

final class ProfileStore {
    private static let logger = Logger(subsystem: "com.dockswitch.menuapp", category: "ProfileStore")

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var baseURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let root = support.appendingPathComponent("DockSwitch", isDirectory: true)
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
        load([DockProfile].self, from: profilesURL) ?? []
    }

    func saveProfiles(_ profiles: [DockProfile]) {
        save(profiles, to: profilesURL)
    }

    func loadSettings() -> AppSettings {
        load(AppSettings.self, from: settingsURL)
            ?? .init(autoModeEnabled: true, manualOverrideProfileID: nil)
    }

    func saveSettings(_ settings: AppSettings) {
        save(settings, to: settingsURL)
    }

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            // Preserve the unreadable file instead of letting the next save
            // silently overwrite the user's data.
            let backupURL = url.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.moveItem(at: url, to: backupURL)
            Self.logger.error("Failed to load \(url.lastPathComponent, privacy: .public): \(error, privacy: .public). Backed up to \(backupURL.lastPathComponent, privacy: .public).")
            return nil
        }
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
            // Profiles can contain home/work coordinates; keep them user-only readable.
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            Self.logger.error("Failed to save \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
        }
    }
}

struct AppSettings: Codable {
    var autoModeEnabled: Bool
    var manualOverrideProfileID: UUID?
}
