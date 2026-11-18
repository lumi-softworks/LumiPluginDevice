import Foundation
import Testing
@testable import PluginDevice

/// #228：后台采样路径不得把开机累计的 CPU tick / 网络字节数当作瞬时值。
///
/// 生产共享实例走后台采样：旧实现直接把累计值算成使用率 / 原样透传，
/// CPU 曲线趋近开机均值、网络显示累计流量。现在 CPU 与网络都在
/// MainActor 侧按相邻采样差分。
struct SystemMonitorBackgroundDeltaTests {
    @Test("CPU tick 差分：首个采样返回 0，之后按差值计算")
    func cpuTicksDelta() {
        #expect(SystemMonitorService.cpuUsage(fromTicks: (600, 1000), previous: nil) == 0)
        let first = (used: Int64(500), total: Int64(1000))
        let second = (used: Int64(700), total: Int64(2000))
        #expect(abs(SystemMonitorService.cpuUsage(fromTicks: second, previous: first) - 0.2) < 0.0001)
    }

    @Test("CPU 计数器回绕或未前进时返回 0，不回退到累计均值")
    func cpuTicksResetReturnsZero() {
        let previous = (used: Int64(900), total: Int64(1000))
        // 总 tick 倒退（计数器重置）：不能拿当前累计均值 0.8 顶上
        #expect(SystemMonitorService.cpuUsage(fromTicks: (100, 200), previous: previous) == 0)
        // 没有新 tick：0
        #expect(SystemMonitorService.cpuUsage(fromTicks: previous, previous: previous) == 0)
    }

    @Test("网络速率按相邻采样差值除以时间差计算")
    func networkSpeedUsesDeltaOverElapsed() {
        let speed = SystemMonitorService.networkSpeed(
            currentIn: 10_000, currentOut: 6_000,
            previousIn: 5_000, previousOut: 5_000,
            elapsed: 2
        )
        #expect(abs(speed.download - 2500) < 0.0001)
        #expect(abs(speed.upload - 500) < 0.0001)

        #expect(SystemMonitorService.networkSpeed(
            currentIn: 10_000, currentOut: 6_000,
            previousIn: 5_000, previousOut: 5_000,
            elapsed: 0
        ) == (0, 0))

        // 计数器回退（网卡重置）：该方向为 0，另一方向照常
        let reset = SystemMonitorService.networkSpeed(
            currentIn: 100, currentOut: 6_000,
            previousIn: 5_000, previousOut: 5_000,
            elapsed: 2
        )
        #expect(reset.download == 0)
        #expect(abs(reset.upload - 500) < 0.0001)
    }

    @Test("后台采样链路：累计计数被换算成 B/s 与瞬时 CPU，而不是原样透传")
    @MainActor
    func backgroundPipelineConvertsCountersToRates() {
        var clock: TimeInterval = 1_000
        let service = SystemMonitorService(
            diskCountersProvider: nil,
            diskCounterInterval: 5,
            timeProvider: { clock }
        )

        service.applyBackgroundSamples(
            cpuTicks: (used: 100, total: 1_000),
            memUsed: 4 << 30,
            memTotal: 16 << 30,
            netCounters: (received: 1_000_000, sent: 500_000)
        )
        // 首个采样没有前值：速率为 0
        #expect(service.currentMetrics.network.downloadSpeed == 0)
        #expect(service.currentMetrics.network.uploadSpeed == 0)

        clock += 1
        service.applyBackgroundSamples(
            cpuTicks: (used: 350, total: 2_000),
            memUsed: 4 << 30,
            memTotal: 16 << 30,
            netCounters: (received: 1_005_000, sent: 502_000)
        )
        #expect(abs(service.currentMetrics.network.downloadSpeed - 5000) < 0.0001)
        #expect(abs(service.currentMetrics.network.uploadSpeed - 2000) < 0.0001)
        // Δused 250 / Δtotal 1000 = 25%
        #expect(abs(service.currentMetrics.cpuUsage.percentage - 0.25) < 0.0001)
    }
}
