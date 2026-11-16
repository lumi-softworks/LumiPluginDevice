#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation
import LumiUI
import SwiftUI

/// 电池明细：电量、健康度、循环次数、功率与温度。
struct BatteryDetailCard: View {
    @LumiTheme private var theme

    @ObservedObject private var battery: BatteryManagerViewModel

    init(battery: BatteryManagerViewModel) {
        self._battery = ObservedObject(wrappedValue: battery)
    }

    var body: some View {
        DashboardCard(title: pluginLocalization.string("Battery"), subtitle: subtitle) {
            if battery.hasBattery {
                batteryContent
            } else {
                noBatteryContent
            }
        }
    }

    // MARK: - Content

    private var batteryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(battery.levelString)
                    .font(.system(size: 26, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())

                Spacer(minLength: 8)

                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.appCaption)
                        .foregroundStyle(theme.warning)
                }
            }

            MeterBar(
                fraction: battery.level,
                color: MetricStatus.batteryLevel(battery.level).color(in: theme)
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                alignment: .leading,
                spacing: 8
            ) {
                MetricKeyValue(
                    label: pluginLocalization.string("Health"),
                    value: battery.healthPercentage > 0 ? battery.healthString : "--",
                    valueColor: battery.healthPercentage > 0
                        ? MetricStatus.batteryHealth(battery.healthPercentage).color(in: theme)
                        : nil
                )

                MetricKeyValue(
                    label: pluginLocalization.string("Cycles"),
                    value: battery.cycleCountString
                )

                MetricKeyValue(
                    label: pluginLocalization.string("Power"),
                    value: battery.watts > 0 ? battery.wattsString : "--"
                )

                MetricKeyValue(
                    label: pluginLocalization.string("Temperature"),
                    value: battery.temperature > 0 ? battery.temperatureString : "--",
                    valueColor: battery.temperature > 0
                        ? MetricStatus.temperature(battery.temperature).color(in: theme)
                        : nil
                )
            }
        }
    }

    private var noBatteryContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "powerplug.fill")
                .font(.appBody)
                .foregroundStyle(theme.success)

            Text(pluginLocalization.string("AC Power"))
                .font(.appBody)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 8)

            if battery.adapterWatts > 0 {
                Text(String(format: pluginLocalization.string("Adapter: %@"), battery.adapterWattsString))
                    .font(.appMicro)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(minHeight: 60)
    }

    private var subtitle: String {
        guard battery.hasBattery else { return "" }

        let state: String
        if battery.isCharging {
            state = pluginLocalization.string("Charging")
        } else if battery.powerSource == .acPower {
            state = pluginLocalization.string("AC Power")
        } else {
            state = pluginLocalization.string("On battery")
        }

        guard battery.temperature > 0 else { return state }
        return "\(state) · \(battery.temperatureString)"
    }
}

/// 存储明细：已用 / 可用 / 使用率 / 容量，并列出外置卷。
struct StorageDetailCard: View {
    @LumiTheme private var theme

    @ObservedObject private var deviceData: DeviceData
    @ObservedObject private var storage: StorageManagerViewModel

    init(deviceData: DeviceData, storage: StorageManagerViewModel) {
        self._deviceData = ObservedObject(wrappedValue: deviceData)
        self._storage = ObservedObject(wrappedValue: storage)
    }

    var body: some View {
        DashboardCard(title: pluginLocalization.string("Storage"), subtitle: capacityText) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(usedText)
                        .font(.system(size: 26, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(theme.textPrimary)
                        .contentTransition(.numericText())

                    Text(pluginLocalization.string("used"))
                        .font(.appMicro)
                        .foregroundStyle(theme.textTertiary)

                    Spacer(minLength: 8)
                }

                MeterBar(fraction: usageFraction, color: meterColor)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    MetricKeyValue(label: pluginLocalization.string("Used"), value: usedText)
                    MetricKeyValue(label: pluginLocalization.string("Available"), value: freeText)
                    MetricKeyValue(label: pluginLocalization.string("Usage"), value: usagePercentText)
                    MetricKeyValue(label: pluginLocalization.string("Capacity"), value: totalText)
                }

                if !storage.externalVolumes.isEmpty {
                    Divider()
                        .overlay(theme.divider)

                    VStack(spacing: 6) {
                        ForEach(storage.externalVolumes) { volume in
                            volumeRow(volume)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var freeBytes: Int64 {
        max(0, deviceData.diskTotal - deviceData.diskUsed)
    }

    private var usageFraction: Double {
        guard deviceData.diskTotal > 0 else { return 0 }
        return min(max(Double(deviceData.diskUsed) / Double(deviceData.diskTotal), 0), 1)
    }

    private var freePercent: Double {
        guard deviceData.diskTotal > 0 else { return 0 }
        return Double(freeBytes) / Double(deviceData.diskTotal) * 100
    }

    private var meterColor: Color {
        let status = MetricStatus.diskFree(freePercent)
        return status == .normal ? theme.info : status.color(in: theme)
    }

    private var usedText: String {
        ByteCountFormatter.string(fromByteCount: max(0, deviceData.diskUsed), countStyle: .file)
    }

    private var freeText: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }

    private var totalText: String {
        ByteCountFormatter.string(fromByteCount: max(0, deviceData.diskTotal), countStyle: .file)
    }

    private var usagePercentText: String {
        "\(Int((usageFraction * 100).rounded()))%"
    }

    private var capacityText: String {
        guard deviceData.diskTotal > 0 else { return pluginLocalization.string("Unavailable") }
        return "\(usedText) / \(totalText)"
    }

    private func volumeRow(_ volume: VolumeInfo) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "externaldrive")
                .font(.appMicro)
                .foregroundStyle(theme.textSecondary)

            Text(volume.name)
                .font(.appMicro)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 6)

            Text("\(volume.usedString) / \(volume.totalString)")
                .font(.appMonoMicro)
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)

            Text("\(volume.usagePercent)%")
                .font(.appMonoMicro)
                .foregroundStyle(theme.textPrimary)
        }
    }
}

#endif
