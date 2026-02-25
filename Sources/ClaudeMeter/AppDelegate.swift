import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingView: PassThroughHostingView<AnyView>!
    private var mouseTrackingTimer: Timer?
    let statsManager = StatsManager()
    let languageManager = LanguageManager()

    private let barWidth: CGFloat = 205

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: barWidth)

        let rootView = StatusBarWrapper(statsManager: statsManager, languageManager: languageManager)
        hostingView = PassThroughHostingView(rootView: AnyView(rootView))
        hostingView.frame = NSRect(x: 0, y: 0, width: barWidth, height: 22)

        guard let button = statusItem.button else { return }
        button.frame = hostingView.frame
        button.addSubview(hostingView)
        button.action = #selector(togglePopover)
        button.target  = self
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(statsManager)
                .environmentObject(languageManager)
        )
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            startMouseTracking()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopMouseTracking()
    }

    // MARK: - Mouse Tracking

    private func startMouseTracking() {
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkMouseLocation()
        }
    }

    private func stopMouseTracking() {
        mouseTrackingTimer?.invalidate()
        mouseTrackingTimer = nil
    }

    private func checkMouseLocation() {
        guard popover.isShown else {
            stopMouseTracking()
            return
        }

        let mouse = NSEvent.mouseLocation

        if let popoverWindow = popover.contentViewController?.view.window {
            let frame = popoverWindow.frame.insetBy(dx: -8, dy: -8)
            if frame.contains(mouse) { return }
        }

        if let buttonWindow = statusItem.button?.window {
            if buttonWindow.frame.contains(mouse) { return }
        }

        closePopover()
    }
}
