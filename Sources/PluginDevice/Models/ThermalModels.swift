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

/// 单个温度传感器的瞬时读数。
public struct ThermalSensorReading: Identifiable, Equatable, Sendable {
    /// 传感器在 HID 服务数组中的下标，用作 `id`。
    ///
    /// - Note: 该下标在同一台机器的一次开机周期内稳定，但跨重启可能变化。
    ///   UI 侧不应把它当作持久标识（例如不要写进历史库主键）。
    public let index: Int

    /// 传感器类别。无法判定时为 `nil`。
    public let kind: SensorKind?

    /// 摄氏温度。
    public let celsius: Double

    public var id: Int { index }

    public init(index: Int, kind: SensorKind?, celsius: Double) {
        self.index = index
        self.kind = kind
        self.celsius = celsius
    }

    /// 传感器类别。
    public enum SensorKind: String, Sendable, CaseIterable {
        /// SoC 裸片温度（`tdie`）。
        case die
        /// 设备/模块温度（`tdev`）。
        case device
        /// 表面温度（`TP0s` 等）。
        case surface
    }
}

/// 温度传感器读取能力。
///
/// 核心包只依赖这个协议，不直接接触 IOHID 私有符号，因此可以在 App Store
/// 版本中安全链接。宿主若需要精确温度，可在组合插件时安装
/// `PluginDeviceThermalSensors` 提供的实现；否则只展示系统热压力。
public protocol ThermalSensorProviding: Sendable {
    /// 读取当前所有可用传感器；不可用时返回空数组。
    func readSensors() -> [ThermalSensorReading]
}

#endif
