import AppKit
import CoreLocation
import CoreWLAN
import Foundation

@MainActor
final class ContextDetector: NSObject {
    private let locationManager = CLLocationManager()
    private var latestLocation: CLLocation?
    private var cachedWifiCandidates: [String] = []

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermissions() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
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

    /// Gathers the current context. Wi-Fi/dock probing (CoreWLAN, subprocesses)
    /// runs off the main actor so callers never block the UI. A full Wi-Fi scan
    /// is slow and disruptive to the network, so it only happens when
    /// `fullWifiScan` is true (profile editor / explicit refresh).
    func snapshot(fullWifiScan: Bool = false) async -> DetectionContext {
        let fallbackScreens = Self.externalScreenNames()
        let location = latestLocation ?? locationManager.location
        let status = locationManager.authorizationStatus
        let locationAuthorized = status == .authorizedAlways || status == .authorized

        let (wifi, dockCandidates) = await Task.detached(priority: .utility) {
            (Self.detectWiFi(fullScan: fullWifiScan), DockHardwareDetector.currentDockCandidates())
        }.value

        if fullWifiScan {
            cachedWifiCandidates = wifi.candidates
        }
        var wifiCandidateSet = Set(cachedWifiCandidates)
        if let current = wifi.current {
            wifiCandidateSet.insert(current)
        }

        let allDockCandidates = Array(Set(dockCandidates + fallbackScreens)).sorted()
        let dockName = allDockCandidates.first(where: { DockHardwareDetector.seemsLikeDock($0) })
            ?? allDockCandidates.first

        return DetectionContext(
            dockName: dockName,
            dockCandidates: allDockCandidates,
            wifiSSID: wifi.current,
            wifiCandidates: wifiCandidateSet.sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            },
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            locationAuthorized: locationAuthorized,
            observedAt: Date()
        )
    }

    private static func externalScreenNames() -> [String] {
        NSScreen.screens
            .filter { screen in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                    return false
                }
                return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) == 0
            }
            .map(\ .localizedName)
    }

    private nonisolated static func detectWiFi(fullScan: Bool) -> (current: String?, candidates: [String]) {
        var current: String?
        var allNames: [String] = []

        let interfaces = CWWiFiClient.shared().interfaces() ?? []
        for interface in interfaces {
            if current == nil,
               let ssid = interface.ssid()?.trimmingCharacters(in: .whitespacesAndNewlines),
               !ssid.isEmpty {
                current = ssid
            }

            if fullScan, let scanned = try? interface.scanForNetworks(withName: nil) {
                allNames.append(contentsOf: scanned.compactMap { network in
                    guard let ssid = network.ssid?.trimmingCharacters(in: .whitespacesAndNewlines), !ssid.isEmpty else {
                        return nil
                    }
                    return ssid
                })
            }
        }

        // CoreWLAN hides the SSID without location permission; fall back to
        // networksetup only when needed to avoid spawning a subprocess per poll.
        if current == nil, let fromNetworkSetup = currentSSIDFromNetworkSetup(), !fromNetworkSetup.isEmpty {
            current = fromNetworkSetup
        }

        if let current {
            allNames.append(current)
        }

        let unique = Array(Set(allNames)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return (current, unique)
    }

    private nonisolated static func currentSSIDFromNetworkSetup() -> String? {
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

    private nonisolated static func runNetworkSetup(on device: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-getairportnetwork", device]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Drain stdout before waiting so the child can't deadlock on a full pipe buffer.
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

extension ContextDetector: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else {
            return
        }
        Task { @MainActor in
            self.latestLocation = latest
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Best-effort detector; failures are non-fatal.
    }
}
