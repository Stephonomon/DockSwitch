import XCTest
@testable import DockSwitch

final class DockSwitchTests: XCTestCase {
    func testMatcherPrefersCombinedSignals() throws {
        let home = DockProfile(
            name: "Home",
            matching: MatchingRules(
                dockNameContains: "SD5900",
                wifiSSID: "MyHomeWiFi",
                latitude: nil,
                longitude: nil,
                radiusMeters: nil
            ),
            preferences: DevicePreferences(microphoneName: "Yeti", speakerName: nil, cameraName: nil)
        )

        let context = DetectionContext(
            dockName: "SD5900T/SD5910T/SD5920T",
            wifiSSID: "MyHomeWiFi",
            latitude: nil,
            longitude: nil,
            observedAt: .now
        )

        let match = try XCTUnwrap(ProfileMatcher.bestMatch(for: context, in: [home]))
        XCTAssertEqual(match.profile.name, "Home")
        XCTAssertGreaterThan(match.confidence, 0.9)
    }
}
