import KernelCore

/// 插件留给宿主的对话扩展点。
///
/// 设备指标的采集与菜单栏展示属于共享核心；把指标卡片投递到聊天消息区则
/// 依赖宿主自己的消息与渲染契约（Lumi 的 `ProviderMessage` /
/// `ProviderMessageRendering` 只存在于 Lumi 工程内）。因此这里把依赖方向
/// 倒过来：插件只声明「需要注册/撤回对话贡献」，具体实现由宿主注入。
///
/// - Lumi：注入 `DeviceStatusChatContribution`，注册 `device_status` 工具与
///   卡片渲染器。
/// - Wakey 等没有聊天的宿主：不注入，相关逻辑完全不参与编译与运行。
@MainActor
public protocol DeviceChatContributing: AnyObject {
    /// 插件启用时登记对话侧贡献（工具、渲染器、消息桥）。
    ///
    /// 实现应保证幂等：内核在「曾经启动过再启用」时只会调用 `onEnable`。
    func register(
        kernel: KernelCoreContainer,
        pluginID: String,
        collector: DeviceStatusCollector
    )

    /// 插件禁用或关闭时撤回对话侧贡献。
    func unregister(kernel: KernelCoreContainer)
}
