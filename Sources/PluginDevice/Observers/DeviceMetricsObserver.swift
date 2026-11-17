#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Combine
import Foundation

/// 将设备服务的外部采样结果转成插件 ViewModel 状态。
@MainActor
final class DeviceMetricsObserver {
    private var cancellables = Set<AnyCancellable>()
    private var dynamicDataTimer: Timer?
    private let viewModels: DevicePluginViewModels

    init(viewModels: DevicePluginViewModels) {
        self.viewModels = viewModels

        CPUService.shared.startMonitoring()
        MemoryService.shared.startMonitoring()
        GPUService.shared.startMonitoring()
        BatteryService.shared.startMonitoring()
        StorageService.shared.startMonitoring()
        SystemMonitorService.shared.startMonitoring()
        ThermalService.shared.startMonitoring()

        // 订阅每 tick 一次的原子快照：combineLatest 六个独立属性会让每个
        // 采样发射 6 次，历史每秒被写入 6 个点（#1210）。
        // dropFirst() 跳过 @Published 订阅时重放的当前值。
        Self.observeCPUUsageSnapshots(
            CPUService.shared.$usageSnapshot.dropFirst().eraseToAnyPublisher(),
            record: { usage in
                CPUHistoryService.shared.recordDataPoint(usage: usage)
            },
            apply: { [weak self] snapshot in
                self?.viewModels.cpu.apply(
                    usage: snapshot.cpuUsage,
                    perCoreUsage: snapshot.perCoreUsage,
                    loadAverage: snapshot.loadAverage,
                    user: snapshot.userUsage,
                    system: snapshot.systemUsage,
                    idle: snapshot.idleUsage
                )
            },
            applyMenuBar: { [weak self] usage, perCoreUsage in
                self?.viewModels.menuBar.applyCPU(usage: usage, perCoreUsage: perCoreUsage)
            }
        )
        .store(in: &cancellables)

        ProcessService.shared.startMonitoring()
        ProcessService.shared.$topProcesses
            .sink { [weak self] processes in
                self?.viewModels.cpu.apply(topProcesses: processes)
            }
            .store(in: &cancellables)
        ProcessService.shared.$topMemoryProcesses
            .sink { [weak self] processes in
                self?.viewModels.memory.apply(topProcesses: processes)
            }
            .store(in: &cancellables)

        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory, MemoryService.shared.$totalMemory)
            .sink { [weak self] percentage, used, total in
                MemoryHistoryService.shared.recordDataPoint(pct: percentage, bytes: used)
                self?.viewModels.memory.apply(percentage: percentage, used: used, total: total)
                self?.viewModels.menuBar.applyMemory(percentage: percentage, used: used, total: total)
            }
            .store(in: &cancellables)

        GPUService.shared.$utilization
            .sink { utilization in GPUHistoryService.shared.recordDataPoint(usage: utilization) }
            .store(in: &cancellables)
        BatteryService.shared.$watts
            .sink { watts in BatteryHistoryService.shared.recordDataPoint(watts: watts) }
            .store(in: &cancellables)

        GPUService.shared.objectWillChange
            .sink { [weak self] in self?.viewModels.gpu.apply(GPUService.shared) }
            .store(in: &cancellables)
        BatteryService.shared.objectWillChange
            .sink { [weak self] in self?.viewModels.battery.apply(BatteryService.shared) }
            .store(in: &cancellables)
        StorageService.shared.objectWillChange
            .sink { [weak self] in self?.viewModels.storage.apply(StorageService.shared) }
            .store(in: &cancellables)
        SystemMonitorService.shared.$currentMetrics
            .sink { [weak self] metrics in self?.viewModels.systemMonitor.apply(metrics) }
            .store(in: &cancellables)
        // 用 `$peakCelsius` 订阅而非 `objectWillChange`:
        // 后者在数值变更「之前」触发,读到的仍是上一轮采样值,首屏会出现数秒空档。
        ThermalService.shared.$peakCelsius
            .sink { [weak self] peak in
                guard let self else { return }
                self.viewModels.thermal.apply(
                    readings: ThermalService.shared.readings,
                    peak: peak
                )
                if let peak {
                    ThermalHistoryService.shared.recordDataPoint(celsius: peak)
                }
            }
            .store(in: &cancellables)

