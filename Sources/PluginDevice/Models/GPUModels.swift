#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

public enum GPUTimeRange: String, CaseIterable, Identifiable, DeviceHistoryRange {
    case hour1
    case hour4
    case hour24
    case month1

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hour1: return pluginLocalization.string("1 Hour")
        case .hour4: return pluginLocalization.string("4 Hours")
        case .hour24: return pluginLocalization.string("24 Hours")
        case .month1: return pluginLocalization.string("30 Days")
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .hour1: return 3600
        case .hour4: return 14400
        case .hour24: return 86400
        case .month1: return 2592000
        }
    }

    /// 仅 1 小时范围使用秒级高频缓冲,更长范围使用分钟级聚合缓冲。
    public var usesHighResolutionBuffer: Bool {
        self == .hour1
    }
}

public struct GPUDataPoint: Codable, Identifiable, Equatable, Sendable, DeviceHistorySample {
    public var id: TimeInterval { timestamp }
    public let timestamp: TimeInterval
    public let usage: Double
}

/// Single reading snapshot from IOKit GPU metrics.
public struct GPUReading: Sendable {
    /// GPU device utilization percentage (0–100).
    public let utilization: Double
    /// Renderer utilization percentage (0–100).
    public let rendererUtilization: Double
    /// Tiler utilization percentage (0–100).
    public let tilerUtilization: Double
    /// GPU memory currently in use (bytes).
    public let usedMemory: UInt64
    /// Total GPU memory allocated (bytes).
    public let totalMemory: UInt64
    /// GPU temperature in Celsius.
    public let temperature: Double
    /// GPU model name (e.g. "Apple M1 Pro GPU").
    public let modelName: String

    public static let empty = GPUReading(
        utilization: 0,
        rendererUtilization: 0,
        tilerUtilization: 0,
        usedMemory: 0,
        totalMemory: 0,
        temperature: 0,
        modelName: ""
    )
}

#endif
