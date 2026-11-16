#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import LumiUI
import SwiftUI

/// 仪表盘卡片容器：统一的标题行、内边距、圆角与分隔线。
///
/// 不复用 `AppSettingSection`（GroupBox），是为了与设置页分组区分开：
/// 仪表盘卡片承担的是数据面板，而不是设置行。
struct DashboardCard<Content: View>: View {
    @LumiTheme private var theme

    let title: String
    let subtitle: String?
    let accessory: AnyView
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> some View = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = AnyView(accessory())
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textSecondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.appMicro)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                accessory
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(style: .panel, cornerRadius: 14, borderColor: theme.divider, lineWidth: 1)
    }
}

// MARK: - Legend

struct TrendLegendEntry: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct TrendLegendView: View {
    @LumiTheme private var theme

    let entries: [TrendLegendEntry]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(entries) { entry in
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.color)
                        .frame(width: 6, height: 6)

                    Text(entry.name)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Key / Value

struct MetricKeyValue: View {
    @LumiTheme private var theme

    let label: String
    let value: String
    var valueColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)

            Text(value)
                .font(.appMonoCaption)
                .foregroundStyle(valueColor ?? theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Meter

struct MeterBar: View {
    @LumiTheme private var theme

    let fraction: Double
    let color: Color

    private var clamped: Double {
        guard fraction.isFinite else { return 0 }
        return min(max(fraction, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.textTertiary.opacity(0.16))

                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * clamped)
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.3), value: clamped)
    }
}

// MARK: - Status Badge

struct MetricStatusBadge: View {
    @LumiTheme private var theme

    let status: MetricStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color(in: theme))
                .frame(width: 5, height: 5)

            Text(status.localizedTitle)
                .font(.appMicroEmphasized)
                .foregroundStyle(status.color(in: theme))
        }
        .fixedSize()
    }
}

#endif
