import SwiftUI
import AppKit

// MARK: - Status Bar Progress View (메뉴바에 직접 표시)

struct StatusBarView: View {
    @EnvironmentObject var statsManager: StatsManager
    @EnvironmentObject var languageManager: LanguageManager

    private var pct: Double { statsManager.rateLimitPct ?? 0 }

    private var barColor: Color {
        switch pct {
        case 0.8...: return .red
        case 0.5...: return .orange
        default:     return .blue
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.yellow)

                if statsManager.isLoadingUsage {
                    Text(languageManager.s("로딩중...", "Loading..."))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if statsManager.rateLimitPct == nil {
                    Text("--%")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.primary.opacity(0.12))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [barColor.opacity(0.75), barColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(3, 90 * pct))
                    }
                    .frame(width: 90, height: 6)

                    Text(String(format: "%d%%", Int(pct * 100)))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AnyShapeStyle(.primary))

                    Text(rightLabel(now: ctx.date))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 22)
        }
    }

    private func rightLabel(now: Date) -> String {
        if let resetDate = statsManager.rateLimitResetsAt, resetDate > now {
            return countdown(to: resetDate, from: now)
        }
        return ""
    }

    private func countdown(to target: Date, from now: Date) -> String {
        let secs = Int(target.timeIntervalSince(now))
        guard secs > 0 else { return "" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? String(format: "%dh%02dm", h, m) : String(format: "%dm", m)
    }
}

// MARK: - Concrete wrapper so NSHostingView re-renders on @Published changes

struct StatusBarWrapper: View {
    @ObservedObject var statsManager: StatsManager
    @ObservedObject var languageManager: LanguageManager
    var body: some View {
        StatusBarView()
            .environmentObject(statsManager)
            .environmentObject(languageManager)
    }
}

// MARK: - 마우스 이벤트를 NSStatusBarButton 으로 투과시키는 NSHostingView

final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var intrinsicContentSize: NSSize { .zero }
}
