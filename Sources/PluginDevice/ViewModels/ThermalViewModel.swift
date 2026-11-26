#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation
import LumiUI
import SwiftUI

/// 热压力与可选温度的展示模型。
///
/// `usesSensors` 在创建时由宿主组合决定：安装温度提供者后展示摄氏度，
/// 否则展示系统热压力等级。两种模式共用同一个模型，避免 UI 分支散落。
@MainActor
final class ThermalViewModel: ObservableObject {

    // MARK: - Properties

    @Published private(set) var state: ProcessInfo.ThermalState

    /// 全部温度传感器读数；仅传感器模式有值。
    @Published private(set) var readings: [ThermalSensorReading] = []

    /// 最高温度（℃）；仅传感器模式可能非空。
    @Published private(set) var peakCelsius: Double?

    /// 宿主是否安装了精确温度读取能力。
    let usesSensors: Bool

    // MARK: - Initialization

    init(
        state: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState,
        usesSensors: Bool = false
    ) {
        self.state = state
        self.usesSensors = usesSensors
    }

    // MARK: - Public Methods

    func apply(state: ProcessInfo.ThermalState) {
        self.state = state
    }

    func apply(readings: [ThermalSensorReading], peak: Double?) {
        self.readings = readings
        peakCelsius = peak
    }

    // MARK: - Computed Properties

    /// 该机器是否存在可读的温度传感器。
    ///
    /// Intel Mac 无 PMU 传感器时为 `false`，UI 应显示「不可用」
    /// 而不是把 0 当作有效温度。
    var isAvailable: Bool { !readings.isEmpty }

    /// 最高温度显示值（例："65.1°C"）；无数据时为 `nil`。
    var peakString: String? {
        guard let peakCelsius else { return nil }
        return String(format: "%.1f°C", peakCelsius)
    }

    /// 最高温度对应的状态色。
    var peakColor: Color {
        guard let peakCelsius else { return .secondary }
        return MetricStatus.cpuTemperature(peakCelsius).themeColor
    }

    /// 热压力对应的告警级别。
    var status: MetricStatus { ThermalPressure.status(for: state) }

    /// 热压力的本地化文案（正常 / 偏热 / 过热 / 严重）。
    var title: String { ThermalPressure.title(for: state) }

    /// 热压力四档中的位置（0–3）。
    var level: Int { ThermalPressure.level(for: state) }

    /// 当前模式下的主色。
    var color: Color { usesSensors ? peakColor : status.themeColor }

    /// 菜单栏与页脚使用的指标名。
    var displayLabel: String {
        usesSensors
            ? pluginLocalization.string("Temperature")
            : pluginLocalization.string("Thermal Pressure")
    }

    /// 菜单栏与页脚使用的指标值。
    var displayValue: String {
        usesSensors ? (peakString ?? "—") : title
    }
}

#endif
