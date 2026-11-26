#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import LumiUI
import SwiftUI

/// 健康诊断：一行结论 + 五项状态明细 + 阈值脚注。
struct HealthDiagnosisCard: View {
    @LumiTheme private var theme

    let health: DashboardHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(pluginLocalization.string("Health diagnosis"))
                    .font(.appCaptionEmphasized)
                    .foregroundStyle(theme.textSecondary)

                Spacer(minLength: 6)

                Text(String(format: pluginLocalization.string("%d items checked"), health.evaluatedCount))
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(bandColor)
                    .frame(width: 6, height: 6)

                Text(headline)
                    .font(.appSectionTitle)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 5) {
                ForEach(health.items) { item in
                    row(for: item)
                }
            }

            Divider()
                .overlay(theme.divider)

            Text(pluginLocalization.string("Thresholds: CPU/Memory 60%, Temperature 70°C, Disk free 10%"))
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(style: .panel, cornerRadius: 14, borderColor: theme.divider, lineWidth: 1)
    }

    // MARK: - Private

    private var bandColor: Color {
        health.worst.color(in: theme)
    }

    private var headline: String {
        switch health.band {
        case .good:
            return pluginLocalization.string("System is running normally. No action needed.")
        case .fair:
            return String(
                format: pluginLocalization.string("%d items need attention"),
                health.attentionCount
            )
        case .poor:
            return pluginLocalization.string("System is under pressure. Take action now.")
        }
    }

    private func row(for item: DashboardHealth.Item) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(item.status?.color(in: theme) ?? theme.textTertiary.opacity(0.45))
                .frame(width: 6, height: 6)

            Text(item.label ?? item.kind.localizedTitle)
                .font(.appMicro)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(item.status == nil ? pluginLocalization.string("Unavailable") : item.value)
                .font(.appMonoMicro)
                .foregroundStyle(theme.textPrimary.opacity(0.9))
                .lineLimit(1)

            if let status = item.status {
                Text("·")
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)

                Text(status.localizedTitle)
                    .font(.appMicroEmphasized)
                    .foregroundStyle(status.color(in: theme))
                    .lineLimit(1)
            }
        }
    }
}

#endif
