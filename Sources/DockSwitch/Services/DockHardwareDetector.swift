import Foundation

enum DockHardwareDetector {
    static func currentDockCandidates() -> [String] {
        guard let output = runSystemProfiler() else {
            return []
        }
        return parseDockCandidates(from: output)
    }

    static func parseDockCandidates(from output: String) -> [String] {
        let genericHeaders: Set<String> = [
            "Thunderbolt/USB4",
            "Thunderbolt/USB4 Bus 0",
            "Thunderbolt/USB4 Bus 1",
            "Port",
            "Port (Upstream)",
            "Vendor Name",
            "Device Name",
            "UID",
            "Route String",
            "Domain UUID",
            "Status",
            "Link Status",
            "Speed",
            "Receptacle",
            "Micro Firmware Version",
            "Mode",
            "Device ID",
            "Vendor ID",
            "Device Revision",
            "Firmware Version"
        ]

        var names: [String] = []
        for rawLine in output.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasSuffix(":"), !line.contains("\t") else {
                continue
            }

            let candidate = String(line.dropLast())
            if candidate.isEmpty || genericHeaders.contains(candidate) {
                continue
            }
            if candidate == "iOS" {
                continue
            }
            names.append(candidate)
        }

        let unique = Array(Set(names)).sorted()
        let preferred = unique.filter { seemsLikeDock($0) }
        if !preferred.isEmpty {
            return preferred
        }
        return unique
    }

    private static func runSystemProfiler() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPThunderboltDataType", "-detailLevel", "mini"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        // Drain stdout before waiting so the child can't deadlock on a full pipe buffer.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func seemsLikeDock(_ text: String) -> Bool {
        let lowercase = text.lowercased()
        let keywords = [
            "dock", "displaylink", "kensington", "caldigit", "belkin", "hub", "thunderbolt", "usb4"
        ]
        return keywords.contains(where: { lowercase.contains($0) })
    }
}
