#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation
import LumiUI
import SwiftUI
import Combine

/// Menu bar popup view for Device Info plugin
/// Shows detailed CPU usage with progress bar and top processes
public struct DeviceInfoMenuBarPopupView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: CPUManagerViewModel
    @ObservedObject private var thermalViewModel: ThermalViewModel
    private let historyViewModel: DeviceHistoryViewModel<CPUDataPoint>
    private let thermalHistoryViewModel: DeviceHistoryViewModel<ThermalDataPoint>

    init(
        viewModel: CPUManagerViewModel,
        thermalViewModel: ThermalViewModel,
        historyViewModel: DeviceHistoryViewModel<CPUDataPoint>,
        thermalHistoryViewModel: DeviceHistoryViewModel<ThermalDataPoint>
    ) {
        self.viewModel = viewModel
        self.thermalViewModel = thermalViewModel
        self.historyViewModel = historyViewModel
        self.thermalHistoryViewModel = thermalHistoryViewModel
    }

    // MARK: - Body

    public var body: some View {
        HoverableContainerView(
            detailView: CPUHistoryDetailView(
                viewModel: historyViewModel,
                thermalViewModel: thermalViewModel.usesSensors ? thermalHistoryViewModel : nil,
                processViewModel: viewModel
            )
        ) {
            VStack(spacing: 0) {
                // 实时 CPU 负载显示
                liveCpuView

                // Top 5 CPU 占用进程
                topProcessesView
            }
        }
    }

    // MARK: - Live CPU View

    private var liveCpuView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 紧凑指标行:温度 + 开机时长(标题与数值并排,提高信息密度)
            HStack(spacing: 10) {
                metric(
                    label: thermalViewModel.displayLabel,
                    value: thermalViewModel.displayValue,
                    color: thermalViewModel.color
                )

                metric(
                    label: pluginLocalization.string("Uptime"),
                    value: uptimeText,
                    color: .secondary
                )

                Spacer(minLength: 0)
            }

            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))

                    // 进度条
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [cpuColor.opacity(0.8), cpuColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.cpuUsage / 100.0))
                }
            }
            .frame(height: 6)

            // CPU usage breakdown: User / System / Idle + total usage on the right
            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                    Text(String(format: pluginLocalization.string("User %.0f%%"), viewModel.userUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                    Text(String(format: pluginLocalization.string("Sys %.0f%%"), viewModel.systemUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text(String(format: pluginLocalization.string("Idle %.0f%%"), viewModel.idleUsage))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
                Text(String(format: "%.1f%%", viewModel.cpuUsage))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(cpuColor)
            }
        }
        .padding(10)
    }

    // MARK: - Top Processes View

    private var topProcessesView: some View {
        TopProcessesView(processes: viewModel.topProcessesPreview)
    }

    // MARK: - Helpers

    /// 单个「标签 + 数值」指标块,用于首行的紧凑排布。
    private func metric(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
        }
    }

    /// 系统已运行时长（开机至今）；与 CPU 指标同频刷新。
    private var uptimeText: String {
        Self.uptimeFormatter.string(from: ProcessInfo.processInfo.systemUptime) ?? "—"
    }

    private static let uptimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var cpuColor: Color {
        let value = viewModel.cpuUsage
        if value < 60 { return .green }
        if value < 85 { return .orange }
        return .red
    }
}

#endif
