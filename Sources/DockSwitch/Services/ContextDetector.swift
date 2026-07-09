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
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func snapshot() -> DetectionContext {
        let wifiSSID = CWWiFiClient.shared().interface()?.ssid()
        let externalScreens = NSScreen.screens
            .filter { $0 != NSScreen.main }
            .map(\ .localizedName)
        let dockName = externalScreens.first

        return DetectionContext(
            dockName: dockName,
            wifiSSID: wifiSSID,
            latitude: latestLocation?.coordinate.latitude,
            longitude: latestLocation?.coordinate.longitude,
            observedAt: Date()
        )
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
