import Foundation
import CoreAudio
import AudioToolbox
import Combine

class VolumeObserver: ObservableObject {
    @Published var volume: Float = 0.0
    @Published var isMuted: Bool = false

    private var trackedDevices: [AudioDeviceID: DeviceListeners] = [:]
    private var deviceListListener: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?

    private struct DeviceListeners {
        var volumeBlock: AudioObjectPropertyListenerBlock
        var muteBlock: AudioObjectPropertyListenerBlock
    }

    init() {
        let defaultDevice = Self.getDefaultOutputDevice()
        volume = Self.getVolume(for: defaultDevice)
        isMuted = Self.getMuteState(for: defaultDevice)
        startListeningForDeviceChanges()
        updateTrackedDevices()
    }

    deinit {
        stopListening()
    }

    // MARK: - Device discovery

    private static func getDefaultOutputDevice() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &deviceID
        )

        return status == noErr ? deviceID : kAudioObjectUnknown
    }

    private static func getAllOutputDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &dataSize
        )

        guard status == noErr, dataSize > 0 else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: kAudioObjectUnknown, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &dataSize,
            &devices
        )

        guard status == noErr else { return [] }

        return devices.filter { hasOutputChannels($0) }
    }

    private static func hasOutputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        guard status == noErr, size > 0 else { return false }

        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        var getSize = size
        let getStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &getSize, bufferListPointer)
        guard getStatus == noErr else { return false }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    // MARK: - Reading state

    private static func getVolume(for deviceID: AudioDeviceID) -> Float {
        guard deviceID != kAudioObjectUnknown else { return 0.0 }

        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)

        // Try the virtual main volume first — this works for Bluetooth
        // and other devices that don't expose per-channel volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        if status == noErr { return volume }

        // Fall back to volume scalar on master channel
        address.mSelector = kAudioDevicePropertyVolumeScalar
        address.mElement = 0
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        if status == noErr { return volume }

        // Try channel 1
        address.mElement = 1
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        if status == noErr { return volume }

        return 0.0
    }

    private static func getMuteState(for deviceID: AudioDeviceID) -> Bool {
        guard deviceID != kAudioObjectUnknown else { return false }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var mute: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &mute)
        return status == noErr && mute != 0
    }

    // MARK: - System-level listeners

    private func startListeningForDeviceChanges() {
        // Listen for device list changes (devices added/removed)
        deviceListListener = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateTrackedDevices()
            }
        }

        if let block = deviceListListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                block
            )
        }

        // Listen for default output device changes
        defaultDeviceListener = { [weak self] _, _ in
            DispatchQueue.main.async {
                let device = Self.getDefaultOutputDevice()
                self?.volume = Self.getVolume(for: device)
                self?.isMuted = Self.getMuteState(for: device)
            }
        }

        if let block = defaultDeviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                block
            )
        }
    }

    // MARK: - Per-device listeners

    private func updateTrackedDevices() {
        let currentDevices = Set(Self.getAllOutputDevices())
        let existingDevices = Set(trackedDevices.keys)

        for deviceID in existingDevices.subtracting(currentDevices) {
            removeListeners(for: deviceID)
        }

        for deviceID in currentDevices.subtracting(existingDevices) {
            addListeners(for: deviceID)
        }
    }

    private func addListeners(for deviceID: AudioDeviceID) {
        let volumeBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                let device = Self.getDefaultOutputDevice()
                self?.volume = Self.getVolume(for: device)
            }
        }

        let muteBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                let device = Self.getDefaultOutputDevice()
                self?.isMuted = Self.getMuteState(for: device)
            }
        }

        // Listen on virtual main volume (used by Bluetooth devices)
        var virtualVolumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(deviceID, &virtualVolumeAddress, DispatchQueue.main, volumeBlock)

        // Listen on volume scalar master channel and channel 1
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddress, DispatchQueue.main, volumeBlock)

        volumeAddress.mElement = 1
        AudioObjectAddPropertyListenerBlock(deviceID, &volumeAddress, DispatchQueue.main, volumeBlock)

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, muteBlock)

        trackedDevices[deviceID] = DeviceListeners(volumeBlock: volumeBlock, muteBlock: muteBlock)
    }

    private func removeListeners(for deviceID: AudioDeviceID) {
        guard let listeners = trackedDevices[deviceID] else { return }

        var virtualVolumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(deviceID, &virtualVolumeAddress, DispatchQueue.main, listeners.volumeBlock)

        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(deviceID, &volumeAddress, DispatchQueue.main, listeners.volumeBlock)

        volumeAddress.mElement = 1
        AudioObjectRemovePropertyListenerBlock(deviceID, &volumeAddress, DispatchQueue.main, listeners.volumeBlock)

        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(deviceID, &muteAddress, DispatchQueue.main, listeners.muteBlock)

        trackedDevices.removeValue(forKey: deviceID)
    }

    // MARK: - Cleanup

    private func stopListening() {
        for deviceID in Array(trackedDevices.keys) {
            removeListeners(for: deviceID)
        }

        if let block = deviceListListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                block
            )
        }

        if let block = defaultDeviceListener {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                block
            )
        }
    }
}
