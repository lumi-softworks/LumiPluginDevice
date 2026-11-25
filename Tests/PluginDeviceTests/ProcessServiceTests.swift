import Darwin
import Testing
@testable import PluginDevice

/// `sysctl(KERN_PROC_ALL)` 枚举回归测试。
///
/// App Sandbox 拒绝 `proc_listpids`，枚举改走 sysctl；至少要能列出自
/// 己这个进程，否则榜单在沙盒宿主里永远是空的。
@Suite("ProcessService PID 枚举")
struct ProcessServiceEnumerationTests {
    @Test("枚举结果非空且包含当前进程")
    func enumeratesOwnProcess() {
        let pids = ProcessService.allProcessIDs()

        #expect(!pids.isEmpty)
        #expect(pids.contains(getpid()))
    }
}

/// 进程内存口径必须是 footprint（活动监视器 / Xcode / `top` MEM 列同款），
/// 否则 MLX 这类只落在 Metal buffer 上的权重会被漏掉：Lumi 自身显示几百 MB，
/// 而 Xcode 显示十几 GB。
@Suite("ProcessService 内存口径")
struct ProcessServiceMemoryBytesTests {

    private func selfFootprintFromTaskInfo() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<natural_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    @Test("自身进程返回 footprint，而不是 RSS")
    func returnsPhysFootprintForSelf() {
        let expected = selfFootprintFromTaskInfo()
        #expect(expected > 0)

        // residentBytes 故意给 1：实现若退回 RSS，返回值就会是 1。
        let bytes = ProcessService.memoryBytes(pid: getpid(), residentBytes: 1)

        // 两次读取之间 footprint 会小幅波动，只校验同一量级。
        #expect(bytes > 1)
        #expect(Int64(bytes) >= Int64(expected) / 2)
        #expect(Int64(bytes) <= Int64(max(expected * 2, 16 * 1024 * 1024)))
    }

    @Test("rusage 不可用时回落到 residentBytes")
    func fallsBackToResidentBytes() {
        // 不存在的 PID：proc_pid_rusage 必然失败，走回落分支。
        let bytes = ProcessService.memoryBytes(pid: Int32.max, residentBytes: 123_456)

        #expect(bytes == 123_456)
    }
}

/// `proc_taskinfo.pti_total_user/system` 的单位换算回归测试。
///
/// mach absolute time 的每秒 tick 数随硬件不同（Apple Silicon 24 MHz、
/// Intel 1 GHz），实现必须通过 `mach_timebase_info` 换算，不能假设固定值。
@Suite("ProcessService CPU 百分比换算")
struct ProcessServiceCPUPercentTests {

    private func timebase(_ numer: UInt32, _ denom: UInt32) -> mach_timebase_info_data_t {
        mach_timebase_info_data_t(numer: numer, denom: denom)
    }

    @Test("Apple Silicon 24MHz ticks 下占满单核为 100%")
    func appleSiliconTimebaseYieldsOneHundredPercent() {
        let percent = ProcessService.cpuPercent(
            forProcessTimeDelta: 24_000_000,
            elapsedSeconds: 1,
            timebase: timebase(125, 3)
        )

        #expect(abs(percent - 100) < 0.001)
    }

    @Test("Intel 1GHz ticks 下占满单核为 100%")
    func intelTimebaseYieldsOneHundredPercent() {
        let percent = ProcessService.cpuPercent(
            forProcessTimeDelta: 1_000_000_000,
            elapsedSeconds: 1,
            timebase: timebase(1, 1)
        )

        #expect(abs(percent - 100) < 0.001)
    }

    @Test("多线程进程可以超过 100%")
    func multiCoreUsageExceedsOneHundredPercent() {
        let percent = ProcessService.cpuPercent(
            forProcessTimeDelta: 48_000_000,
            elapsedSeconds: 1,
            timebase: timebase(125, 3)
        )

        #expect(abs(percent - 200) < 0.001)
    }

    @Test("零采样间隔返回 0")
    func zeroElapsedReturnsZero() {
        let percent = ProcessService.cpuPercent(
            forProcessTimeDelta: 1,
            elapsedSeconds: 0,
            timebase: timebase(125, 3)
        )

        #expect(percent == 0)
    }
}
