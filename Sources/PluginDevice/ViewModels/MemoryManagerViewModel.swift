#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

@MainActor
class MemoryManagerViewModel: ObservableObject {
    static let emoji = "💾"

    @Published var memoryUsagePercentage: Double = 0.0
    @Published var usedMemory: String = "0 GB"
    @Published var totalMemory: String = "0 GB"
    @Published var rawTotalMemory: UInt64 = 0
    @Published var topProcesses: [ProcessMetric] = []

    init() {}

    func apply(percentage: Double, used: UInt64, total: UInt64) {
        memoryUsagePercentage = percentage
        usedMemory = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)
        totalMemory = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
        rawTotalMemory = total
    }

    func apply(topProcesses: [ProcessMetric]) {
        self.topProcesses = topProcesses
    }

    /// 主弹窗只展示前 5 条内存占用进程。
    var topProcessesPreview: [ProcessMetric] {
        Array(topProcesses.prefix(5))
    }
}

#endif
