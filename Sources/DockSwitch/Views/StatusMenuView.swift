import Foundation
import MapKit
import SwiftUI

private enum LiquidGlassTheme {
    static let ocean = Color(red: 0.17, green: 0.44, blue: 0.76)
    static let mint = Color(red: 0.37, green: 0.74, blue: 0.7)
    static let frost = Color.white.opacity(0.2)
    static let edge = Color.white.opacity(0.36)
    static let glow = Color.white.opacity(0.6)
}

struct StatusMenuView: View {
    @ObservedObject var state: AppState

    @State private var isShowingEditor = false
    @State private var editingProfile: DockProfile?

    var body: some View {
        ZStack {
            liquidBackground

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
                },
                onOpenLocationSettings: {
                    state.openLocationSettings()
                },
                onRefreshContext: {
                    state.refreshNow()
                }
            ) { saved in
                state.upsertProfile(saved)
            }
        }
    }

    private var liquidBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.95, blue: 1.0),
                    Color(red: 0.78, green: 0.89, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(LiquidGlassTheme.mint.opacity(0.25))
                .frame(width: 240, height: 240)
                .blur(radius: 40)
                .offset(x: -120, y: -170)

            Circle()
                .fill(LiquidGlassTheme.ocean.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 45)
                .offset(x: 130, y: 220)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(LiquidGlassTheme.ocean)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("DockSwitch")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Active: \(state.activeProfileName)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(state.lastEventMessage)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .glassCard()
    }

    private var detectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Context")

            HStack {
                Toggle("Auto Mode", isOn: Binding(
                    get: { state.autoModeEnabled },
                    set: { state.setAutoMode($0) }
                ))
                .toggleStyle(.switch)

                Spacer()

                Button("Refresh") {
                    state.refreshNow()
                }
                .buttonStyle(.borderedProminent)
                .tint(LiquidGlassTheme.ocean)
                .controlSize(.small)
            }

            Text(state.detectedContextLabel)
                .font(.system(size: 12, weight: .regular, design: .rounded))

            Text("Best match: \(state.latestMatchSummary)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            if state.manualOverrideProfileID != nil {
                Button("Clear manual override") {
                    state.setManualOverride(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .glassCard()
    }

    private var profilesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Profiles")
                Spacer()
                Button("New") {
                    editingProfile = nil
                    isShowingEditor = true
                }
                .buttonStyle(.borderedProminent)
                .tint(LiquidGlassTheme.ocean)
                .controlSize(.small)
            }

            ForEach(state.profiles) { profile in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LiquidGlassTheme.frost)
                        Image(systemName: profileSymbol(for: profile))
                            .foregroundStyle(LiquidGlassTheme.ocean)
                    }
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text(summary(for: profile))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button("Apply") {
                        state.setManualOverride(profile.id)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Edit") {
                        editingProfile = profile
                        isShowingEditor = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        state.removeProfile(profile)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(LiquidGlassTheme.edge, lineWidth: 0.8)
                        )
                )
            }
        }
        .glassCard()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.92))
    }

    private func profileSymbol(for profile: DockProfile) -> String {
        profileSymbol(forName: profile.name)
    }

    private func profileSymbol(forName name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("home") {
            return "house.fill"
        }
        if lower.contains("work") || lower.contains("office") {
            return "building.2.fill"
        }
        return "arrow.left.arrow.right.circle.fill"
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
    var onOpenLocationSettings: () -> Void
    var onRefreshContext: () -> Void
    var onSave: (DockProfile) -> Void

    @State private var name: String
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
        onOpenLocationSettings: @escaping () -> Void,
        onRefreshContext: @escaping () -> Void,
        onSave: @escaping (DockProfile) -> Void
    ) {
        existingProfile = profile
        self.deviceCatalog = deviceCatalog
        self.latestContext = latestContext
        self.suggestedDocks = suggestedDocks
        self.suggestedSSIDs = suggestedSSIDs
        self.onRequestCurrentLocation = onRequestCurrentLocation
        self.onOpenLocationSettings = onOpenLocationSettings
        self.onRefreshContext = onRefreshContext
        self.onSave = onSave

        let profileDock = profile?.matching.dockNameContains ?? ""
        let profileWiFi = profile?.matching.wifiSSID ?? ""

        let initialCenter = Self.initialCoordinate(profile: profile, latestContext: latestContext)
        let initialRadius = profile?.matching.radiusMeters ?? 100
        let initialSpanDelta = max(initialRadius / 40_000, 0.003)

        _name = State(initialValue: profile?.name ?? "")
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
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.98, blue: 1.0), Color(red: 0.86, green: 0.94, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(existingProfile == nil ? "New Profile" : "Edit Profile")
                        .font(.title2.weight(.bold))

                    contextShortcuts

                    Group {
                        labeledField("Name", text: $name)
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
                        .tint(LiquidGlassTheme.ocean)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(18)
                .frame(width: 470)
            }
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
                .tint(LiquidGlassTheme.ocean)

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

                Button("Open Location Settings") {
                    onOpenLocationSettings()
                }
                .buttonStyle(.bordered)
            }
        }
        .glassCard(padding: 10)
    }

    private var matchingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matching")
                .font(.caption.weight(.semibold))

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
            HStack {
                Text("Connected network: \(latestContext.wifiSSID ?? "Unavailable")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Refresh Wi-Fi list") {
                    onRefreshContext()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

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
        .glassCard(padding: 10)
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location & Radius")
                .font(.caption.weight(.semibold))

            ZStack {
                Map(coordinateRegion: $mapRegion)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LiquidGlassTheme.ocean)
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
        .glassCard(padding: 10)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferred Devices")
                .font(.caption.weight(.semibold))

            devicePicker("Preferred microphone", selection: $microphoneName, options: deviceCatalog.microphones)
            devicePicker("Preferred speaker", selection: $speakerName, options: deviceCatalog.speakers)
            devicePicker("Preferred camera", selection: $cameraName, options: deviceCatalog.cameras)
        }
        .glassCard(padding: 10)
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
            iconSymbol: existingProfile?.iconSymbol ?? "arrow.left.arrow.right.circle",
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

private extension View {
    func glassCard(padding: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LiquidGlassTheme.edge, lineWidth: 0.9)
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LiquidGlassTheme.glow, lineWidth: 0.7)
                            .blur(radius: 1.2)
                            .opacity(0.5)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
            )
    }
}
