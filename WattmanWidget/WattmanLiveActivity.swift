import SwiftUI
import ActivityKit
import WidgetKit

/// Live Activity UI cho Wattman
/// Hiển thị trên: Lock Screen, Dynamic Island (compact + expanded + minimal)
struct WattmanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WattmanAttributes.self) { context in
            // ── LOCK SCREEN / NOTIFICATION BANNER ──────────────────────────
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.1, green: 0.1, blue: 0.18))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // ── EXPANDED (chạm vào Dynamic Island) ─────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: context.state.isCharging ? "bolt.fill" : "battery.75")
                            .foregroundColor(context.state.isCharging ? .yellow : .blue)
                            .font(.system(size: 16, weight: .bold))
                        Text(String(format: "%.1fW", context.state.watts))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(context.state.isCharging ? Color(red: 0.66, green: 1.0, blue: 0.24) : .blue)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(context.state.batteryPercent)%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        if context.state.timeToFullMin > 0 {
                            let h = context.state.timeToFullMin / 60
                            let m = context.state.timeToFullMin % 60
                            Text(h > 0 ? "\(h)g \(m)p" : "\(m)p")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(state: context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.statusText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }

            } compactLeading: {
                // ── COMPACT LEADING (góc trái) ──────────────────────────────
                HStack(spacing: 3) {
                    Image(systemName: context.state.isCharging ? "bolt.fill" : "battery.75")
                        .foregroundColor(context.state.isCharging ? .yellow : .blue)
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%.1fW", context.state.watts))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(context.state.isCharging ? Color(red: 0.66, green: 1.0, blue: 0.24) : .blue)
                }

            } compactTrailing: {
                // ── COMPACT TRAILING (góc phải) ─────────────────────────────
                Text("\(context.state.batteryPercent)%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

            } minimal: {
                // ── MINIMAL (khi có nhiều activity) ────────────────────────
                Image(systemName: context.state.isCharging ? "bolt.circle.fill" : "battery.75")
                    .foregroundColor(context.state.isCharging ? .yellow : .blue)
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let state: WattmanAttributes.ContentState

    var chargingColor: Color {
        if state.currentMa > 0 { return Color(red: 0.66, green: 1.0, blue: 0.24) }
        if state.currentMa < -800 { return .orange }
        return .blue
    }

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(chargingColor)
                Text("WATTMAN")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .kerning(2)
                Spacer()
                Text("\(state.batteryPercent)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            // Main wattage display
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", state.watts))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(chargingColor)
                Text("W")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(chargingColor.opacity(0.8))
                    .padding(.bottom, 4)
                Spacer()
            }

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 0.5)

            // Sub metrics
            HStack {
                MetricPill(icon: "bolt.horizontal.fill", value: "\(state.voltageMv) mV", color: .cyan)
                MetricPill(icon: "arrow.up.arrow.down", value: "\(state.currentMa) mA", color: state.currentMa >= 0 ? .green : .orange)
                Spacer()
                // Time remaining / to full
                if state.isCharging && state.timeToFullMin > 0 {
                    let h = state.timeToFullMin / 60
                    let m = state.timeToFullMin % 60
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Đầy sau")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(h > 0 ? "~\(h)g \(m)p" : "~\(m) phút")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    Text(state.statusText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Expanded Bottom View

private struct ExpandedBottomView: View {
    let state: WattmanAttributes.ContentState

    var body: some View {
        HStack(spacing: 20) {
            MetricItem(label: "Điện áp", value: "\(state.voltageMv) mV")
            MetricItem(label: "Dòng điện", value: "\(state.currentMa) mA")
            if state.isCharging && state.timeToFullMin > 0 {
                let h = state.timeToFullMin / 60
                let m = state.timeToFullMin % 60
                MetricItem(label: "Đầy sau", value: h > 0 ? "\(h)g \(m)p" : "\(m)p")
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Reusable Components

private struct MetricPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct MetricItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
