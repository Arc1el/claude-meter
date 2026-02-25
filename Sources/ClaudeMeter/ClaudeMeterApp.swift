import SwiftUI

// NSApplicationDelegateAdaptor 로 AppDelegate 를 연결.
// 실제 UI 는 AppDelegate 의 NSStatusItem 이 담당하므로 Scene 은 비워 둠.
@main
struct ClaudeMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
