#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

/// 仪表盘的健康摘要：把各指标的状态聚合成一个评分与整体结论。
///
/// 纯值类型，不依赖 SwiftUI，文案与颜色由视图层决定。阈值全部复用
/// ``MetricStatus``，此处只负责打分与封顶规则：
/// 全部正常 100 分；出现告警时封顶 84；出现临界时封顶 59。
struct DashboardHealth {
    enum Kind: String, CaseIterable, Sendable {
        case cpu
        case thermal
        case memory
        case battery
        case storage
    }

    enum Band: Sendable {
        case good
        case fair
        case poor
    }

    struct Item: Identifiable, Equatable, Sendable {
        var id: Kind { kind }
        let kind: Kind
        /// `nil` 表示该项当前不可用（无传感器 / 无电池 / 尚未采到容量）。
        let status: MetricStatus?
        /// 展示值，如 "23%"、"58°C"、"514 GB"；不可用时为 "--"。
        let value: String
        /// 覆盖默认指标名；温度模式与热压力模式共用 `.thermal` 类别。
        let label: String?

        init(kind: Kind, status: MetricStatus?, value: String, label: String? = nil) {
            self.kind = kind
            self.status = status
            self.value = value
            self.label = label
        }
    }

    let items: [Item]
    let score: Int
    let worst: MetricStatus
    let warningCount: Int
    let criticalCount: Int

    /// 热压力模式：App Store 宿主只拿得到系统热压力。
    init(
        cpuPercent: Double,
        memoryPercent: Double,
        thermalState: ProcessInfo.ThermalState,
        batteryHealth: Double?,
        diskFreeBytes: Int64,
        diskTotalBytes: Int64
    ) {
        self.init(
            cpuPercent: cpuPercent,
            memoryPercent: memoryPercent,
            thermalItem: Item(
                kind: .thermal,
                status: ThermalPressure.status(for: thermalState),
                value: ThermalPressure.title(for: thermalState)
            ),
            batteryHealth: batteryHealth,
            diskFreeBytes: diskFreeBytes,
            diskTotalBytes: diskTotalBytes
        )
    }

    /// 温度模式：宿主安装了精确温度传感器。
    init(
        cpuPercent: Double,
        memoryPercent: Double,
        thermalCelsius: Double?,
        batteryHealth: Double?,
        diskFreeBytes: Int64,
        diskTotalBytes: Int64
    ) {
        let label = pluginLocalization.string("CPU Temperature")
        let thermalItem: Item
        if let thermalCelsius {
            thermalItem = Item(
                kind: .thermal,
                status: .cpuTemperature(thermalCelsius),
                value: String(format: "%.0f°C", thermalCelsius),
                label: label
            )
        } else {
            thermalItem = Item(kind: .thermal, status: nil, value: "--", label: label)
        }
        self.init(
            cpuPercent: cpuPercent,
            memoryPercent: memoryPercent,
            thermalItem: thermalItem,
            batteryHealth: batteryHealth,
            diskFreeBytes: diskFreeBytes,
            diskTotalBytes: diskTotalBytes
        )
    }

    private init(
        cpuPercent: Double,
        memoryPercent: Double,
        thermalItem: Item,
        batteryHealth: Double?,
        diskFreeBytes: Int64,
        diskTotalBytes: Int64
    ) {
        var items: [Item] = [
            Item(
                kind: .cpu,
                status: MetricStatusScale.from(percentage: cpuPercent),
                value: Self.percent(cpuPercent)
            ),
        ]

        items.append(thermalItem)

        items.append(
            Item(
                kind: .memory,
                status: MetricStatusScale.from(percentage: memoryPercent),
                value: Self.percent(memoryPercent)
            )
        )

        if let batteryHealth {
            items.append(
                Item(
                    kind: .battery,
                    status: .batteryHealth(batteryHealth),
                    value: Self.percent(batteryHealth)
                )
            )
        }

        if diskTotalBytes > 0 {
            let freeRatio = Double(max(0, diskTotalBytes - diskFreeBytes)) / Double(diskTotalBytes)
            items.append(
                Item(
                    kind: .storage,
                    status: .diskFree(freeRatio * 100),
                    value: ByteCountFormatter.string(fromByteCount: max(0, diskFreeBytes), countStyle: .file)
                )
            )
        } else {
            items.append(Item(kind: .storage, status: nil, value: "--"))
        }

        let evaluated = items.compactMap(\.status)
        let warnings = evaluated.filter { $0 == .warning }.count
        let criticals = evaluated.filter { $0 == .critical }.count

        var rawScore = 100
        for item in items {
            guard let status = item.status else { continue }
            rawScore -= Self.deduction(kind: item.kind, status: status)
        }
        if criticals > 0 {
            rawScore = min(rawScore, 59)
        } else if warnings > 0 {
            rawScore = min(rawScore, 84)
        }

        self.items = items
        self.warningCount = warnings
        self.criticalCount = criticals
        self.score = max(0, rawScore)
        self.worst = evaluated.contains(.critical) ? .critical : (evaluated.contains(.warning) ? .warning : .normal)
    }

    /// 参与评分的项数（不含不可用项）。
    var evaluatedCount: Int {
        items.filter { $0.status != nil }.count
    }

    var attentionCount: Int {
        warningCount + criticalCount
    }

    var band: Band {
        if criticalCount > 0 { return .poor }
        if warningCount > 0 { return .fair }
        return .good
    }

    // MARK: - Helpers

    private static func deduction(kind: Kind, status: MetricStatus) -> Int {
        switch (kind, status) {
        case (_, .normal):
            return 0
        case (.cpu, .warning): return 8
        case (.cpu, .critical): return 18
        case (.memory, .warning): return 10
        case (.memory, .critical): return 22
        case (.thermal, .warning): return 12
        case (.thermal, .critical): return 26
        case (.battery, .warning): return 8
        case (.battery, .critical): return 18
        case (.storage, .warning): return 8
        case (.storage, .critical): return 16
        }
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }
}

// MARK: - 展示文案

extension DashboardHealth.Band {
    var localizedTitle: String {
        switch self {
        case .good: return pluginLocalization.string("Good")
        case .fair: return pluginLocalization.string("Fair")
        case .poor: return pluginLocalization.string("Poor")
        }
    }
}

extension MetricStatus {
    var localizedTitle: String {
        switch self {
        case .normal: return pluginLocalization.string("Normal")
        case .warning: return pluginLocalization.string("Warning")
        case .critical: return pluginLocalization.string("Critical")
        }
    }
}

extension DashboardHealth.Kind {
    var localizedTitle: String {
        switch self {
        case .cpu: return pluginLocalization.string("CPU Usage")
        case .thermal: return pluginLocalization.string("Thermal Pressure")
        case .memory: return pluginLocalization.string("Memory Usage")
        case .battery: return pluginLocalization.string("Battery health")
        case .storage: return pluginLocalization.string("Disk available")
        }
    }
}

#endif
