/// 传感器行标签；`resolve` 便于测试注入，默认走插件本地化资源。
enum ThermalSensorLabel {
    static func text(
        index: Int,
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        String(format: resolve("Sensor %d"), index)
    }
}
