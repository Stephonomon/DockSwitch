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

    static func defaultSymbol(forName name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("home") {
            return "house.fill"
        }
        if lower.contains("work") || lower.contains("office") {
            return "building.2.fill"
        }
        return "arrow.left.arrow.right.circle.fill"
    }
}

struct DetectionContext {
    var dockName: String?
    var dockCandidates: [String]
    var wifiSSID: String?
    var wifiCandidates: [String]
    var latitude: Double?
    var longitude: Double?
    var locationAuthorized: Bool
    var observedAt: Date

    static let empty = DetectionContext(
        dockName: nil,
        dockCandidates: [],
        wifiSSID: nil,
        wifiCandidates: [],
        latitude: nil,
        longitude: nil,
        locationAuthorized: false,
        observedAt: .distantPast
    )
}

struct ProfileMatch {
    var profile: DockProfile
    /// Fraction of the profile's own rules that matched (0–1); used for the auto-apply threshold.
    var confidence: Double
    /// Absolute weight of matched signals; used to rank competing profiles.
    var matchedWeight: Double
    var reasons: [String]
}
