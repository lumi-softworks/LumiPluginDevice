import KernelCore
import LumiLoggingKit
import os
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderMenuBar
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import SwiftUI

/// 设备信息插件。
///
/// 共享远程包：指标采集、详情页与菜单栏 popover 是宿主无关的核心能力；
/// 聊天卡片等宿主专属贡献通过 ``DeviceChatContributing`` 注入。
@MainActor
public final class DevicePlugin: SuperPlugin, SuperLog {
    /// 日志子系统跟随宿主注入的配置，便于在系统日志中区分品牌。
    nonisolated let logger: Logger

    /// 宿主品牌配置。
    public let configuration: DevicePluginConfiguration

    public let id: String
    public let order: Int
    public let metadata: PluginMetadata

    private var viewModels: DevicePluginViewModels?
    private var metricsObserver: DeviceMetricsObserver?

    /// 设备状态采集器。宿主注入的对话贡献也复用它。
    private let collector = DeviceStatusCollector()

    /// 宿主注入的对话扩展；没有聊天的宿主保持 nil。
    private let chat: (any DeviceChatContributing)?

    /// 入口标题的本地化解析；测试可注入替身断言注册链不再写死字面量。
    private let localize: (String) -> String

    /// - Parameters:
    ///   - configuration: 宿主品牌配置。
    ///   - order: 插件启动顺序（数值越小越先启动）。
    ///   - policy: 启用策略。
    ///   - chat: 对话贡献实现；没有聊天能力的宿主传 nil。
    public init(
        configuration: DevicePluginConfiguration = .lumi,
        order: Int = 6,
        policy: PluginEnablePolicy = .disabledByDefault,
        chat: (any DeviceChatContributing)? = nil
    ) {
        self.configuration = configuration
        self.id = configuration.pluginID
        self.order = order
        self.metadata = PluginMetadata(
            id: configuration.pluginID,
            name: pluginLocalization.string("Device"),
            description: pluginLocalization.string("View device information and hardware status."),
            category: .system,
            stage: .stable,
            policy: policy
        )
        self.chat = chat
        self.localize = { pluginLocalization.string($0) }
        self.logger = Logger(subsystem: configuration.loggerSubsystem, category: "Device")
    }

    init(
        configuration: DevicePluginConfiguration = .lumi,
        order: Int = 6,
        policy: PluginEnablePolicy = .disabledByDefault,
        chat: (any DeviceChatContributing)? = nil,
        localize: @escaping (String) -> String
    ) {
        self.configuration = configuration
        self.id = configuration.pluginID
        self.order = order
        self.metadata = PluginMetadata(
            id: configuration.pluginID,
            name: pluginLocalization.string("Device"),
            description: pluginLocalization.string("View device information and hardware status."),
            category: .system,
            stage: .stable,
            policy: policy
        )
        self.chat = chat
        self.localize = localize
        self.logger = Logger(subsystem: configuration.loggerSubsystem, category: "Device")
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: localize("Device Info")) { DeviceInfoAboutView() })
            docs.addManual(DocsEntry(id: id, name: localize("Device Info")) { DeviceInfoManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let viewModels = DevicePluginViewModels()
        self.viewModels = viewModels
        metricsObserver?.cancel()
        metricsObserver = DeviceMetricsObserver(viewModels: viewModels)

        // 0. 配置历史服务的存储目录
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let pluginStorageDir = storage.pluginDataDirectory(for: id)
            MemoryHistoryService.configure(storageDirectory: pluginStorageDir)
            ThermalHistoryService.configure(storageDirectory: pluginStorageDir)
        }

        // 1. 注册 ActivityBar 入口；入口被激活时由插件切换自己的主内容，
        //    并隐藏侧边栏 Rail（本插件不贡献 Rail 内容，直接全屏展示主视图）。
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: localize("Device Info"),
                    systemImage: "gauge.with.dots.needle.50percent",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .system])
                        // 本插件被激活：展示主内容并隐藏侧边栏 Rail（全屏展示）。
                        contentView?.setContentView(AnyView(DeviceInfoView(viewModels: viewModels)))
                        rootView?.setRailView(nil)
                        rootView?.setContentHeaderViewHidden(true)
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        // 切换到其它入口时恢复 Rail 可见性。
                        rootView?.setRailView(railView?.makeRailView())
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        rootView?.setContentHeaderViewHidden(false)
                    }
                },
            ])
        } else {
            // 无 ActivityBar 的精简宿主仍可直接展示插件主内容。
            contentView?.setContentView(AnyView(DeviceInfoView(viewModels: viewModels)))
        }

        try contributeMenuBar(to: kernel, viewModels: viewModels)
        registerChatContributions(kernel: kernel)
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        guard let viewModels else { return }
        try contributeMenuBar(to: kernel, viewModels: viewModels)
        registerChatContributions(kernel: kernel)
    }

    /// 运行时禁用：撤回对话侧贡献。
    ///
    /// - Important: 内核在运行时禁用插件时只撤回它**显式登记**的贡献
    ///   （`trackContribution`），不会替插件清理 Provider 侧的写入。
    ///   因此对话侧的贡献必须由宿主实现自己在 `unregister` 里撤回。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        chat?.unregister(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        chat?.unregister(kernel: kernel)
        metricsObserver?.cancel()
        metricsObserver = nil
        viewModels = nil
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        // 恢复 Rail 可见性（本插件激活时可能已将其隐藏）。
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        rootView?.setRailView(railView?.makeRailView())
        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
        rootView?.setContentHeaderViewHidden(false)
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    private func registerChatContributions(kernel: KernelCoreContainer) {
        chat?.register(kernel: kernel, pluginID: id, collector: collector)
    }

    private func contributeMenuBar(
        to kernel: KernelCoreContainer,
        viewModels: DevicePluginViewModels
    ) throws {
        guard let menuBar = kernel.resolveProvider((any MenuBarProviding).self) else { return }
        let ownerID = id
        try kernel.trackContribution {
            menuBar.removeItems(ownedBy: ownerID)
        }
        menuBar.addContent(MenuBarContribution(
            id: "\(id).metrics",
            title: localize("Device Info"),
            order: order,
            ownerPluginID: id
        ) {
            DeviceInfoMenuBarContentView(viewModel: viewModels.menuBar)
        })
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).cpu",
            title: "CPU",
            order: order,
            ownerPluginID: id
        ) {
            DeviceInfoMenuBarPopupView(
                viewModel: viewModels.cpu,
                thermalViewModel: viewModels.thermal,
                historyViewModel: viewModels.cpuHistory,
                thermalHistoryViewModel: viewModels.thermalHistory
            )
        })
        menuBar.addPopup(MenuBarContribution(
            id: "\(id).memory",
            title: localize("Memory"),
            order: order,
            ownerPluginID: id
        ) {
            MemoryMenuBarPopupView(viewModel: viewModels.memory, historyViewModel: viewModels.memoryHistory)
        })
    }
}
