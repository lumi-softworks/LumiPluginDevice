#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Combine
import Foundation

@MainActor
final class StorageManagerViewModel: ObservableObject {
    @Published private(set) var externalVolumes: [VolumeInfo] = []

    func apply(_ volumes: [VolumeInfo]) {
        externalVolumes = volumes
    }
}

/// 范围缓存的键：缓冲层选择 + 时长唯一确定一个裁剪窗口。
struct HistoryRangeKey: Hashable {
    let usesHighResolutionBuffer: Bool
    let duration: TimeInterval
}

@MainActor
final class DeviceHistoryViewModel<Point: DeviceHistorySample>: ObservableObject {
    @Published private(set) var recentHistory: [Point] = []
    @Published private(set) var longTermHistory: [Point] = []

    private var rangeCache: [HistoryRangeKey: [Point]] = [:]

    /// 应用高频缓冲（每个采样 tick 调用一次）。
    ///
    /// 只发布 `recentHistory` 并只失效高频范围的缓存：recent-only 的采样
    /// 不得唤醒未变化的长期图表（30 天视图）重算（#1209）。
    func applyRecent(_ points: [Point]) {
        recentHistory = points
        // 高频缓冲变化只失效高频范围（hour1）的缓存。
        rangeCache = rangeCache.filter { !$0.key.usesHighResolutionBuffer }
    }

    /// 应用长期缓冲（分钟聚合或历史恢复时调用）。
    func applyLongTerm(_ points: [Point]) {
        longTermHistory = points
        // 长期缓冲变化只失效长期范围的缓存，hour1 不受影响。
        rangeCache = rangeCache.filter { $0.key.usesHighResolutionBuffer }
    }

    /// 按时间范围裁剪历史数据。
    ///
    /// 1 小时范围取秒级高频缓冲,更长范围取分钟级聚合缓冲;
    /// 两者都按 `range.duration` 剔除过期样本,避免不同范围展示同一份数据。
    /// 结果按范围缓存，缓冲未变化时 `data(for:)` 不再重复线性过滤
    /// 数万点的长期数组（#1209）。
    func data(for range: some DeviceHistoryRange) -> [Point] {
        let key = HistoryRangeKey(
            usesHighResolutionBuffer: range.usesHighResolutionBuffer,
            duration: range.duration
        )
        if let cached = rangeCache[key] { return cached }
        let cutoff = Date().timeIntervalSince1970 - range.duration
        let buffer = range.usesHighResolutionBuffer ? recentHistory : longTermHistory
        let points = buffer.filter { $0.timestamp >= cutoff }
        rangeCache[key] = points
        return points
    }
}

@MainActor
final class DevicePluginViewModels: ObservableObject {
    let deviceData: DeviceData
    let cpu: CPUManagerViewModel
    let memory: MemoryManagerViewModel
    let gpu: GPUManagerViewModel
    let battery: BatteryManagerViewModel
    let storage: StorageManagerViewModel
    let systemMonitor: SystemMonitorViewModel
    let thermal: ThermalViewModel
    let menuBar: DeviceInfoMenuBarContentViewModel
    let cpuHistory = DeviceHistoryViewModel<CPUDataPoint>()
    let thermalHistory = DeviceHistoryViewModel<ThermalDataPoint>()
    let gpuHistory = DeviceHistoryViewModel<GPUDataPoint>()
    let memoryHistory = DeviceHistoryViewModel<MemoryDataPoint>()

    init() {
        deviceData = DeviceData()
        cpu = CPUManagerViewModel()
        memory = MemoryManagerViewModel()
        gpu = GPUManagerViewModel()
        battery = BatteryManagerViewModel()
        storage = StorageManagerViewModel()
        systemMonitor = SystemMonitorViewModel()
        thermal = ThermalViewModel(usesSensors: ThermalService.shared.usesSensors)
        menuBar = DeviceInfoMenuBarContentViewModel()
    }
}

#endif
