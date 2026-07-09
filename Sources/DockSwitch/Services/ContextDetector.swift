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
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
        locationManager.requestLocation()
    }

    func requestFreshLocation() {
        requestPermissions()
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

        if let current {
            allNames.append(current)
        }

        let unique = Array(Set(allNames)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return (current, unique)
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
