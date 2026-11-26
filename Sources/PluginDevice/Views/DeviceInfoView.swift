#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation
import LumiUI
import SwiftUI

public struct DeviceInfoView: View {
    private let viewModels: DevicePluginViewModels

    init(viewModels: DevicePluginViewModels) {
        self.viewModels = viewModels
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    DashboardHeaderView(
                        deviceData: viewModels.deviceData,
                        cpu: viewModels.cpu,
                        memory: viewModels.memory,
                        thermal: viewModels.thermal,
                        battery: viewModels.battery
                    )

                    DashboardHeroSection(
                        deviceData: viewModels.deviceData,
                        cpu: viewModels.cpu,
                        memory: viewModels.memory,
                        gpu: viewModels.gpu,
                        thermal: viewModels.thermal,
                        battery: viewModels.battery,
                        cpuHistory: viewModels.cpuHistory,
                        memoryHistory: viewModels.memoryHistory,
                        gpuHistory: viewModels.gpuHistory,
                        columns: DashboardLayout.heroColumns(for: proxy.size.width)
                    )

                    DashboardTrendsSection(
                        viewModels: viewModels,
                        columns: DashboardLayout.trendColumns(for: proxy.size.width)
                    )

                    DashboardBottomSection(
                        deviceData: viewModels.deviceData,
                        cpu: viewModels.cpu,
                        memory: viewModels.memory,
                        battery: viewModels.battery,
                        storage: viewModels.storage,
                        stacked: DashboardLayout.stacksBottom(for: proxy.size.width)
                    )

                    DashboardFooterView(
                        deviceData: viewModels.deviceData,
                        thermal: viewModels.thermal
                    )
                }
                .padding(20)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Header

private struct DashboardHeaderView: View {
    @LumiTheme private var theme

    @ObservedObject var deviceData: DeviceData
    @ObservedObject var cpu: CPUManagerViewModel
    @ObservedObject var memory: MemoryManagerViewModel
    @ObservedObject var thermal: ThermalViewModel
    @ObservedObject var battery: BatteryManagerViewModel

    var body: some View {
        let health = DashboardHealthFactory.make(
            deviceData: deviceData,
            cpu: cpu,
            memory: memory,
            thermal: thermal,
            battery: battery
        )

        HStack(spacing: 12) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(theme.primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.primary.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(deviceData.deviceName)
                    .font(.appTitle)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 12)

            healthPill(health)
        }
    }

    private var subtitle: String {
        var parts = [deviceData.osVersion]
        if !deviceData.processorName.isEmpty {
            parts.append(deviceData.processorName)
        }
        parts.append(String(format: pluginLocalization.string("%d cores"), deviceData.coreCount))
        return parts.joined(separator: " · ")
    }

    private func healthPill(_ health: DashboardHealth) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(health.worst.color(in: theme))
                .frame(width: 6, height: 6)

            Text(pluginLocalization.string("System status"))
                .font(.appMicro)
                .foregroundStyle(theme.textSecondary)

            Text("·")
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)

            Text(health.band.localizedTitle)
                .font(.appMicroEmphasized)
                .foregroundStyle(health.worst.color(in: theme))

            Text("\(health.score)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(theme.surface))
        .overlay(Capsule().stroke(theme.divider, lineWidth: 1))
    }
}

// MARK: - Hero

private struct DashboardHeroSection: View {
    @LumiTheme private var theme

    @ObservedObject var deviceData: DeviceData
    @ObservedObject var cpu: CPUManagerViewModel
    @ObservedObject var memory: MemoryManagerViewModel
    @ObservedObject var gpu: GPUManagerViewModel
    @ObservedObject var thermal: ThermalViewModel
    @ObservedObject var battery: BatteryManagerViewModel
    @ObservedObject var cpuHistory: DeviceHistoryViewModel<CPUDataPoint>
    @ObservedObject var memoryHistory: DeviceHistoryViewModel<MemoryDataPoint>
    @ObservedObject var gpuHistory: DeviceHistoryViewModel<GPUDataPoint>

