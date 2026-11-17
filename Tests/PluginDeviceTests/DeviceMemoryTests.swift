#if os(macOS)
import Foundation
import Testing
@testable import PluginDevice

@Suite("DeviceData memory statistics")
struct DeviceMemoryTests {

    @Test("used memory includes compressed pages")
    func usedMemoryIncludesCompressorPages() {
        var stats = vm_statistics64()
        stats.active_count = 1000
        stats.wire_count = 500
        stats.compressor_page_count = 2000

        let used = DeviceData.usedMemoryBytes(from: stats, pageSize: 16384)

        // 压缩页必须计入：漏算会显著低估内存占用（#649）。
        #expect(used == (1000 + 500 + 2000) * 16384)
    }

    @Test("used memory without compressor pages stays active plus wired")
    func usedMemoryWithoutCompressorPages() {
        var stats = vm_statistics64()
        stats.active_count = 1000
        stats.wire_count = 500
        stats.compressor_page_count = 0

        let used = DeviceData.usedMemoryBytes(from: stats, pageSize: 4096)

        #expect(used == 1500 * 4096)
    }

    @Test("live overview memory matches the popover flavor")
    func liveMemoryUsageIsSane() {
        let (used, total) = DeviceData.currentMemoryUsage()

        #expect(total == ProcessInfo.processInfo.physicalMemory)
        #expect(used > 0)
        #expect(used <= total)
    }
}
#endif
