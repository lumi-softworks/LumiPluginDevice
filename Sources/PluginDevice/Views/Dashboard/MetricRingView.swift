#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import LumiUI
import SwiftUI

/// 环形仪表：轨道 + 进度弧 + 圆心数值。
///
/// 环色是指标身份色；越过阈值时由调用方补充状态点与文案，不把整环染红。
struct MetricRingView: View {
    @LumiTheme private var theme

    let progress: Double
    let valueText: String
    let caption: String
    let color: Color
    var diameter: CGFloat = 96
    var lineWidth: CGFloat = 9

    private var clampedProgress: Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.textTertiary.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text(valueText)
                    .font(.system(size: 25, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 16)
            }
        }
        .padding(lineWidth / 2)
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.3), value: clampedProgress)
        .accessibilityElement(children: .combine)
    }
}

#endif
