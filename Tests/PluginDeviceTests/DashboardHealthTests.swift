import Foundation
import Testing
@testable import PluginDevice

@Suite("DashboardHealth")
struct DashboardHealthTests {
    private func make(
        cpu: Double = 20,
        memory: Double = 40,
        thermal: Double? = 55,
        battery: Double? = 95,
        diskFree: Int64 = 500,
        diskTotal: Int64 = 1000
    ) -> DashboardHealth {
        DashboardHealth(
            cpuPercent: cpu,
            memoryPercent: memory,
            thermalCelsius: thermal,
            batteryHealth: battery,
            diskFreeBytes: diskFree,
            diskTotalBytes: diskTotal
        )
    }

    @Test("全部正常时 100 分、良好")
    func allNormalScoresFullMarks() {
        let health = make()

        #expect(health.score == 100)
        #expect(health.band == .good)
        #expect(health.worst == .normal)
        #expect(health.evaluatedCount == 5)
        #expect(health.attentionCount == 0)
    }

    @Test("出现告警时得分封顶 84、评级为一般")
    func warningCapsScoreAt84() {
        // CPU 65% 触发告警（-8），原始分 92，按规则封顶 84。
        let health = make(cpu: 65)

        #expect(health.warningCount == 1)
        #expect(health.criticalCount == 0)
        #expect(health.score == 84)
        #expect(health.band == .fair)
        #expect(health.worst == .warning)
    }

    @Test("出现临界时得分封顶 59、评级为较差")
    func criticalCapsScoreAt59() {
        // CPU 90% 临界（-18），原始分 82，按规则封顶 59。
        let health = make(cpu: 90)

        #expect(health.criticalCount == 1)
        #expect(health.score == 59)
        #expect(health.band == .poor)
        #expect(health.worst == .critical)
    }

    @Test("多项告警按类别累加扣分，但仍封顶 84")
    func multipleWarningsAccumulate() {
        // CPU 65%（-8）+ 内存 65%（-10）= 82，未超过 84 封顶，保留 82。
        let health = make(cpu: 65, memory: 65)

        #expect(health.warningCount == 2)
        #expect(health.score == 82)
        #expect(health.band == .fair)
    }

    @Test("温度不可用时该项不参与评分")
    func missingThermalIsExcluded() {
        let health = make(thermal: nil)

        let thermal = health.items.first { $0.kind == .thermal }
        #expect(thermal?.status == nil)
        #expect(thermal?.value == "--")
        #expect(health.evaluatedCount == 4)
        #expect(health.score == 100)
        #expect(health.band == .good)
    }

    @Test("无电池时不生成电池项，共四项")
    func noBatteryOmitsBatteryItem() {
        let health = make(battery: nil)

        #expect(!health.items.contains { $0.kind == .battery })
        #expect(health.items.count == 4)
        #expect(health.evaluatedCount == 4)
    }

    @Test("尚未采到磁盘容量时存储项不参与评分")
    func missingDiskCapacityIsExcluded() {
        let health = make(diskFree: 0, diskTotal: 0)

        #expect(health.items.first { $0.kind == .storage }?.status == nil)
        #expect(health.evaluatedCount == 4)
        #expect(health.score == 100)
    }

    @Test(
        "磁盘可用空间阈值：10% 正常、低于 10% 告警、低于 5% 临界",
        arguments: [
            (50.0, MetricStatus.normal),
            (10.0, MetricStatus.normal),
            (9.99, MetricStatus.warning),
            (5.0, MetricStatus.warning),
            (4.99, MetricStatus.critical),
        ]
    )
    func diskFreeThresholds(percent: Double, expected: MetricStatus) {
        #expect(MetricStatus.diskFree(percent) == expected)
    }

    @Test(
        "CPU 温度阈值：70℃ 起告警、85℃ 起临界",
        arguments: [
            (69.9, MetricStatus.normal),
            (70.0, MetricStatus.warning),
            (84.9, MetricStatus.warning),
            (85.0, MetricStatus.critical),
        ]
    )
    func cpuTemperatureThresholds(celsius: Double, expected: MetricStatus) {
        #expect(MetricStatus.cpuTemperature(celsius) == expected)
    }
}
