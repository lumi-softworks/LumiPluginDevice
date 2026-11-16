#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

/// CPU / die 温度的历史采样点。
public struct ThermalDataPoint: Codable, Identifiable, Equatable, Sendable, DeviceHistorySample {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let celsius: Double
}

#endif