    let columns: Int

    var body: some View {
        let health = DashboardHealthFactory.make(
            deviceData: deviceData,
            cpu: cpu,
            memory: memory,
            thermal: thermal,
            battery: battery
        )

        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                count: columns
            ),
            spacing: 12
        ) {
            HeroMetricCard(
                title: pluginLocalization.string("CPU"),
                meta: deviceData.processorName.isEmpty
                    ? String(format: pluginLocalization.string("%d cores"), deviceData.coreCount)
                    : deviceData.processorName,
                valueText: "\(Int(cpu.cpuUsage.rounded()))%",
                caption: pluginLocalization.string("Usage"),
                detail: String(
                    format: "%@ %.0f%% · %@ %.0f%%",
                    pluginLocalization.string("User"),
                    cpu.userUsage,
                    pluginLocalization.string("System"),
                    cpu.systemUsage
                ),
                progress: cpu.cpuUsage / 100,
                color: theme.info,
                status: MetricStatusScale.from(percentage: cpu.cpuUsage),
                sparklineValues: sparkline(cpuHistory.recentHistory.map(\.usage)),
                sparklineMax: 100
            )

            HeroMetricCard(
                title: pluginLocalization.string("Memory"),
                meta: memory.totalMemory,
                valueText: "\(Int(memory.memoryUsagePercentage.rounded()))%",
                caption: pluginLocalization.string("used"),
                detail: "\(memory.usedMemory) / \(memory.totalMemory)",
                progress: memory.memoryUsagePercentage / 100,
                color: theme.success,
                status: MetricStatusScale.from(percentage: memory.memoryUsagePercentage),
                sparklineValues: sparkline(memoryHistory.recentHistory.map(\.usagePercentage)),
                sparklineMax: 100
            )

            HeroMetricCard(
                title: pluginLocalization.string("GPU"),
                meta: gpu.modelName,
                valueText: gpu.utilizationString,
                caption: pluginLocalization.string("Usage"),
                detail: "\(gpu.usedMemory) / \(gpu.totalMemory)",
                progress: gpu.utilization / 100,
                color: theme.primary,
                status: MetricStatusScale.from(percentage: gpu.utilization),
                sparklineValues: sparkline(gpuHistory.recentHistory.map(\.usage)),
                sparklineMax: 100
            )

            HealthDiagnosisCard(health: health)
        }
    }

    private func sparkline(_ values: [Double]) -> [Double] {
        Array(values.suffix(60))
    }
}

// MARK: - Trends

private struct DashboardTrendsSection: View {
    @LumiTheme private var theme

    @ObservedObject var systemMonitor: SystemMonitorViewModel
    @ObservedObject var thermal: ThermalViewModel
    @ObservedObject var thermalHistory: DeviceHistoryViewModel<ThermalDataPoint>

    let columns: Int

