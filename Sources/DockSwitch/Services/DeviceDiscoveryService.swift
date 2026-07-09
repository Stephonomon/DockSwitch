import AVFoundation
import Foundation

struct DeviceCatalog {
    var microphones: [String]
    var speakers: [String]
    var cameras: [String]

    static let empty = DeviceCatalog(microphones: [], speakers: [], cameras: [])
}

enum DeviceDiscoveryService {
    static func currentCatalog() -> DeviceCatalog {
        let audioDevices = AudioDeviceManager.listAudioDevices()
        let cameras = AVCaptureDevice
            .DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external], mediaType: .video, position: .unspecified)
            .devices
            .map(\ .localizedName)
            .sorted()

        return DeviceCatalog(
            microphones: audioDevices.inputs,
            speakers: audioDevices.outputs,
            cameras: cameras
        )
    }
}
