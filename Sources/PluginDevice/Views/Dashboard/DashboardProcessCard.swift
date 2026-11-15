import AppKit
import LumiUI
import SwiftUI

/// 主窗口常驻的进程榜，支持 CPU / 内存两种口径。
///
/// CPU 值沿用 `ProcessService` 的单核口径（100% = 占满一个核心），
/// 不按榜单归一化；内存进度条以榜首进程为满格，仅用于相对比较。
struct DashboardProcessCard: View {
    @LumiTheme private var theme

    @ObservedObject private var cpu: CPUManagerViewModel
    @ObservedObject private var memory: MemoryManagerViewModel

    @State private var metric: ProcessMetricKind = .cpu

    init(cpu: CPUManagerViewModel, memory: MemoryManagerViewModel) {
        self._cpu = ObservedObject(wrappedValue: cpu)
        self._memory = ObservedObject(wrappedValue: memory)
    }

    var body: some View {
        DashboardCard(
            title: metric == .cpu
                ? pluginLocalization.string("Processes · by CPU")
                : pluginLocalization.string("Processes · by Memory"),
            subtitle: pluginLocalization.string("Top 5 · single-core 100% basis"),
            accessory: { picker }
        ) {
            VStack(spacing: 0) {
                if processes.isEmpty {
                    Text(pluginLocalization.string("Collecting..."))
                        .font(.appMicro)
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 130)
                } else {
                    ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                        if index > 0 {
                            Divider()
                                .overlay(theme.divider)
                                .padding(.leading, 26)
                        }

                        row(for: process)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var processes: [ProcessMetric] {
        let source = metric == .cpu ? cpu.topProcesses : memory.topProcesses
        return Array(source.prefix(5))
    }

    private var maxMemoryUsage: Int64 {
        processes.map(\.memoryUsage).max() ?? 0
    }

    private var accentColor: Color {
        metric == .cpu ? theme.info : theme.primary
    }

    // MARK: - Subviews

    private var picker: some View {
        Picker("", selection: $metric) {
            Text(pluginLocalization.string("CPU")).tag(ProcessMetricKind.cpu)
            Text(pluginLocalization.string("Memory")).tag(ProcessMetricKind.memory)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 138)
    }

    private func row(for process: ProcessMetric) -> some View {
        HStack(spacing: 8) {
            icon(for: process)
                .resizable()
                .frame(width: 18, height: 18)

            Text(process.name)
                .font(.appCallout)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            if process.instanceCount > 1 {
                Text("×\(process.instanceCount)")
                    .font(.appMonoMicro)
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize()
            }

            if process.isCurrentApp {
                Text(pluginLocalization.string("This app"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(theme.textSecondary.opacity(0.12)))
            }

            Spacer(minLength: 8)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.textTertiary.opacity(0.16))

                    Capsule()
                        .fill(accentColor.opacity(0.75))
                        .frame(width: geometry.size.width * barFraction(for: process))
                }
            }
            .frame(width: 60, height: 4)

            Text(primaryValue(for: process))
                .font(.appMonoCaption)
                .foregroundStyle(accentColor)
                .frame(width: 46, alignment: .trailing)

            Text(secondaryValue(for: process))
                .font(.appMonoMicro)
                .foregroundStyle(theme.textTertiary)
                .frame(width: 60, alignment: .trailing)
        }
        .frame(height: 26)
    }

    private func icon(for process: ProcessMetric) -> Image {
        if let path = process.icon {
            return Image(nsImage: NSWorkspace.shared.icon(forFile: path))
        }
        return Image(systemName: "terminal")
    }

    // MARK: - Presentation

    private func primaryValue(for process: ProcessMetric) -> String {
        switch metric {
        case .cpu: return process.formattedCPUUsage
        case .memory: return process.memoryString
        }
    }

    private func secondaryValue(for process: ProcessMetric) -> String {
        switch metric {
        case .cpu: return process.memoryString
        case .memory: return process.formattedCPUUsage
        }
    }

    private func barFraction(for process: ProcessMetric) -> Double {
        switch metric {
        case .cpu: return process.cpuBarFraction
        case .memory: return process.memoryBarFraction(relativeTo: maxMemoryUsage)
        }
    }
}
