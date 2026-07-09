import AppKit
import CoreLocation
import CoreWLAN
import Foundation

final class ContextDetector: NSObject {
    private let locationManager = CLLocationManager()
    private var latestLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermissions() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            requestAuthorizationPrompt()
        }
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }

    func requestFreshLocation() {
        requestPermissions()
    }

    func openLocationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity",
            "x-apple.systempreferences:com.apple.settings",
            "x-apple.systempreferences:"
        ]

        for raw in urls {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func snapshot() -> DetectionContext {
        let wifi = detectedWiFi()
        let dockCandidates = DockHardwareDetector.currentDockCandidates()
        let fallbackScreens = NSScreen.screens
            .filter { $0 != NSScreen.main }
            .map(\ .localizedName)

        let allDockCandidates = Array(Set(dockCandidates + fallbackScreens)).sorted()

        let location = latestLocation ?? locationManager.location
        let status = locationManager.authorizationStatus
        let locationAuthorized = status == .authorizedAlways || status == .authorized

        return DetectionContext(
            dockName: allDockCandidates.first,
            dockCandidates: allDockCandidates,
            wifiSSID: wifi.current,
            wifiCandidates: wifi.candidates,
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            locationAuthorized: locationAuthorized,
            observedAt: Date()
        )
    }

    private func requestAuthorizationPrompt() {
        #if os(macOS)
        locationManager.requestAlwaysAuthorization()
        #else
        locationManager.requestWhenInUseAuthorization()
        #endif
    }

    private func detectedWiFi() -> (current: String?, candidates: [String]) {
        var current: String?
        var allNames: [String] = []

        let interfaces = CWWiFiClient.shared().interfaces() ?? []
        for interface in interfaces {
            if current == nil,
               let ssid = interface.ssid()?.trimmingCharacters(in: .whitespacesAndNewlines),
               !ssid.isEmpty {
                current = ssid
            }

            if let scanned = try? interface.scanForNetworks(withName: nil) {
                allNames.append(contentsOf: scanned.compactMap { network in
                    guard let ssid = network.ssid?.trimmingCharacters(in: .whitespacesAndNewlines), !ssid.isEmpty else {
                        return nil
                    }
                    return ssid
                })
            }
        }

        if let fromNetworkSetup = currentSSIDFromNetworkSetup(), !fromNetworkSetup.isEmpty {
            current = fromNetworkSetup
            allNames.append(fromNetworkSetup)
        }

        if let current {
            allNames.append(current)
        }

        let unique = Array(Set(allNames)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return (current, unique)
    }

    private func currentSSIDFromNetworkSetup() -> String? {
        for device in ["en0", "en1"] {
            guard let output = runNetworkSetup(on: device) else {
                continue
            }

            if let range = output.range(of: "Current Wi-Fi Network:") {
                let tail = output[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !tail.isEmpty,
                   !tail.localizedCaseInsensitiveContains("not associated") {
                    return tail
                }
            }
        }
        return nil
    }

    private func runNetworkSetup(on device: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getairportnetwork", device]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}

extension ContextDetector: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Best-effort detector; failures are non-fatal.
    }
}
