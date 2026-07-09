import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var profiles: [DockProfile]
    @Published var autoModeEnabled: Bool
    @Published var manualOverrideProfileID: UUID?
    @Published var activeProfileID: UUID?
    @Published var latestContext: DetectionContext
    @Published var deviceCatalog: DeviceCatalog
    @Published var lastEventMessage: String = "Ready"
    @Published var latestMatchSummary: String = "No profile match yet"

    private let store = ProfileStore()
    private let detector = ContextDetector()
    private var timer: Timer?

    init() {
        let loadedProfiles = store.loadProfiles()
        profiles = loadedProfiles.isEmpty ? Self.defaultProfiles() : loadedProfiles

        let settings = store.loadSettings()
        autoModeEnabled = settings.autoModeEnabled
        manualOverrideProfileID = settings.manualOverrideProfileID

        latestContext = detector.snapshot()
        deviceCatalog = DeviceDiscoveryService.currentCatalog()
        detector.requestPermissions()

        if let overrideID = manualOverrideProfileID, profiles.contains(where: { $0.id == overrideID }) {
            activeProfileID = overrideID
            lastEventMessage = "Manual override active"
        }

        refreshNow()
        startAutoPolling()
    }

    var activeProfileName: String {
        guard let activeProfileID,
              let profile = profiles.first(where: { $0.id == activeProfileID }) else {
            return "None"
        }
        return profile.name
    }

    var detectedContextLabel: String {
        let dock = latestContext.dockName ?? "No dock detected"
        let wifi = latestContext.wifiSSID ?? "Wi-Fi unavailable"
        let locationState: String
        if latestContext.latitude != nil && latestContext.longitude != nil {
            locationState = "Location ready"
        } else if latestContext.locationAuthorized {
            locationState = "Locating..."
        } else {
            locationState = "Location permission needed"
        }
        return "Dock: \(dock) | Wi-Fi: \(wifi) | \(locationState)"
    }

    var suggestedDockNames: [String] {
        var items = profiles.compactMap(\ .matching.dockNameContains)
        items.append(contentsOf: latestContext.dockCandidates)
        return Array(Set(items)).sorted()
    }

    var suggestedSSIDs: [String] {
        var items = latestContext.wifiCandidates
        if let ssid = latestContext.wifiSSID {
            items.append(ssid)
        }
        return Array(Set(items)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    func refreshNow() {
        latestContext = detector.snapshot()
        deviceCatalog = DeviceDiscoveryService.currentCatalog()

        if let match = ProfileMatcher.bestMatch(for: latestContext, in: profiles) {
            latestMatchSummary = "\(match.profile.name) (\(Int(match.confidence * 100))%)"
        } else {
            latestMatchSummary = "No eligible match"
        }

        guard autoModeEnabled, manualOverrideProfileID == nil else {
            return
        }

        if let match = ProfileMatcher.bestMatch(for: latestContext, in: profiles), match.confidence >= 0.7 {
            applyProfile(id: match.profile.id, source: "Auto")
            lastEventMessage = "Auto applied \(match.profile.name): \(match.reasons.joined(separator: ", "))"
        }
    }

    func requestCurrentLocation() {
        detector.requestFreshLocation()
        refreshNow()
    }

    func openLocationSettings() {
        detector.openLocationSettings()
    }

    func applyProfile(id: UUID, source: String = "Manual") {
        guard let profile = profiles.first(where: { $0.id == id }) else {
            return
        }

        var applied: [String] = []
        if let mic = profile.preferences.microphoneName, AudioDeviceManager.setDefaultInput(named: mic) {
            applied.append("Mic: \(mic)")
        }
        if let speaker = profile.preferences.speakerName, AudioDeviceManager.setDefaultOutput(named: speaker) {
            applied.append("Speaker: \(speaker)")
        }

        activeProfileID = id
        lastEventMessage = applied.isEmpty
            ? "\(source) applied \(profile.name) (no audio changes succeeded)"
            : "\(source) applied \(profile.name): \(applied.joined(separator: ", "))"
    }

    func setManualOverride(_ id: UUID?) {
        manualOverrideProfileID = id
        if let id {
            applyProfile(id: id, source: "Override")
        }
        saveSettings()
    }

    func setAutoMode(_ enabled: Bool) {
        autoModeEnabled = enabled
        if enabled {
            manualOverrideProfileID = nil
            refreshNow()
        }
        saveSettings()
    }

    func upsertProfile(_ profile: DockProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        store.saveProfiles(profiles)
        refreshNow()
    }

    func removeProfile(_ profile: DockProfile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfileID == profile.id {
            activeProfileID = nil
        }
        if manualOverrideProfileID == profile.id {
            manualOverrideProfileID = nil
        }
        store.saveProfiles(profiles)
        saveSettings()
    }

    private func saveSettings() {
        store.saveSettings(.init(autoModeEnabled: autoModeEnabled, manualOverrideProfileID: manualOverrideProfileID))
    }

    private func startAutoPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshNow()
            }
        }
    }

    private static func defaultProfiles() -> [DockProfile] {
        [
            DockProfile(
                name: "Home",
                iconSymbol: "house.fill",
                matching: MatchingRules(
                    dockNameContains: "Display",
                    wifiSSID: nil,
                    latitude: nil,
                    longitude: nil,
                    radiusMeters: 100
                ),
                preferences: DevicePreferences(
                    microphoneName: "Yeti",
                    speakerName: nil,
                    cameraName: "Insta360"
                )
            ),
            DockProfile(
                name: "Work",
                iconSymbol: "building.2.fill",
                matching: MatchingRules(
                    dockNameContains: nil,
                    wifiSSID: nil,
                    latitude: nil,
                    longitude: nil,
                    radiusMeters: 100
                ),
                preferences: DevicePreferences(
                    microphoneName: nil,
                    speakerName: nil,
                    cameraName: nil
                )
            )
        ]
    }
}
