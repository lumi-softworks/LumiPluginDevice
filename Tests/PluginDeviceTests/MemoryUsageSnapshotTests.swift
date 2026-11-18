import Combine
import Foundation
import Testing
@testable import PluginDevice

/// 回归 #382：每个 1Hz 内存采样 tick 必须只发布一个原子快照，历史记录
/// 边界每个快照只写入一个点（修复前三个 @Published 属性的 combineLatest
/// 每 tick 写 2 个点，且首条是「新 used + 旧百分比」的拼装值，3600 上限
/// 实际只覆盖约 30 分钟）。
@MainActor
struct MemoryUsageSnapshotTests {

    @Test("每个采样 tick 只发布一个原子快照")
    func samplingTickPublishesExactlyOneAtomicSnapshot() async throws {
        // 独立实例：不与 UI 共享单例状态。监控定时器虽挂在主 RunLoop 上，
        // 但测试期间主 RunLoop 未被驱动，不会产生额外 tick。
        let service = MemoryService()
        service.startMonitoring()
        defer { service.stopMonitoring() }

        var snapshots: [MemoryUsageSnapshot] = []
        var cancellables = Set<AnyCancellable>()
        service.$usageSnapshot
            .dropFirst()
            .sink { snapshots.append($0) }
            .store(in: &cancellables)

        // startMonitoring 已触发首个采样；随后三个 tick 逐个驱动并等待完成。
        for _ in 0..<3 {
            service.updateMemoryUsage()
            let deadline = Date().addingTimeInterval(5)
            while service.isSampling {
                if Date() > deadline {
                    Issue.record("Sampling tick did not finish within 5 seconds")
                    break
                }
                await Task.yield()
            }
        }

        // 修复前：usedMemory 与 memoryUsagePercentage 逐个赋值，
        // combineLatest 每 tick 发射 2 次。
        #expect(snapshots.count == 3)
        let last = try #require(snapshots.last)
        #expect(last.percentage == service.memoryUsagePercentage)
        #expect(last.used == service.usedMemory)
        #expect(last.total == service.totalMemory)
    }

    @Test("快照记录边界每快照一个历史点与一次 UI 刷新")
    func memoryRecordingWritesOneHistoryPointPerSnapshot() {
        let subject = PassthroughSubject<MemoryUsageSnapshot, Never>()
        var recorded: [(pct: Double, bytes: UInt64)] = []
        var applied: [MemoryUsageSnapshot] = []
        var menuBarCalls: [(pct: Double, used: UInt64, total: UInt64)] = []
        let cancellable = DeviceMetricsObserver.observeMemoryUsageSnapshots(
            subject.eraseToAnyPublisher(),
            record: { pct, bytes in recorded.append((pct, bytes)) },
            apply: { applied.append($0) },
            applyMenuBar: { pct, used, total in menuBarCalls.append((pct, used, total)) }
        )
        defer { cancellable.cancel() }

        for index in 1...3 {
            subject.send(MemoryUsageSnapshot(
                percentage: Double(index) * 10,
                used: UInt64(index) * 1_000_000,
                total: 16_000_000_000
            ))
        }

        #expect(recorded.count == 3)
        #expect(recorded.map(\.pct) == [10, 20, 30])
        #expect(recorded.map(\.bytes) == [1_000_000, 2_000_000, 3_000_000])
        #expect(applied.count == 3)
        #expect(menuBarCalls.count == 3)
        #expect(menuBarCalls.last?.pct == 30)
        #expect(menuBarCalls.last?.used == 3_000_000)
        #expect(menuBarCalls.last?.total == 16_000_000_000)
    }

    @Test("快照字段保持原子一致")
    func memoryRecordingKeepsSnapshotFieldsAtomic() {
        let subject = PassthroughSubject<MemoryUsageSnapshot, Never>()
        var applied: [MemoryUsageSnapshot] = []
        let cancellable = DeviceMetricsObserver.observeMemoryUsageSnapshots(
            subject.eraseToAnyPublisher(),
            record: { _, _ in },
            apply: { applied.append($0) },
            applyMenuBar: { _, _, _ in }
        )
        defer { cancellable.cancel() }

        let snapshot = MemoryUsageSnapshot(
            percentage: 55.5,
            used: 8_880_000_000,
            total: 16_000_000_000
        )
        subject.send(snapshot)

        #expect(applied == [snapshot])
    }
}