    init(viewModels: DevicePluginViewModels, columns: Int) {
        self._systemMonitor = ObservedObject(wrappedValue: viewModels.systemMonitor)
        self._thermal = ObservedObject(wrappedValue: viewModels.thermal)
        self._thermalHistory = ObservedObject(wrappedValue: viewModels.thermalHistory)
        self.columns = columns
    }

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                count: columns
            ),
            spacing: 12
        ) {
            DashboardCard(
                title: pluginLocalization.string("CPU Usage"),
                accessory: { legend([("cpu", pluginLocalization.string("CPU"), theme.info)]) }
            ) {
                TrendChartView(
                    series: [
                        TrendSeries(
                            id: "cpu",
                            name: pluginLocalization.string("CPU"),
                            color: theme.info,
                            points: DashboardTrendData.points(
                                systemMonitor.metrics.cpuUsage.history.map { $0 * 100 }
                            )
                        ),
                    ],
                    format: .percent,
                    fixedMax: 100
                )
            }

            DashboardCard(
                title: pluginLocalization.string("Network"),
                subtitle: pluginLocalization.string("Adaptive scale"),
                accessory: {
                    legend([
                        ("download", pluginLocalization.string("Download"), theme.info),
                        ("upload", pluginLocalization.string("Upload"), theme.primarySecondary),
                    ])
                }
            ) {
                TrendChartView(
                    series: [
                        TrendSeries(
                            id: "download",
                            name: pluginLocalization.string("Download"),
                            color: theme.info,
                            points: DashboardTrendData.points(systemMonitor.metrics.network.downloadHistory)
                        ),
                        TrendSeries(
                            id: "upload",
                            name: pluginLocalization.string("Upload"),
                            color: theme.primarySecondary,
                            points: DashboardTrendData.points(systemMonitor.metrics.network.uploadHistory)
                        ),
                    ],
                    format: .rate
                )
            }

            DashboardCard(
                title: pluginLocalization.string("Disk I/O"),
                subtitle: pluginLocalization.string("Adaptive scale"),
                accessory: {
                    legend([
                        ("read", pluginLocalization.string("Read"), theme.info),
                        ("write", pluginLocalization.string("Write"), theme.primarySecondary),
                    ])
                }
            ) {
                TrendChartView(
                    series: [
                        TrendSeries(
                            id: "read",
                            name: pluginLocalization.string("Read"),
                            color: theme.info,
                            points: DashboardTrendData.points(systemMonitor.metrics.disk.readHistory)
                        ),
                        TrendSeries(
                            id: "write",
                            name: pluginLocalization.string("Write"),
                            color: theme.primarySecondary,
                            points: DashboardTrendData.points(systemMonitor.metrics.disk.writeHistory)
                        ),
                    ],
                    format: .rate
                )
            }

            if thermal.usesSensors {
                temperatureCard
            } else {
                thermalPressureCard
            }
        }
    }

    private var temperatureCard: some View {
        DashboardCard(
            title: pluginLocalization.string("CPU Temperature"),
            accessory: {
                if let peak = thermal.peakString {
                    Text(peak)
                        .font(.appMonoMicro)
                        .foregroundStyle(thermal.peakColor)
                }
            }
        ) {
            if thermal.isAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    TrendChartView(
                        series: [
                            TrendSeries(
                                id: "temperature",
                                name: pluginLocalization.string("Peak Temperature"),
                                color: theme.warning,
                                points: thermalHistory.recentHistory.suffix(60).map {
                                    TrendPoint(timestamp: $0.timestamp, value: $0.celsius)
                                }
                            ),
                        ],
                        format: .celsius
                    )

                    sensorDetails
                }
            } else {
                Text(pluginLocalization.string("No temperature sensors available"))
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 128)
            }
        }
    }

    private var sensorDetails: some View {
        DisclosureGroup {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ],
                alignment: .leading,
                spacing: 5
            ) {
                ForEach(thermal.readings) { reading in
                    HStack(spacing: 4) {
                        Text(ThermalSensorLabel.text(index: reading.index))
                            .font(.appMicro)
                            .foregroundStyle(theme.textSecondary)

                        Spacer(minLength: 4)

                        Text(String(format: "%.1f°C", reading.celsius))
                            .font(.appMonoMicro)
                            .foregroundStyle(
                                MetricStatus.cpuTemperature(reading.celsius).color(in: theme)
                            )
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 5) {
                Text(pluginLocalization.string("Sensor details"))
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)

                Text(String(format: pluginLocalization.string("%d sensors"), thermal.readings.count))
                    .font(.appMonoMicro)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .tint(theme.textSecondary)
    }

    private var thermalPressureCard: some View {
        DashboardCard(
            title: pluginLocalization.string("Thermal Pressure"),
            accessory: {
                Text(thermal.title)
                    .font(.appMonoMicro)
                    .foregroundStyle(thermal.color)
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(thermal.color)

                    Text(thermal.title)
                        .font(.appTitle)
                        .foregroundStyle(thermal.color)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= thermal.level ? thermal.color : theme.divider)
                            .frame(height: 6)
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(pluginLocalization.string("Thermal Pressure")): \(thermal.title)")
        }
    }

    private func legend(_ entries: [(String, String, Color)]) -> some View {
        TrendLegendView(
            entries: entries.map { TrendLegendEntry(id: $0.0, name: $0.1, color: $0.2) }
        )
    }
}

