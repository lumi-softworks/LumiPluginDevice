#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import LumiUI
import SwiftUI

/// 英雄指标卡：身份色点 + 环形仪表 + 辅助口径 + 微型趋势。
struct HeroMetricCard: View {
    @LumiTheme private var theme

    let title: String
    let meta: String
    let valueText: String
    let caption: String
    let detail: String
    let progress: Double
    let color: Color
    let status: MetricStatus
    let sparklineValues: [Double]
    let sparklineMax: Double

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)

                Text(title)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textSecondary)

                Spacer(minLength: 6)

                Text(meta)
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            MetricRingView(
                progress: progress,
                valueText: valueText,
                caption: caption,
                color: color
            )

            HStack(spacing: 5) {
                if status != .normal {
                    MetricStatusBadge(status: status)

                    Text("·")
                        .font(.appMicro)
                        .foregroundStyle(theme.textTertiary)
                }

                Text(detail)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)

            SparklineView(values: sparklineValues, maxValue: sparklineMax, color: color)
                .frame(height: 26)
                .opacity(sparklineValues.count >= 2 ? 1 : 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .appSurface(style: .panel, cornerRadius: 14, borderColor: theme.divider, lineWidth: 1)
    }
}

#endif
