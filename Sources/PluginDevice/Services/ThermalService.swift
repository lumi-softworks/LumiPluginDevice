#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

/// 系统热压力与可选温度传感器采集服务。
///
/// 热压力来自公开的 `ProcessInfo.thermalState`，任何 macOS 版本都可用。
/// 精确的摄氏度依赖宿主注入的 ``ThermalSensorProviding``：
///
/// - 核心竞争力只依赖公开 API，可安全通过 App Store 静态扫描；
/// - 需要精确温度的宿主（如 Lumi）安装 `PluginDeviceThermalSensors`，
///   由它提供 IOHID 实现；
/// - 未注入实现的宿主（如 Wakey）只展示热压力状态。
@MainActor
public final class ThermalService: ObservableObject {
    public static let shared = ThermalService()

    // MARK: - Published Properties

    /// 当前系统热压力。
    @Published public private(set) var state: ProcessInfo.ThermalState =
        ProcessInfo.processInfo.thermalState

    /// 全部有效温度读数，按传感器下标升序。
    @Published public private(set) var readings: [ThermalSensorReading] = []

    /// 最高温度读数（℃）；无数据时为 `nil`。
    ///
    /// 用 `nil` 而非 `0` 表达「读不到」，以便 UI 区分「没有温度数据」
    /// 与「温度真的是 0℃」。
    @Published public private(set) var peakCelsius: Double?

    // MARK: - Private Properties

    private var timer: Timer?
    private var subscribersCount = 0
    private var sensorProvider: (any ThermalSensorProviding)?
    private var isReadingSensors = false

    package init() {}

    // MARK: - Public Methods

    /// 是否由宿主安装了精确温度读取能力。
    ///
    /// UI 依据它选择展示温度还是热压力：安装后即使机器读不到传感器
    /// （Intel Mac），仍显示温度卡片与「无传感器」说明，保持宿主原有体验。
    public var usesSensors: Bool { sensorProvider != nil }

    /// 安装温度传感器实现。应在插件启动前的组合阶段调用。
    ///
    /// 本方法是核心包接触私有能力实现的唯一入口，实现本身位于可选模块。
    public static func install(sensorProvider: any ThermalSensorProviding) {
        shared.sensorProvider = sensorProvider
        if shared.subscribersCount > 0 {
            shared.sample()
        }
    }

    public func startMonitoring() {
        subscribersCount += 1
        guard timer == nil else { return }

        sample()

        let newTimer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        guard subscribersCount == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Sampling

    private func sample() {
        let current = ProcessInfo.processInfo.thermalState
        if current != state {
            state = current
        }

        guard let sensorProvider else { return }
        guard !isReadingSensors else { return }
        isReadingSensors = true

        // HID 读取涉及 CF 对象遍历，放到后台避免阻塞主线程。
        Task.detached(priority: .utility) { [weak self, sensorProvider] in
            let snapshot = sensorProvider.readSensors()
            let peak = snapshot.map(\.celsius).max()

            await MainActor.run {
                guard let self else { return }
                self.isReadingSensors = false
                guard self.subscribersCount > 0 else { return }
                if self.readings != snapshot {
                    self.readings = snapshot
                }
                if self.peakCelsius != peak {
                    self.peakCelsius = peak
                }
            }
        }
    }
}

#endif
