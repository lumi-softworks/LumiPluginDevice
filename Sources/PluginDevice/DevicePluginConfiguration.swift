#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

/// 设备信息插件的宿主品牌配置。
///
/// 共享远程包不在代码里写死宿主品牌：Lumi / Wakey 等宿主在装配时注入自己的
/// 插件 id 与日志子系统。插件 id 同时决定设置项、活动栏入口、菜单栏贡献与
/// 插件数据目录，宿主一旦确定就不应再改，否则会丢失用户已保存的启用状态。
public struct DevicePluginConfiguration: Sendable {
    /// Lumi 品牌的默认插件标识。
    public static let defaultPluginID = "com.coffic.lumi.plugin.device-info"

    /// Lumi 品牌的默认日志子系统。
    public static let defaultLoggerSubsystem = "com.coffic.lumi.plugin.device-info"

    /// 插件唯一标识。
    public let pluginID: String

    /// 日志子系统。
    public let loggerSubsystem: String

    public init(
        pluginID: String = DevicePluginConfiguration.defaultPluginID,
        loggerSubsystem: String = DevicePluginConfiguration.defaultLoggerSubsystem
    ) {
        self.pluginID = pluginID
        self.loggerSubsystem = loggerSubsystem
    }

    /// Lumi 品牌默认配置。
    public static let lumi = DevicePluginConfiguration()
}

#endif
