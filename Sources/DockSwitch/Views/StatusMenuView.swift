import Foundation
import MapKit
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var state: AppState

    @State private var isShowingEditor = false
    @State private var editingProfile: DockProfile?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color(red: 0.9, green: 0.95, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    detectionCard
                    profilesCard
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isShowingEditor) {
            ProfileEditorView(
                profile: editingProfile,
                deviceCatalog: state.deviceCatalog,
                latestContext: state.latestContext,
                suggestedDocks: state.suggestedDockNames,
                suggestedSSIDs: state.suggestedSSIDs,
                onRequestCurrentLocation: {
                    state.requestCurrentLocation()
                }
            ) { saved in
                state.upsertProfile(saved)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DockSwitch")
                .font(.system(size: 23, weight: .bold, design: .rounded))
            Text("Active: \(state.activeProfileName)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(state.lastEventMessage)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var detectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Auto mode", isOn: Binding(
                    get: { state.autoModeEnabled },
                    set: { state.setAutoMode($0) }
                ))
                .toggleStyle(.switch)

                Button("Refresh") {
                    state.refreshNow()
                }
                .buttonStyle(.bordered)
            }

            Text(state.detectedContextLabel)
                .font(.system(size: 12, weight: .regular, design: .rounded))
            Text("Best match: \(state.latestMatchSummary)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if state.manualOverrideProfileID != nil {
                Button("Clear manual override") {
                    state.setManualOverride(nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profiles")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button("New") {
                    editingProfile = nil
                    isShowingEditor = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }

            ForEach(state.profiles) { profile in
                HStack(spacing: 8) {
                    Image(systemName: profile.iconSymbol)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text(summary(for: profile))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Apply") {
                        state.setManualOverride(profile.id)
                    }
                    .buttonStyle(.bordered)
                    Button("Edit") {
                        editingProfile = profile
                        isShowingEditor = true
                    }
                    .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        state.removeProfile(profile)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summary(for profile: DockProfile) -> String {
        let wifi = profile.matching.wifiSSID ?? "Any Wi-Fi"
        let dock = profile.matching.dockNameContains ?? "Any dock"
        let mic = profile.preferences.microphoneName ?? "No mic preference"
        return "\(wifi) | \(dock) | \(mic)"
    }
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var existingProfile: DockProfile?
    var deviceCatalog: DeviceCatalog
    var latestContext: DetectionContext
    var suggestedDocks: [String]
    var suggestedSSIDs: [String]
    var onRequestCurrentLocation: () -> Void
    var onSave: (DockProfile) -> Void

    @State private var name: String
    @State private var iconSymbol: String
    @State private var dockNameContains: String
    @State private var wifiSSID: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var radiusMeters: Double
    @State private var microphoneName: String
    @State private var speakerName: String
    @State private var cameraName: String
    @State private var dockSuggestionSelection: String
    @State private var wifiSuggestionSelection: String
    @State private var mapRegion: MKCoordinateRegion

    init(
        profile: DockProfile?,
        deviceCatalog: DeviceCatalog,
        latestContext: DetectionContext,
        suggestedDocks: [String],
        suggestedSSIDs: [String],
        onRequestCurrentLocation: @escaping () -> Void,
        onSave: @escaping (DockProfile) -> Void
    ) {
        existingProfile = profile
        self.deviceCatalog = deviceCatalog
        self.latestContext = latestContext
        self.suggestedDocks = suggestedDocks
        self.suggestedSSIDs = suggestedSSIDs
        self.onRequestCurrentLocation = onRequestCurrentLocation
        self.onSave = onSave

        let profileDock = profile?.matching.dockNameContains ?? ""
        let profileWiFi = profile?.matching.wifiSSID ?? ""

        let initialCenter = Self.initialCoordinate(profile: profile, latestContext: latestContext)
        let initialRadius = profile?.matching.radiusMeters ?? 100
        let initialSpanDelta = max(initialRadius / 40_000, 0.003)

        _name = State(initialValue: profile?.name ?? "")
        _iconSymbol = State(initialValue: profile?.iconSymbol ?? "mappin.and.ellipse")
        _dockNameContains = State(initialValue: profileDock)
        _wifiSSID = State(initialValue: profileWiFi)
        _latitude = State(initialValue: profile?.matching.latitude.map { String($0) } ?? "")
        _longitude = State(initialValue: profile?.matching.longitude.map { String($0) } ?? "")
        _radiusMeters = State(initialValue: initialRadius)
        _microphoneName = State(initialValue: profile?.preferences.microphoneName ?? "")
        _speakerName = State(initialValue: profile?.preferences.speakerName ?? "")
        _cameraName = State(initialValue: profile?.preferences.cameraName ?? "")
        _dockSuggestionSelection = State(initialValue: suggestedDocks.contains(profileDock) ? profileDock : "")
        _wifiSuggestionSelection = State(initialValue: suggestedSSIDs.contains(profileWiFi) ? profileWiFi : "")
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: initialCenter,
            span: MKCoordinateSpan(latitudeDelta: initialSpanDelta, longitudeDelta: initialSpanDelta)
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(existingProfile == nil ? "New Profile" : "Edit Profile")
                    .font(.title2.weight(.bold))

                contextShortcuts

                Group {
                    labeledField("Name", text: $name)
                    labeledField("SF Symbol", text: $iconSymbol)
                    matchingSection
                    locationSection
                    deviceSection
                }

                HStack {
                    Spacer()
                    Button("Cancel") { dismiss() }
                    Button("Save") {
                        onSave(buildProfile())
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(18)
            .frame(width: 460)
        }
        .onChange(of: latitude) { _, _ in
            syncMapFromTextIfNeeded()
        }
        .onChange(of: longitude) { _, _ in
            syncMapFromTextIfNeeded()
        }
        .onChange(of: latestContext.latitude) { _, _ in
            if let lat = latestContext.latitude, let lon = latestContext.longitude {
                mapRegion.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
    }

    private var contextShortcuts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Fill")
                .font(.caption.weight(.semibold))

            Text("Detected now: \(latestContext.dockName ?? "No dock") | \(latestContext.wifiSSID ?? "No Wi-Fi")")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Use current dock") {
                    if let dock = latestContext.dockName {
                        dockNameContains = dock
                    }
                }
                .buttonStyle(.bordered)

                Button("Use current Wi-Fi") {
                    if let ssid = latestContext.wifiSSID {
                        wifiSSID = ssid
                    }
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button("Locate me now") {
                    onRequestCurrentLocation()
                }
                .buttonStyle(.borderedProminent)

                Button("Use current location") {
                    guard let lat = latestContext.latitude, let lon = latestContext.longitude else {
                        return
                    }
                    setLocation(lat: lat, lon: lon)
                }
                .buttonStyle(.bordered)
                .disabled(latestContext.latitude == nil || latestContext.longitude == nil)

                Button("Clear location") {
                    latitude = ""
                    longitude = ""
                }
                .buttonStyle(.bordered)
            }

            if !latestContext.locationAuthorized {
                Text("Location permission is needed for current location and better Wi-Fi scan results.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var matchingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            labeledField("Dock name contains", text: $dockNameContains)
            if !suggestedDocks.isEmpty {
                Picker("Detected docks", selection: $dockSuggestionSelection) {
                    Text("Select detected dock").tag("")
                    ForEach(suggestedDocks, id: \.self) { dock in
                        Text(dock).tag(dock)
                    }
                }
                .onChange(of: dockSuggestionSelection) { _, value in
                    guard !value.isEmpty else { return }
                    dockNameContains = value
                }
            }

            labeledField("Wi-Fi SSID", text: $wifiSSID)
            if !suggestedSSIDs.isEmpty {
                Text("Nearby Wi-Fi found: \(suggestedSSIDs.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Detected Wi-Fi", selection: $wifiSuggestionSelection) {
                    Text("Select detected Wi-Fi").tag("")
                    ForEach(suggestedSSIDs, id: \.self) { ssid in
                        Text(ssid).tag(ssid)
                    }
                }
                .onChange(of: wifiSuggestionSelection) { _, value in
                    guard !value.isEmpty else { return }
                    wifiSSID = value
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location & Radius")
                .font(.caption.weight(.semibold))

            ZStack {
                Map(coordinateRegion: $mapRegion)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.red)
                    .shadow(radius: 2)
            }

            Text("Pan map, then lock location from center")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Use map center") {
                    setLocation(lat: mapRegion.center.latitude, lon: mapRegion.center.longitude)
                }
                .buttonStyle(.bordered)

                Button("Center on current location") {
                    guard let lat = latestContext.latitude, let lon = latestContext.longitude else {
                        return
                    }
                    mapRegion.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                .buttonStyle(.bordered)
                .disabled(latestContext.latitude == nil || latestContext.longitude == nil)
            }

            labeledField("Latitude", text: $latitude)
            labeledField("Longitude", text: $longitude)

            Stepper(value: $radiusMeters, in: 25...5000, step: 25) {
                Text("Radius meters: \(Int(radiusMeters))")
                    .font(.caption)
            }
        }
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferred Devices")
                .font(.caption.weight(.semibold))

            devicePicker("Preferred microphone", selection: $microphoneName, options: deviceCatalog.microphones)
            devicePicker("Preferred speaker", selection: $speakerName, options: deviceCatalog.speakers)
            devicePicker("Preferred camera", selection: $cameraName, options: deviceCatalog.cameras)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold))
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func devicePicker(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold))
            Picker(label, selection: selection) {
                Text("No preference").tag("")
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
        }
    }

    private func buildProfile() -> DockProfile {
        let hasLocation = Double(latitude) != nil && Double(longitude) != nil

        return DockProfile(
            id: existingProfile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconSymbol: iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mappin.and.ellipse" : iconSymbol,
            autoApplyEnabled: true,
            matching: MatchingRules(
                dockNameContains: optionalString(dockNameContains),
                wifiSSID: optionalString(wifiSSID),
                latitude: Double(latitude),
                longitude: Double(longitude),
                radiusMeters: hasLocation ? radiusMeters : nil
            ),
            preferences: DevicePreferences(
                microphoneName: optionalString(microphoneName),
                speakerName: optionalString(speakerName),
                cameraName: optionalString(cameraName)
            )
        )
    }

    private func setLocation(lat: Double, lon: Double) {
        latitude = String(lat)
        longitude = String(lon)
        mapRegion.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func syncMapFromTextIfNeeded() {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            return
        }

        let candidate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let current = mapRegion.center
        let latDiff = abs(current.latitude - candidate.latitude)
        let lonDiff = abs(current.longitude - candidate.longitude)
        if latDiff > 0.000001 || lonDiff > 0.000001 {
            mapRegion.center = candidate
        }
    }

    private static func initialCoordinate(profile: DockProfile?, latestContext: DetectionContext) -> CLLocationCoordinate2D {
        if let lat = profile?.matching.latitude, let lon = profile?.matching.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let lat = latestContext.latitude, let lon = latestContext.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    }

    private func optionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
