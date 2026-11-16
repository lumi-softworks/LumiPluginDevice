#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
/// 传感器行标签；`resolve` 便于测试注入，默认走插件本地化资源。
enum ThermalSensorLabel {
    static func text(
        index: Int,
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        String(format: resolve("Sensor %d"), index)
    }
}

#endif
