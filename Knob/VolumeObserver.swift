import Foundation
import CoreAudio
import AudioToolbox
import Combine

class VolumeObserver: ObservableObject {
    @Published var volume: Float = 0.0
    @Published var isMuted: Bool = false

    private var defaultOutputDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var muteListenerBlock: AudioObjectPropertyListenerBlock?

    init() {
        setupDefaultOutputDevice()
        volume = getCurrentVolume()
        isMuted = getMuteState()
        startListening()
    }

    deinit {
        stopListening()
    }

    private func setupDefaultOutputDevice() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        if status == noErr {
            defaultOutputDeviceID = deviceID
        }
    }

    private func getCurrentVolume() -> Float {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return 0.0 }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: 0
        )

        // Try master channel first
        var volume: Float32 = 0.0
        var propertySize = UInt32(MemoryLayout<Float32>.size)

        var status = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &volume
        )

        if status == noErr {
            return volume
        }

        // Try channel 1 if master doesn't work
        propertyAddress.mElement = 1
        status = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &volume
        )

        if status == noErr {
            return volume
        }

        return 0.0
    }

    private func getMuteState() -> Bool {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return false }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var mute: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &mute
        )

        if status == noErr {
            return mute != 0
        }

        return false
    }

    private func startListening() {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        listenerBlock = { [weak self] (inNumberAddresses: UInt32, inAddresses: UnsafePointer<AudioObjectPropertyAddress>) in
            DispatchQueue.main.async {
                self?.volume = self?.getCurrentVolume() ?? 0.0
            }
        }

        if let block = listenerBlock {
            // Listen on master channel
            AudioObjectAddPropertyListenerBlock(
                defaultOutputDeviceID,
                &propertyAddress,
                DispatchQueue.main,
                block
            )

            // Also listen on channel 1
            propertyAddress.mElement = 1
            AudioObjectAddPropertyListenerBlock(
                defaultOutputDeviceID,
                &propertyAddress,
                DispatchQueue.main,
                block
            )
        }

        // Listen for mute changes
        muteListenerBlock = { [weak self] (inNumberAddresses: UInt32, inAddresses: UnsafePointer<AudioObjectPropertyAddress>) in
            DispatchQueue.main.async {
                self?.isMuted = self?.getMuteState() ?? false
            }
        }

        if let muteBlock = muteListenerBlock {
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectAddPropertyListenerBlock(
                defaultOutputDeviceID,
                &muteAddress,
                DispatchQueue.main,
                muteBlock
            )
        }
    }

    private func stopListening() {
        guard defaultOutputDeviceID != kAudioObjectUnknown else { return }

        if let block = listenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectRemovePropertyListenerBlock(
                defaultOutputDeviceID,
                &propertyAddress,
                DispatchQueue.main,
                block
            )

            propertyAddress.mElement = 1
            AudioObjectRemovePropertyListenerBlock(
                defaultOutputDeviceID,
                &propertyAddress,
                DispatchQueue.main,
                block
            )
        }

        if let muteBlock = muteListenerBlock {
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            AudioObjectRemovePropertyListenerBlock(
                defaultOutputDeviceID,
                &muteAddress,
                DispatchQueue.main,
                muteBlock
            )
        }
    }
}