        // 四组历史缓冲各自分开订阅：`@Published` 只在缓冲真正变化时发射。
        // 原先 combineLatest 让 recent-only 的采样 tick 也携带长期缓冲进入
        // apply，把未变化的 30 天数据重新发布一遍（#1209）。
        CPUHistoryService.shared.$recentHistory
            .sink { [weak self] recent in self?.viewModels.cpuHistory.applyRecent(recent) }
            .store(in: &cancellables)
        CPUHistoryService.shared.$longTermHistory
            .sink { [weak self] longTerm in self?.viewModels.cpuHistory.applyLongTerm(longTerm) }
            .store(in: &cancellables)
        ThermalHistoryService.shared.$recentHistory
            .sink { [weak self] recent in self?.viewModels.thermalHistory.applyRecent(recent) }
            .store(in: &cancellables)
        ThermalHistoryService.shared.$longTermHistory
            .sink { [weak self] longTerm in self?.viewModels.thermalHistory.applyLongTerm(longTerm) }
            .store(in: &cancellables)
        GPUHistoryService.shared.$recentHistory
            .sink { [weak self] recent in self?.viewModels.gpuHistory.applyRecent(recent) }
            .store(in: &cancellables)
        GPUHistoryService.shared.$longTermHistory
            .sink { [weak self] longTerm in self?.viewModels.gpuHistory.applyLongTerm(longTerm) }
            .store(in: &cancellables)
        MemoryHistoryService.shared.$recentHistory
            .sink { [weak self] recent in self?.viewModels.memoryHistory.applyRecent(recent) }
            .store(in: &cancellables)
        MemoryHistoryService.shared.$longTermHistory
            .sink { [weak self] longTerm in self?.viewModels.memoryHistory.applyLongTerm(longTerm) }
            .store(in: &cancellables)

        dynamicDataTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModels.deviceData.updateDynamicData()
            }
        }
        viewModels.deviceData.updateDynamicData()
        viewModels.gpu.apply(GPUService.shared)
        viewModels.battery.apply(BatteryService.shared)
        viewModels.storage.apply(StorageService.shared)
        viewModels.systemMonitor.apply(SystemMonitorService.shared.currentMetrics)
    }

    /// 把「每个快照记录一个历史点并刷新一次 UI」的接线独立出来，
    /// 便于用受控发布器验证 1:1 关系，而不必构造完整的 observer（#1210）。
    static func observeCPUUsageSnapshots(
        _ snapshots: AnyPublisher<CPUUsageSnapshot, Never>,
        record: @escaping (Double) -> Void,
        apply: @escaping (CPUUsageSnapshot) -> Void,
        applyMenuBar: @escaping (Double, [Double]) -> Void
    ) -> AnyCancellable {
        snapshots.sink { snapshot in
            record(snapshot.cpuUsage)
            apply(snapshot)
            applyMenuBar(snapshot.cpuUsage, snapshot.perCoreUsage)
        }
    }

    func cancel() {
        dynamicDataTimer?.invalidate()
        dynamicDataTimer = nil
        cancellables.removeAll()
        CPUService.shared.stopMonitoring()
        MemoryService.shared.stopMonitoring()
        GPUService.shared.stopMonitoring()
        BatteryService.shared.stopMonitoring()
        StorageService.shared.stopMonitoring()
        SystemMonitorService.shared.stopMonitoring()
        ThermalService.shared.stopMonitoring()
        ProcessService.shared.stopMonitoring()
        CPUHistoryService.shared.stopRecording()
        ThermalHistoryService.shared.stopRecording()
        GPUHistoryService.shared.stopRecording()
        MemoryHistoryService.shared.stopRecording()
        BatteryHistoryService.shared.stopRecording()
    }
}

#endif
