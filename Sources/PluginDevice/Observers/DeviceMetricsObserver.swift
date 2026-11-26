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

        // 同 CPU（#1210）：订阅每 tick 一次的原子快照。combineLatest 三个
        // 独立属性会让每个采样发射 2 次（先「新 used + 旧百分比」，再完整
        // 快照），历史每秒被写入 2 个点且首条混入上一轮的百分比（#382）。
        // dropFirst() 跳过 @Published 订阅时重放的当前值。
        Self.observeMemoryUsageSnapshots(
            MemoryService.shared.$usageSnapshot.dropFirst().eraseToAnyPublisher(),
            record: { percentage, used in
                MemoryHistoryService.shared.recordDataPoint(pct: percentage, bytes: used)
            },
            apply: { [weak self] snapshot in
                self?.viewModels.memory.apply(
                    percentage: snapshot.percentage,
                    used: snapshot.used,
                    total: snapshot.total
                )
            },
            applyMenuBar: { [weak self] percentage, used, total in
                self?.viewModels.menuBar.applyMemory(percentage: percentage, used: used, total: total)
            }
        )
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
        // 用 `$externalVolumes` 订阅而非 `objectWillChange`：后者在属性写入
        // 「之前」触发，同步读取读到的是上一轮扫描的卷列表，挂载/推出/容量
        // 变化都会延迟一轮（#793）。订阅即回放当前值，替代单独的初始 apply。
        StorageService.shared.$externalVolumes
            .sink { [weak self] volumes in self?.viewModels.storage.apply(volumes) }
            .store(in: &cancellables)
        SystemMonitorService.shared.$currentMetrics
            .sink { [weak self] metrics in self?.viewModels.systemMonitor.apply(metrics) }
            .store(in: &cancellables)
        // 用 `$state` 订阅而非 `objectWillChange`，避免首屏读到上一轮采样值。
        ThermalService.shared.$state
            .sink { [weak self] state in
                self?.viewModels.thermal.apply(state: state)
            }
            .store(in: &cancellables)

        // 精确温度只在宿主安装提供者时订阅；未安装时服务不会发布读数。
        if ThermalService.shared.usesSensors {
            // 用 `$peakCelsius` 订阅而非 `objectWillChange`：
            // 后者在数值变更「之前」触发，读到的仍是上一轮采样值，首屏会出现数秒空档。
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
            // 峰值不变时传感器明细仍可能变化（个别传感器温度回落），
            // 单独订阅读数让明细保持实时。
            ThermalService.shared.$readings
                .sink { [weak self] readings in
                    guard let self else { return }
                    self.viewModels.thermal.apply(
                        readings: readings,
                        peak: ThermalService.shared.peakCelsius
                    )
                }
                .store(in: &cancellables)
        }

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

    /// Memory 与 CPU 同构：每个快照记录一个历史点并刷新一次 UI（#382）。
    static func observeMemoryUsageSnapshots(
        _ snapshots: AnyPublisher<MemoryUsageSnapshot, Never>,
        record: @escaping (Double, UInt64) -> Void,
        apply: @escaping (MemoryUsageSnapshot) -> Void,
        applyMenuBar: @escaping (Double, UInt64, UInt64) -> Void
    ) -> AnyCancellable {
        snapshots.sink { snapshot in
            record(snapshot.percentage, snapshot.used)
            apply(snapshot)
            applyMenuBar(snapshot.percentage, snapshot.used, snapshot.total)
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
        if ThermalService.shared.usesSensors {
            ThermalHistoryService.shared.stopRecording()
        }
        GPUHistoryService.shared.stopRecording()
        MemoryHistoryService.shared.stopRecording()
        BatteryHistoryService.shared.stopRecording()
    }
}

#endif
