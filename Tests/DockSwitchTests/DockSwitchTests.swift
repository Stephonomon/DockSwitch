import Testing
@testable import DockSwitch

struct ProfileMatcherTests {
    private func makeProfile(
        name: String,
        dock: String? = nil,
        ssid: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radiusMeters: Double? = nil
    ) -> DockProfile {
        DockProfile(
            name: name,
            matching: MatchingRules(
                dockNameContains: dock,
                wifiSSID: ssid,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters
            ),
            preferences: DevicePreferences(microphoneName: nil, speakerName: nil, cameraName: nil)
        )
    }

    private func makeContext(
        dockName: String? = nil,
        ssid: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) -> DetectionContext {
        DetectionContext(
            dockName: dockName,
            dockCandidates: dockName.map { [$0] } ?? [],
            wifiSSID: ssid,
            wifiCandidates: ssid.map { [$0] } ?? [],
            latitude: latitude,
            longitude: longitude,
            locationAuthorized: true,
            observedAt: .now
        )
    }

    @Test func matcherPrefersCombinedSignals() throws {
        let home = makeProfile(name: "Home", dock: "SD5900", ssid: "MyHomeWiFi")
        let context = makeContext(dockName: "SD5900T/SD5910T/SD5920T", ssid: "MyHomeWiFi")

        let match = try #require(ProfileMatcher.bestMatch(for: context, in: [home]))
        #expect(match.profile.name == "Home")
        #expect(match.confidence > 0.9)
    }

    @Test func profileWithNoMatchedSignalsIsNotAMatch() {
        let work = makeProfile(name: "Work", dock: "CalDigit", ssid: "OfficeWiFi")
        let context = makeContext(dockName: "SD5900T", ssid: "MyHomeWiFi")

        #expect(ProfileMatcher.bestMatch(for: context, in: [work]) == nil)
    }

    @Test func profileWithNoRulesIsNotAMatch() {
        let empty = makeProfile(name: "Empty")
        let context = makeContext(dockName: "SD5900T", ssid: "MyHomeWiFi")

        #expect(ProfileMatcher.bestMatch(for: context, in: [empty]) == nil)
    }

    @Test func multiSignalMatchBeatsSingleSignalMatch() throws {
        let single = makeProfile(name: "Single", ssid: "MyHomeWiFi")
        let combined = makeProfile(name: "Combined", dock: "SD5900", ssid: "MyHomeWiFi")
        let context = makeContext(dockName: "SD5900T", ssid: "MyHomeWiFi")

        let match = try #require(ProfileMatcher.bestMatch(for: context, in: [single, combined]))
        #expect(match.profile.name == "Combined")
    }

    @Test func partialMatchStillWinsOverNoMatch() throws {
        let home = makeProfile(name: "Home", dock: "SD5900", ssid: "MyHomeWiFi")
        let work = makeProfile(name: "Work", dock: "CalDigit", ssid: "OfficeWiFi")
        let context = makeContext(ssid: "MyHomeWiFi")

        let match = try #require(ProfileMatcher.bestMatch(for: context, in: [home, work]))
        #expect(match.profile.name == "Home")
        #expect(match.confidence < 1.0)
    }

    @Test func geofenceMatchesInsideRadiusOnly() throws {
        // Philadelphia City Hall; ~500m offset in latitude is ~0.0045 degrees.
        let inside = makeProfile(name: "Inside", latitude: 39.9526, longitude: -75.1652, radiusMeters: 1000)
        let outside = makeProfile(name: "Outside", latitude: 39.9526, longitude: -75.1652, radiusMeters: 100)
        let context = makeContext(latitude: 39.9571, longitude: -75.1652)

        let match = try #require(ProfileMatcher.bestMatch(for: context, in: [inside, outside]))
        #expect(match.profile.name == "Inside")
        #expect(ProfileMatcher.bestMatch(for: context, in: [outside]) == nil)
    }

    @Test func ssidComparisonIsCaseInsensitiveAndExact() {
        let home = makeProfile(name: "Home", ssid: "MyHomeWiFi")

        #expect(ProfileMatcher.bestMatch(for: makeContext(ssid: "myhomewifi"), in: [home]) != nil)
        #expect(ProfileMatcher.bestMatch(for: makeContext(ssid: "MyHomeWiFi-Guest"), in: [home]) == nil)
    }

    @Test func autoApplyDisabledProfileIsSkipped() {
        var home = makeProfile(name: "Home", ssid: "MyHomeWiFi")
        home.autoApplyEnabled = false

        #expect(ProfileMatcher.bestMatch(for: makeContext(ssid: "MyHomeWiFi"), in: [home]) == nil)
    }
}

struct DockHardwareDetectorTests {
    private let sampleOutput = """
    Thunderbolt/USB4:

        Thunderbolt/USB4 Bus 0:

          Vendor Name: Apple Inc.
          Device Name: MacBook Pro
          UID: 0x0001

          Kensington SD5900T:

            Vendor Name: Kensington
            Device ID: 0x1234
            Status:
            Link Status: 0x2
            Speed: Up to 40 Gb/s

        Thunderbolt/USB4 Bus 1:

          Port:

            Status: No device connected
    """

    @Test func parsesDockNamesAndSkipsGenericHeaders() {
        let names = DockHardwareDetector.parseDockCandidates(from: sampleOutput)
        #expect(names == ["Kensington SD5900T"])
    }

    @Test func emptyOutputYieldsNoCandidates() {
        #expect(DockHardwareDetector.parseDockCandidates(from: "").isEmpty)
    }
}
