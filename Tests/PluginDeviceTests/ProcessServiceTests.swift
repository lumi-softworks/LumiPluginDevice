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
