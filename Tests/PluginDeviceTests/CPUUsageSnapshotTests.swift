import Combine
import Foundation
import Testing
@testable import PluginDevice

/// 回归 #1210：每个 1Hz CPU 采样 tick 必须只发布一个原子快照，
/// 历史记录边界每个快照只写入一个点（修复前六个 @Published 属性的
/// combineLatest 每 tick 写 6 个点，3600 上限实际只覆盖约 10 分钟）。
@MainActor
struct CPUUsageSnapshotTests {

    @Test("每个采样 tick 只发布一个原子快照")
    func samplingTickPublishesExactlyOneAtomicSnapshot() async throws {
        // 独立实例：不与 UI 共享单例状态。监控定时器虽挂在主 RunLoop 上，
        // 但测试期间主 RunLoop 未被驱动，不会产生额外 tick。
        let service = CPUService()
        service.startMonitoring()
        defer { service.stopMonitoring() }

        var snapshots: [CPUUsageSnapshot] = []
        var cancellables = Set<AnyCancellable>()
        service.$usageSnapshot
            .dropFirst()
            .sink { snapshots.append($0) }
            .store(in: &cancellables)

        // startMonitoring 已触发首个采样；随后三个 tick 逐个驱动并等待完成。
        for _ in 0..<3 {
            service.updateCPUUsage()
            let deadline = Date().addingTimeInterval(5)
            while service.isSampling {
                if Date() > deadline {
                    Issue.record("Sampling tick did not finish within 5 seconds")
                    break
                }
                await Task.yield()
            }
        }

        // 修复前：六个 @Published 逐个赋值，combineLatest 每 tick 发射 6 次。
        #expect(snapshots.count == 3)
        let last = try #require(snapshots.last)
        #expect(last.cpuUsage == service.cpuUsage)
        #expect(last.perCoreUsage == service.perCoreUsage)
        #expect(last.loadAverage == service.loadAverage)
        #expect(last.userUsage == service.userUsage)
        #expect(last.systemUsage == service.systemUsage)
        #expect(last.idleUsage == service.idleUsage)
    }

    @Test("快照记录边界每快照一个历史点与一次 UI 刷新")
    func cpuRecordingWritesOneHistoryPointPerSnapshot() {
        let subject = PassthroughSubject<CPUUsageSnapshot, Never>()
        var recorded: [Double] = []
        var applied: [CPUUsageSnapshot] = []
        var menuBarCalls: [(usage: Double, perCore: [Double])] = []
        let cancellable = DeviceMetricsObserver.observeCPUUsageSnapshots(
            subject.eraseToAnyPublisher(),
            record: { recorded.append($0) },
            apply: { applied.append($0) },
            applyMenuBar: { usage, perCore in menuBarCalls.append((usage, perCore)) }
        )
        defer { cancellable.cancel() }

        for index in 1...3 {
            subject.send(CPUUsageSnapshot(
                cpuUsage: Double(index) * 10,
                perCoreUsage: [Double(index) * 5, Double(index) * 5],
                loadAverage: [Double(index), 0, 0],
                userUsage: Double(index) * 2,
                systemUsage: Double(index),
                idleUsage: 100 - Double(index) * 3
            ))
        }

        #expect(recorded == [10, 20, 30])
        #expect(applied.count == 3)
        #expect(menuBarCalls.count == 3)
        #expect(menuBarCalls.last?.usage == 30)
        #expect(menuBarCalls.last?.perCore == [15, 15])
    }

    @Test("快照字段保持原子一致")
    func cpuRecordingKeepsSnapshotFieldsAtomic() {
        let subject = PassthroughSubject<CPUUsageSnapshot, Never>()
        var applied: [CPUUsageSnapshot] = []
        let cancellable = DeviceMetricsObserver.observeCPUUsageSnapshots(
            subject.eraseToAnyPublisher(),
            record: { _ in },
            apply: { applied.append($0) },
            applyMenuBar: { _, _ in }
        )
        defer { cancellable.cancel() }

        let snapshot = CPUUsageSnapshot(
            cpuUsage: 42,
            perCoreUsage: [30, 54],
            loadAverage: [1.5, 1.2, 0.9],
            userUsage: 20,
            systemUsage: 22,
            idleUsage: 58
        )
        subject.send(snapshot)

        #expect(applied == [snapshot])
    }
}
