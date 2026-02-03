import SwiftUI
import AppKit

@main
struct KnobApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: NSWindow?
    var volumeObserver: VolumeObserver?
    var hideTimer: Timer?
    var hostingView: NSHostingView<OverlayContentView>?
    private var showCounter = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Create the volume observer
        volumeObserver = VolumeObserver()

        // Create overlay window
        setupOverlayWindow()

        // Observe volume changes
        volumeObserver?.$volume
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.showOverlay()
            }
            .store(in: &cancellables)

        // Observe mute changes
        volumeObserver?.$isMuted
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.showOverlay()
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    func setupOverlayWindow() {
        guard let screen = NSScreen.main else { return }

        let windowSize = CGSize(width: 280, height: 280)
        let windowOrigin = CGPoint(
            x: screen.frame.midX - windowSize.width / 2,
            y: screen.frame.midY - windowSize.height / 2
        )

        let window = NSWindow(
            contentRect: NSRect(origin: windowOrigin, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = false
        window.hasShadow = true
        window.ignoresMouseEvents = true

        let contentView = OverlayContentView(volumeObserver: volumeObserver!)
        hostingView = NSHostingView(rootView: contentView)
        hostingView?.frame = NSRect(origin: .zero, size: windowSize)
        window.contentView = hostingView

        overlayWindow = window
    }

    func showOverlay() {
        hideTimer?.invalidate()
        showCounter += 1

        // Center on current screen
        if let screen = NSScreen.main, let window = overlayWindow {
            let windowSize = window.frame.size
            let newOrigin = CGPoint(
                x: screen.frame.midX - windowSize.width / 2,
                y: screen.frame.midY - windowSize.height / 2
            )
            window.setFrameOrigin(newOrigin)
        }

        overlayWindow?.alphaValue = 0.9
        overlayWindow?.orderFrontRegardless()

        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
            self?.hideOverlay()
        }
    }

    func hideOverlay() {
        let counterAtStart = showCounter
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            overlayWindow?.animator().alphaValue = 0.0
        } completionHandler: { [weak self] in
            // Only hide if no new show request came in during fade
            if self?.showCounter == counterAtStart {
                self?.overlayWindow?.orderOut(nil)
            }
        }
    }
}

import Combine

struct OverlayContentView: View {
    @ObservedObject var volumeObserver: VolumeObserver

    var body: some View {
        KnobView(value: volumeObserver.isMuted ? 0 : volumeObserver.volume, isMuted: volumeObserver.isMuted)
            .frame(width: 200, height: 200)
            .padding(40)
    }
}
