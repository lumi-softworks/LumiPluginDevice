#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Combine
import Foundation
import LumiLoggingKit
import os

/// 单次内存采样 tick 的原子快照：一次赋值发布全部指标，订阅方不再从
/// 三个独立属性的 combineLatest 中拼装（#382，与 CPU 的 #1210 同构）。
public struct MemoryUsageSnapshot: Equatable, Sendable {
    public var percentage: Double
    public var used: UInt64
    public var total: UInt64

    public init(percentage: Double, used: UInt64, total: UInt64) {
        self.percentage = percentage
        self.used = used
        self.total = total
    }
}

/// Memory monitoring service providing real-time memory usage data.
@MainActor
public final class MemoryService: ObservableObject, SuperLog {
    public static let shared = MemoryService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.memory")
    nonisolated(unsafe) static var verbose: Bool = false
    nonisolated public static let emoji = "🧠"

    // MARK: - Published Properties

    /// 每 tick 一次的原子快照（`#382`）：历史记录与 UI 刷新以它为唯一边界。
    @Published public private(set) var usageSnapshot = MemoryUsageSnapshot(
        percentage: 0,
        used: 0,
        total: ProcessInfo.processInfo.physicalMemory
    )

    /// Memory usage percentage (0.0 - 100.0)
    @Published public var memoryUsagePercentage: Double = 0.0

    /// Used memory (Bytes)
    @Published public var usedMemory: UInt64 = 0

    /// Total memory (Bytes)
    @Published public var totalMemory: UInt64 = 0

    /// Memory pressure description
    @Published public var memoryPressure: String = "Normal"

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var samplingTask: Task<Void, Never>?
    /// 是否有采样在途中（测试用它等待 tick 完成）。
    var isSampling: Bool { samplingTask != nil }
    private var subscribersCount = 0

    /// 心跳节流计数：每次内存采样 tick 自增，每 N 次打一条日志（1Hz 定时器 → 约每 10 秒一条）。
    /// 用于排查 CPU 占用持续 100% 时确认本采样链路是否在主线程持续运行。
    private var tickCount = 0
    private let tickLogEvery = 10

    package init() {
        self.totalMemory = ProcessInfo.processInfo.physicalMemory
    }

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(Self.emoji) 开始 Memory 监控")
            }

            updateMemoryUsage()

            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateMemoryUsage()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            monitoringTimer = timer
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(Self.emoji) 停止 Memory 监控")
            }

            monitoringTimer?.invalidate()
            monitoringTimer = nil
            samplingTask?.cancel()
            samplingTask = nil
        }
    }

    // MARK: - Internal Methods

    /// Compute memory usage for testing purposes.
    func computeMemoryUsage() -> (used: UInt64, total: UInt64) {
        Self.computeMemoryUsage(totalMemory: totalMemory)
    }

    private nonisolated static func computeMemoryUsage(totalMemory: UInt64) -> (used: UInt64, total: UInt64) {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, totalMemory) }

        let pageSize = getKernelPageSize()
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        return (used, totalMemory)
    }

    // MARK: - Private Methods

    private nonisolated static func getKernelPageSize() -> UInt64 {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        return result == KERN_SUCCESS ? UInt64(pageSize) : 4096
    }

    func updateMemoryUsage() {
        guard samplingTask == nil else { return }
        let totalMemory = totalMemory

        samplingTask = Task.detached(priority: .utility) { [totalMemory] in
            let (used, total) = Self.computeMemoryUsage(totalMemory: totalMemory)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.subscribersCount > 0 else { return }
                self.usedMemory = used
                self.memoryUsagePercentage = min(100.0, Double(used) / Double(total) * 100.0)
                // 原子快照必须在全部独立属性赋值「之后」发布，作为本 tick 的
                // 唯一历史/UI 边界（#382）。
                self.usageSnapshot = MemoryUsageSnapshot(
                    percentage: self.memoryUsagePercentage,
                    used: used,
                    total: total
                )

                // 节流心跳：确认 1Hz 内存采样链路在持续运行。
                self.tickCount += 1
                if Self.verbose, self.tickCount % self.tickLogEvery == 0 {
                    Self.logger.info("\(self.t)\(Self.emoji) tick #\(self.tickCount) 采样完成，mem=\(String(format: "%.1f", self.memoryUsagePercentage))%")
                }
            }
        }
    }
}

#endif
