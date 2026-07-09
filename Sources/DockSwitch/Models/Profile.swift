import Foundation

struct DevicePreferences: Codable, Hashable {
    var microphoneName: String?
    var speakerName: String?
    var cameraName: String?
}

struct MatchingRules: Codable, Hashable {
    var dockNameContains: String?
    var wifiSSID: String?
    var latitude: Double?
    var longitude: Double?
    var radiusMeters: Double?
}

struct DockProfile: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var iconSymbol: String
    var autoApplyEnabled: Bool
    var matching: MatchingRules
    var preferences: DevicePreferences

    init(
        id: UUID = UUID(),
        name: String,
        iconSymbol: String = "mappin.and.ellipse",
        autoApplyEnabled: Bool = true,
        matching: MatchingRules,
        preferences: DevicePreferences
    ) {
        self.id = id
        self.name = name
        self.iconSymbol = iconSymbol
        self.autoApplyEnabled = autoApplyEnabled
        self.matching = matching
        self.preferences = preferences
    }
}

struct DetectionContext {
    var dockName: String?
    var wifiSSID: String?
    var latitude: Double?
    var longitude: Double?
    var observedAt: Date
}

struct ProfileMatch {
    var profile: DockProfile
    var confidence: Double
    var reasons: [String]
}
