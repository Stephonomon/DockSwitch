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
            ProfileEditorView(profile: editingProfile) { saved in
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
    @Environment(\ .dismiss) private var dismiss

    var existingProfile: DockProfile?
    var onSave: (DockProfile) -> Void

    @State private var name: String
    @State private var iconSymbol: String
    @State private var dockNameContains: String
    @State private var wifiSSID: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var radiusMeters: String
    @State private var microphoneName: String
    @State private var speakerName: String
    @State private var cameraName: String

    init(profile: DockProfile?, onSave: @escaping (DockProfile) -> Void) {
        existingProfile = profile
        self.onSave = onSave

        _name = State(initialValue: profile?.name ?? "")
        _iconSymbol = State(initialValue: profile?.iconSymbol ?? "mappin.and.ellipse")
        _dockNameContains = State(initialValue: profile?.matching.dockNameContains ?? "")
        _wifiSSID = State(initialValue: profile?.matching.wifiSSID ?? "")
        _latitude = State(initialValue: profile?.matching.latitude.map { String($0) } ?? "")
        _longitude = State(initialValue: profile?.matching.longitude.map { String($0) } ?? "")
        _radiusMeters = State(initialValue: profile?.matching.radiusMeters.map { String(Int($0)) } ?? "100")
        _microphoneName = State(initialValue: profile?.preferences.microphoneName ?? "")
        _speakerName = State(initialValue: profile?.preferences.speakerName ?? "")
        _cameraName = State(initialValue: profile?.preferences.cameraName ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(existingProfile == nil ? "New Profile" : "Edit Profile")
                .font(.title2.weight(.bold))

            Group {
                labeledField("Name", text: $name)
                labeledField("SF Symbol", text: $iconSymbol)
                labeledField("Dock name contains", text: $dockNameContains)
                labeledField("Wi-Fi SSID", text: $wifiSSID)
                labeledField("Latitude", text: $latitude)
                labeledField("Longitude", text: $longitude)
                labeledField("Radius meters", text: $radiusMeters)
                labeledField("Preferred microphone", text: $microphoneName)
                labeledField("Preferred speaker", text: $speakerName)
                labeledField("Preferred camera", text: $cameraName)
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
        .frame(width: 420)
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.semibold))
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func buildProfile() -> DockProfile {
        DockProfile(
            id: existingProfile?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            iconSymbol: iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "mappin.and.ellipse" : iconSymbol,
            autoApplyEnabled: true,
            matching: MatchingRules(
                dockNameContains: optionalString(dockNameContains),
                wifiSSID: optionalString(wifiSSID),
                latitude: Double(latitude),
                longitude: Double(longitude),
                radiusMeters: Double(radiusMeters)
            ),
            preferences: DevicePreferences(
                microphoneName: optionalString(microphoneName),
                speakerName: optionalString(speakerName),
                cameraName: optionalString(cameraName)
            )
        )
    }

    private func optionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
