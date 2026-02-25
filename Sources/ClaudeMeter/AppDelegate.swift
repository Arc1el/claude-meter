import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingView: PassThroughHostingView<AnyView>!
    let statsManager = StatsManager()
    let languageManager = LanguageManager()

    // 메뉴바 아이템 너비: ⚡ + 바 90 + % + 리셋시간
    private let barWidth: CGFloat = 190

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
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
