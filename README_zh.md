# LumiPluginDevice

[English](README.md) | 📖 中文版

「设备信息（Device Info）」插件的共享远程包，由 Lumi、Wakey 等 CofficLab 同族应用装配。

> 插件只依赖 Provider 契约：设备指标采集、详情页与菜单栏 popover 都是宿主无关能力。
> 聊天卡片依赖宿主自己的消息契约，因此通过 `DeviceChatContributing` 注入，
> 不在本包内写死。

## 包信息

- Manifest 包名：`LumiPluginDevice`（与仓库名一致）
- Product / Target：`PluginDevice`
- 平台：macOS 14+
- Swift tools：6.0

## 提供的能力

- CPU / 内存 / GPU / 电池 / 存储 / 温度 / 进程指标采集。
- 菜单栏 CPU、内存 popover，含历史曲线。
- 宿主提供 ActivityBar 时贡献完整的「设备信息」详情页。
- 共享文档视图里的 Device Info 说明书与关于条目。
- 在插件专属目录下持久化历史数据。

## 宿主能力

所有宿主 Provider 都是可选的。只渲染菜单栏 popover 的宿主（例如 Wakey）
仍能拿到可用的 CPU / 内存 popover，只是没有详情页与聊天卡片。

| Provider | 提供时的效果 | 缺失时的效果 |
|---|---|---|
| `MenuBarProviding` | 注册指标状态项与 CPU / 内存 popover | 无菜单栏 UI |
| `ActivityBarProviding` + `ContentViewProviding` | 注册完整设备信息页 | 无完整详情页 |
| `DocsViewProviding` | 添加说明书与关于条目 | 无文档条目 |
| `StorageProviding` | 持久化 CPU / 内存 / GPU / 电池 / 可选温度历史 | 历史不落盘 |
| `DeviceChatContributing`（宿主注入） | 注册聊天工具与卡片渲染器 | 无聊天贡献 |

## 依赖与接入

```swift
dependencies: [
    .package(url: "https://github.com/lumi-softworks/LumiPluginDevice.git", from: "1.0.0")
]
```

在宿主 Factory target 中加入 product：

```swift
.product(name: "PluginDevice", package: "LumiPluginDevice")
```

并在插件装配处创建：

```swift
import PluginDevice

DevicePlugin()
```

默认插件 id 为 `com.coffic.lumi.plugin.device-info`，宿主可注入自己的品牌配置：

```swift
DevicePlugin(
    configuration: DevicePluginConfiguration(
        pluginID: "com.coffic.wakey.plugin.device-info",
        loggerSubsystem: "com.coffic.wakey.plugin.device-info"
    )
)
```

有聊天面的宿主可以挂自己的对话贡献。Lumi 用本地 `DeviceStatusChatContribution`
实现，它与 `ProviderMessage` / `ProviderMessageRendering` 放在同一工程内：

```swift
DevicePlugin(chat: DeviceStatusChatContribution())
```

## 精确温度（可选）

核心 product 不引用任何 IOHID 私有符号，始终提供
`ProcessInfo.thermalState`（nominal / fair / serious / critical），可安全提交
App Store。

不走 App Store 的宿主可以额外链接可选 product，展示逐传感器摄氏度与温度历史：

```swift
.product(name: "PluginDeviceThermalSensors", package: "LumiPluginDevice")
```

```swift
#if os(macOS)
import PluginDeviceThermalSensors
ThermalSensors.install()
#endif

DevicePlugin()
```

`ThermalSensors.install()` 必须在创建插件之前调用。App Store 宿主不得依赖
`PluginDeviceThermalSensors`：一旦链接，私有 IOHID 符号会进入最终二进制并触发审核拒绝。

## 测试

```sh
swift test
```
