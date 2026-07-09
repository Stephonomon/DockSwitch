import Foundation

enum ProfileMatcher {
    static func bestMatch(for context: DetectionContext, in profiles: [DockProfile]) -> ProfileMatch? {
        let matches = profiles
            .filter(\ .autoApplyEnabled)
            .compactMap { profile in
                score(profile: profile, context: context)
            }
            .sorted { $0.confidence > $1.confidence }

        return matches.first
    }

    static func score(profile: DockProfile, context: DetectionContext) -> ProfileMatch? {
        var score: Double = 0
        var maxScore: Double = 0
        var reasons: [String] = []

        if let expectedSSID = profile.matching.wifiSSID, !expectedSSID.isEmpty {
            maxScore += 0.35
            if context.wifiSSID?.caseInsensitiveCompare(expectedSSID) == .orderedSame {
                score += 0.35
                reasons.append("Wi-Fi matched \(expectedSSID)")
            }
        }

        if let dockHint = profile.matching.dockNameContains, !dockHint.isEmpty {
            maxScore += 0.4
            if let dockName = context.dockName,
               dockName.localizedCaseInsensitiveContains(dockHint) {
                score += 0.4
                reasons.append("Dock signature matched \(dockHint)")
            }
        }

        if let lat = profile.matching.latitude,
           let lon = profile.matching.longitude,
           let radius = profile.matching.radiusMeters,
           let observedLat = context.latitude,
           let observedLon = context.longitude {
            maxScore += 0.25
            let distance = haversineMeters(lat1: lat, lon1: lon, lat2: observedLat, lon2: observedLon)
            if distance <= radius {
                score += 0.25
                reasons.append(String(format: "Within %.0fm geofence", radius))
            }
        }

        guard maxScore > 0 else {
            return nil
        }

        let confidence = score / maxScore
        return ProfileMatch(profile: profile, confidence: confidence, reasons: reasons)
    }

    private static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
            sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }
}
