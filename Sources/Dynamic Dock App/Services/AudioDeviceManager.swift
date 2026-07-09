import CoreAudio
import Foundation

struct AudioDeviceList {
    var inputs: [String]
    var outputs: [String]
}

enum AudioDeviceManager {
    static func listAudioDevices() -> AudioDeviceList {
        let all = allDeviceIDs()
        var inputs: [String] = []
        var outputs: [String] = []

        for device in all {
            if hasScope(deviceID: device, scope: kAudioDevicePropertyScopeInput) {
                inputs.append(deviceName(device) ?? "Unknown Input")
            }
            if hasScope(deviceID: device, scope: kAudioDevicePropertyScopeOutput) {
                outputs.append(deviceName(device) ?? "Unknown Output")
            }
        }

        return AudioDeviceList(inputs: inputs.sorted(), outputs: outputs.sorted())
    }

    @discardableResult
    static func setDefaultInput(named name: String) -> Bool {
        setDefaultDevice(named: name, selector: kAudioHardwarePropertyDefaultInputDevice, scope: kAudioDevicePropertyScopeInput)
    }

    @discardableResult
    static func setDefaultOutput(named name: String) -> Bool {
        setDefaultDevice(named: name, selector: kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioDevicePropertyScopeOutput)
    }

    private static func setDefaultDevice(named name: String, selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope) -> Bool {
        let candidate = allDeviceIDs().first {
            hasScope(deviceID: $0, scope: scope) && (deviceName($0)?.caseInsensitiveCompare(name) == .orderedSame)
        }

        guard var device = candidate else {
            return false
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &device
        )

        return status == noErr
    }

    private static func allDeviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )

        guard sizeStatus == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = Array(repeating: AudioObjectID(0), count: count)

        let getStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        return getStatus == noErr ? deviceIDs : []
    }

    private static func deviceName(_ deviceID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        return status == noErr ? (name as String) : nil
    }

    private static func hasScope(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        return status == noErr && size > 0
    }
}
