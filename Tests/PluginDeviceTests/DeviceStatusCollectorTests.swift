import Testing
@testable import PluginDevice

/// `device_status(scope: .processes)` 的进程榜单与按需采样回归测试（#1293）。
///
/// 修复前 `collect` 是同步主 actor 方法：启动窗口内 `topProcesses` 为空时，
/// 整个 libproc 全量枚举（proc_listpids + 每 PID proc_pidinfo/proc_pidpath）
/// 直接压在主线程上执行。修复后枚举与排序都在后台线程完成，只在主 actor
/// 上读写服务状态。
@Suite("DeviceStatusCollector 进程榜单")
struct DeviceStatusCollectorProcessTests {

    @Test("processes 范围合并 CPU 榜与内存榜并去重，按 CPU 优先排序")
    @MainActor
    func processesScopeMergesRankingsAndDedups() async throws {
        let service = ProcessService.shared
        defer { service.topProcesses = [] }
        service.topProcesses = [
            ProcessMetric(id: 100, name: "both", icon: nil, cpuUsage: 80, memoryUsage: 500),
            ProcessMetric(id: 101, name: "cpu-only", icon: nil, cpuUsage: 40, memoryUsage: 100),
            ProcessMetric(id: 102, name: "memory-only", icon: nil, cpuUsage: 0, memoryUsage: 900),
            ProcessMetric(id: 103, name: "low", icon: nil, cpuUsage: 0.05, memoryUsage: 200),
        ]

        let payload = await DeviceStatusCollector().collect(scope: .processes)

        let names = payload.processes.map(\.name)
        // 同一 pid 只出现一次（CPU 榜与内存榜去重）。
        #expect(Set(names).count == names.count)
        #expect(names == ["both", "cpu-only", "low", "memory-only"])
        let both = try #require(payload.processes.first { $0.name == "both" })
        #expect(both.cpuPercentage == 80)
        #expect(both.memoryBytes == 500)
    }

    @Test("榜单超过上限时只保留前 processLimit 条")
    @MainActor
    func processesScopeCapsAtLimit() async throws {
        let service = ProcessService.shared
        defer { service.topProcesses = [] }
        service.topProcesses = (0..<20).map { index in
            ProcessMetric(id: Int32(1000 + index), name: "p\(index)", icon: nil, cpuUsage: Double(20 - index), memoryUsage: 0)
        }

        let payload = await DeviceStatusCollector().collect(scope: .processes)

        #expect(payload.processes.count == DeviceStatusCollector.processLimit)
        #expect(payload.processes.first?.name == "p0")
    }

    /// 按需采样两轮语义：冷基线第一轮只播种快照（返回空），第二轮
    /// 有可比对的上轮数据，返回真实的进程聚合结果。修复前的同步
    /// 实现也具备该语义，回归点在于新的异步入口必须保持它。
    @Test("按需采样第一轮播种基线，第二轮返回真实进程")
    @MainActor
    func onDemandSamplingSeedsBaselineThenReturnsMetrics() async throws {
        let service = ProcessService()

        let first = await service.sampleProcessesOnce()
        #expect(first.isEmpty, "冷基线下首轮无可比对数据，应返回空列表")

        let second = await service.sampleProcessesOnce()
        #expect(!second.isEmpty, "播种基线后第二轮应返回真实进程聚合结果")
        #expect(second.allSatisfy { !$0.name.isEmpty })
    }
}
