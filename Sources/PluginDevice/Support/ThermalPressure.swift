#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

/// 系统热压力（`ProcessInfo.thermalState`）到状态与文案的映射。
///
/// App Store 审核禁止引用 IOHID 私有温度接口，macOS 也没有公开的摄氏度 API，
/// 因此这里只消费系统公开的热压力等级。
enum ThermalPressure {

    /// 把热压力映射为与 CPU / 内存一致的告警级别。
    static func status(for state: ProcessInfo.ThermalState) -> MetricStatus {
        switch state {
        case .nominal: return .normal
        case .fair: return .warning
        case .serious, .critical: return .critical
        @unknown default: return .normal
        }
    }

    /// 本地化后的等级文案。
    static func title(for state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return pluginLocalization.string("Normal")
        case .fair: return pluginLocalization.string("Warm")
        case .serious: return pluginLocalization.string("Serious")
        case .critical: return pluginLocalization.string("Critical")
        @unknown default: return pluginLocalization.string("Unknown")
        }
    }

    /// 四档中的位置（0–3），用于分段指示。
    static func level(for state: ProcessInfo.ThermalState) -> Int {
        switch state {
        case .nominal: return 0
        case .fair: return 1
        case .serious: return 2
        case .critical: return 3
        @unknown default: return 0
        }
    }
}

#endif