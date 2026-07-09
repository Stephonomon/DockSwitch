import CoreAudio
import Foundation

struct AudioDeviceList {
    var inputs: [String]
    var outputs: [String]
}

enum AudioDeviceManager {
    static func listAudioDevices() -> AudioDeviceList {
        let all = allDeviceIDs()
        var inputNames: [String] = []
        var outputNames: [String] = []

        for device in all {
            guard let name = deviceName(device) else {
                continue
            }

            if hasScope(deviceID: device, scope: kAudioDevicePropertyScopeInput) {
                inputNames.append(name)
            }

            if hasScope(deviceID: device, scope: kAudioDevicePropertyScopeOutput) {
                outputNames.append(name)
            }
        }

        return AudioDeviceList(
            inputs: dedupedSorted(inputNames),
            outputs: dedupedSorted(outputNames)
        )
    }

    @discardableResult
    static func setDefaultInput(named name: String) -> Bool {
        setDefaultDevice(named: name, selector: kAudioHardwarePropertyDefaultInputDevice, scope: kAudioDevicePropertyScopeInput)
    }

    @discardableResult
    static func setDefaultOutput(named name: String) -> Bool {
        let changed = setDefaultDevice(named: name, selector: kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioDevicePropertyScopeOutput)
        if changed {
            // Route system alerts/sound effects to the same device so nothing
            // keeps playing through the old speakers.
            _ = setDefaultDevice(named: name, selector: kAudioHardwarePropertyDefaultSystemOutputDevice, scope: kAudioDevicePropertyScopeOutput)
        }
        return changed
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

        var name: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? (name as String?) : nil
    }

    private static func hasScope(deviceID: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        // The property size is non-zero even for a device with no streams in
        // this scope (an empty AudioBufferList still has a header), so read the
        // configuration and check for an actual channel.
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }

        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { buffer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, buffer) == noErr else {
            return false
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(buffer.assumingMemoryBound(to: AudioBufferList.self))
        return bufferList.contains { $0.mNumberChannels > 0 }
    }

    private static func dedupedSorted(_ values: [String]) -> [String] {
        Array(Set(values)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}
