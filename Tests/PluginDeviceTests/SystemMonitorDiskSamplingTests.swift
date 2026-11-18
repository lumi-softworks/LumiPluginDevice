import Foundation
import Testing
@testable import PluginDevice

/// #229：磁盘计数器从未被调度读取，Disk I/O 卡片一直是 0 B/s。
///
/// 修复后周期采样循环借同一 samplingTask 槽位按 diskCounterInterval
/// 节流补充读取磁盘计数器，速率由相邻两次计数器差值除以时间差得出。
struct SystemMonitorDiskSamplingTests {
    /// 供等待后台采样任务完成的有界轮询；条件不满足则超时由断言暴露。
    @MainActor
    private func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    @Test("磁盘速率由相邻计数器差值除以时间差计算，首次采样为 0")
    @MainActor
    func diskRatesComeFromAdjacentCounterDeltas() {
        var clock: TimeInterval = 5_000
        let service = SystemMonitorService(
            diskCountersProvider: nil,
            timeProvider: { clock }
        )

        service.updateMetrics(diskCounters: (readBytes: 1_000, writeBytes: 500))
        #expect(service.currentMetrics.disk.readSpeed == 0)
        #expect(service.currentMetrics.disk.writeSpeed == 0)

        clock += 2
        service.updateMetrics(diskCounters: (readBytes: 9_000, writeBytes: 4_500))
        #expect(abs(service.currentMetrics.disk.readSpeed - 4_000) < 0.0001)
        #expect(abs(service.currentMetrics.disk.writeSpeed - 2_000) < 0.0001)
    }

    @Test("周期采样循环按 diskCounterInterval 调度磁盘计数器读取")
    @MainActor
    func periodicLoopSchedulesDiskCounterReads() async {
        final class CounterBox: @unchecked Sendable {
            var count = 0
        }
        let box = CounterBox()
        var clock: TimeInterval = 2_000
        let service = SystemMonitorService(
            diskCountersProvider: nil,
            diskCountersReader: {
                box.count += 1
                return (readBytes: 10, writeBytes: 20)
            },
            diskCounterInterval: 5,
            timeProvider: { clock }
        )
        // 周期采样只在 refCount > 0 时落地；测试同样走 start/stop 生命周期。
        service.startMonitoring()
        defer { service.stopMonitoring(force: true) }

        service.refreshScheduledMetricsForTesting()
        await waitUntil { box.count >= 1 }
        // 读取完成到其完成回调落地之间有微小窗口，留出沉降时间避免
        // 下一次调度撞上尚未清空的 samplingTask 槽位。
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(box.count == 1)

        clock += 6
        service.refreshScheduledMetricsForTesting()
        await waitUntil { box.count >= 2 }
        #expect(box.count == 2)
    }
}
