import SwiftUI

// MARK: - Root Menu Bar View

struct MenuBarView: View {
    @EnvironmentObject private var statsManager: StatsManager
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 15, weight: .bold))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Claude Meter")
                        .font(.system(size: 14, weight: .semibold))
                    if let updated = statsManager.lastUpdated {
                        Text("\(lang.s("업데이트", "Updated")) \(updated, style: .time)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 언어 토글
                Button(lang.isKorean ? "EN" : "한") {
                    lang.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // 현재 세션 한도
            VStack(alignment: .leading, spacing: 8) {
                Text(lang.s("세션 한도", "Session Limit"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.4)

                if statsManager.isLoadingUsage {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(0.9)
                            Text(lang.s("사용량 불러오는 중...", "Loading usage..."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if statsManager.rateLimitPct == nil {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                            Text(lang.s("데이터를 가져올 수 없음", "Failed to load data"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(lang.s("잠시 후 자동으로 재시도합니다", "Will retry automatically"))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else {
                    UsageLimitView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 주간 사용량 (데이터 있을 때만)
            if statsManager.weeklyPct != nil {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(lang.s("주간 사용량", "Weekly Usage"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.4)

                    WeeklyUsageView()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "power.circle")
                        Text(lang.s("종료", "Quit"))
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
        .environment(\.locale, lang.locale)
    }
}

// MARK: - Weekly Usage View

struct WeeklyUsageView: View {
    @EnvironmentObject private var statsManager: StatsManager
    @EnvironmentObject private var lang: LanguageManager

    private var pct: Double { statsManager.weeklyPct ?? 0 }

    private var gaugeColor: Color {
        switch pct {
        case 0.8...: return .red
        case 0.5...: return .orange
        default:     return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", pct * 100))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(gaugeColor)
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(gaugeColor)
                Text(lang.s("사용됨", "used"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [gaugeColor.opacity(0.7), gaugeColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * pct), height: 10)
                        .animation(.easeOut(duration: 0.4), value: pct)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        .frame(height: 10)
                )
            }
            .frame(height: 10)

            if let resetsAt = statsManager.weeklyResetsAt {
                ResetTimeRow(resetsAt: resetsAt)
            }
        }
    }
}

// MARK: - Usage Limit View

struct UsageLimitView: View {
    @EnvironmentObject private var statsManager: StatsManager
    @EnvironmentObject private var lang: LanguageManager

    private var pct: Double { statsManager.rateLimitPct ?? 0 }

    private var gaugeColor: Color {
        switch pct {
        case 0.8...: return .red
        case 0.5...: return .orange
        default:     return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", pct * 100))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(gaugeColor)
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(gaugeColor)
                Text(lang.s("사용됨", "used"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [gaugeColor.opacity(0.7), gaugeColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * pct), height: 10)
                        .animation(.easeOut(duration: 0.4), value: pct)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        .frame(height: 10)
                )
            }
            .frame(height: 10)

            if let resetsAt = statsManager.rateLimitResetsAt {
                ResetTimeRow(resetsAt: resetsAt)
            }
        }
    }
}

// MARK: - Reset Time Row

struct ResetTimeRow: View {
    @EnvironmentObject private var lang: LanguageManager
    let resetsAt: Date

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Text(lang.s("리셋:", "Resets in"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(resetsAt, style: .relative)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if lang.isKorean {
                Text("후")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(resetsAt, style: .time)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}
