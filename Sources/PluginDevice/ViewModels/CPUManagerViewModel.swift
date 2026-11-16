#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

@MainActor
class CPUManagerViewModel: ObservableObject {
    static let emoji = "🧠"
    nonisolated static let verbose: Bool = false
    
    // MARK: - Properties
    
    @Published var cpuUsage: Double = 0.0
    @Published var perCoreUsage: [Double] = []
    @Published var loadAverage: [Double] = [0, 0, 0]
    @Published var topProcesses: [ProcessMetric] = []
    @Published var userUsage: Double = 0.0
    @Published var systemUsage: Double = 0.0
    @Published var idleUsage: Double = 100.0
    
    private let monitorsProcesses: Bool
    
    // MARK: - Initialization
    
    init(monitorsProcesses: Bool = true) {
        self.monitorsProcesses = monitorsProcesses
    }
    
    // MARK: - Public Methods
    
    func apply(usage: Double, perCoreUsage: [Double], loadAverage: [Double], user: Double, system: Double, idle: Double) {
        cpuUsage = usage
        self.perCoreUsage = perCoreUsage
        self.loadAverage = loadAverage
        userUsage = user
        systemUsage = system
        idleUsage = idle
    }

    func apply(topProcesses: [ProcessMetric]) {
        guard monitorsProcesses else { return }
        self.topProcesses = topProcesses
    }
    
    // MARK: - Computed Properties

    /// 主弹窗只展示前 5 条；完整列表在详情页查看。
    var topProcessesPreview: [ProcessMetric] {
        Array(topProcesses.prefix(5))
    }

    var formattedLoadAverage: String {
        loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  ")
    }
}

#endif