// MARK: - Bottom

private struct DashboardBottomSection: View {
    @ObservedObject var deviceData: DeviceData
    @ObservedObject var cpu: CPUManagerViewModel
    @ObservedObject var memory: MemoryManagerViewModel
    @ObservedObject var battery: BatteryManagerViewModel
    @ObservedObject var storage: StorageManagerViewModel

    let stacked: Bool

    var body: some View {
        if stacked {
            VStack(spacing: 12) {
                processCard
                detailColumn
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                processCard
                    .frame(maxWidth: .infinity)

                detailColumn
                    .frame(width: 340)
            }
        }
    }

    private var processCard: some View {
        DashboardProcessCard(cpu: cpu, memory: memory)
    }

    private var detailColumn: some View {
        VStack(spacing: 12) {
            BatteryDetailCard(battery: battery)
            StorageDetailCard(deviceData: deviceData, storage: storage)
        }
    }
}

// MARK: - Footer

private struct DashboardFooterView: View {
    @LumiTheme private var theme

    @ObservedObject var deviceData: DeviceData
    @ObservedObject var thermal: ThermalViewModel

    var body: some View {
        HStack(spacing: 6) {
            Text("\(pluginLocalization.string("Uptime")): \(formatUptime(deviceData.uptime))")
                .lineLimit(1)

            if thermal.usesSensors {
                if let peak = thermal.peakString {
                    Text("·")
                    Text("\(pluginLocalization.string("Peak Temperature")): \(peak)")
                        .lineLimit(1)
                }

                if thermal.isAvailable {
                    Text("·")
                    Text(String(format: pluginLocalization.string("%d sensors"), thermal.readings.count))
                        .lineLimit(1)
                }
            } else {
                Text("·")
                Text("\(pluginLocalization.string("Thermal Pressure")): \(thermal.title)")
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(pluginLocalization.string("1s refresh · 60s window"))
                .lineLimit(1)
        }
        .font(.appMicro)
        .foregroundStyle(theme.textTertiary)
        .padding(.horizontal, 2)
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}

// MARK: - Data

@MainActor
private enum DashboardHealthFactory {
    static func make(
        deviceData: DeviceData,
        cpu: CPUManagerViewModel,
        memory: MemoryManagerViewModel,
        thermal: ThermalViewModel,
        battery: BatteryManagerViewModel
    ) -> DashboardHealth {
        let batteryHealth: Double? = battery.hasBattery && battery.healthPercentage > 0
            ? battery.healthPercentage
            : nil

        if thermal.usesSensors {
            return DashboardHealth(
                cpuPercent: cpu.cpuUsage,
                memoryPercent: memory.memoryUsagePercentage,
                thermalCelsius: thermal.peakCelsius,
                batteryHealth: batteryHealth,
                diskFreeBytes: max(0, deviceData.diskTotal - deviceData.diskUsed),
                diskTotalBytes: deviceData.diskTotal
            )
        }

        return DashboardHealth(
            cpuPercent: cpu.cpuUsage,
            memoryPercent: memory.memoryUsagePercentage,
            thermalState: thermal.state,
            batteryHealth: batteryHealth,
            diskFreeBytes: max(0, deviceData.diskTotal - deviceData.diskUsed),
            diskTotalBytes: deviceData.diskTotal
        )
    }
}

private enum DashboardTrendData {
    /// 网络 / 磁盘历史只保存数值，按 1s 采样合成时间戳，与 60s 窗口对齐。
    static func points(
        _ values: [Double],
        endingAt now: TimeInterval = Date().timeIntervalSince1970
    ) -> [TrendPoint] {
        guard !values.isEmpty else { return [] }
        let count = values.count
        return values.enumerated().map { index, value in
            TrendPoint(
                timestamp: now - Double(count - 1 - index),
                value: value
            )
        }
    }
}

#endif
