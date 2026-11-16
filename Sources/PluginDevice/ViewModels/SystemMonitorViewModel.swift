#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation
import SwiftUI

@MainActor
class SystemMonitorViewModel: ObservableObject {
    @Published var metrics: SystemMetrics = .empty
    init() {
    }

    func apply(_ metrics: SystemMetrics) {
        self.metrics = metrics
    }
    
    func startMonitoring() {
        SystemMonitorService.shared.startMonitoring()
    }
    
    func stopMonitoring() {
        SystemMonitorService.shared.stopMonitoring()
    }
    
    // MARK: - Helpers
    
    var cpuColor: Color {
        MetricStatusScale.from(ratio: metrics.cpuUsage.percentage).themeColor
    }

    var memoryColor: Color {
        MetricStatusScale.from(ratio: metrics.memoryUsage.percentage).themeColor
    }
}

#endif
