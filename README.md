# LumiPluginDevice

📖 English | [中文版](README_zh.md)

Shared remote package for the "Device Info" plugin, assembled by CofficLab sibling apps such as Lumi and Wakey.

> The plugin depends on Provider contracts only. Device metrics, the detail page, and the menu bar popovers are host-agnostic. Chat card contributions depend on the host's own messaging contracts, so they are injected through `DeviceChatContributing` instead of being hard-wired here.

## Package

- Manifest package name: `LumiPluginDevice` (matches the repository name)
- Product / Target: `PluginDevice`
- Platform: macOS 14+
- Swift tools: 6.0

## What It Provides

- CPU, memory, GPU, battery, storage, thermal, and process metrics.
- Menu bar popovers for CPU and memory, including history charts.
- A full "Device Info" detail page contributed to the Activity Bar when the host provides one.
- Device Info manual and About entries in the shared docs view.
- Persisted history data under the plugin's own storage directory.

## Host Capabilities

Every host provider is optional. A host that only renders menu bar popups (for example Wakey) still gets working CPU and memory popovers; the detail page and chat card are simply absent.

| Provider | Effect when present | Effect when absent |
|---|---|---|
| `MenuBarProviding` | Registers the metrics status item and CPU / memory popovers | No menu bar UI |
| `ActivityBarProviding` + `ContentViewProviding` | Registers the full Device Info page | No full page |
| `DocsViewProviding` | Adds manual and About entries | No docs entries |
| `StorageProviding` | Persists CPU / memory / GPU / battery / optional temperature history | History is not persisted |
| `DeviceChatContributing` (host injected) | Registers the chat tool and card renderer | No chat contributions |

## Dependencies and Integration

```swift
dependencies: [
    .package(url: "https://github.com/lumi-softworks/LumiPluginDevice.git", from: "1.0.0")
]
```

Add the product to the host Factory target:

```swift
.product(name: "PluginDevice", package: "LumiPluginDevice")
```

And assemble it in the plugin factory:

```swift
import PluginDevice

DevicePlugin()
```

The default plugin ID is `com.coffic.lumi.plugin.device-info`. Hosts can inject their own brand configuration:

```swift
DevicePlugin(
    configuration: DevicePluginConfiguration(
        pluginID: "com.coffic.wakey.plugin.device-info",
        loggerSubsystem: "com.coffic.wakey.plugin.device-info"
    )
)
```

A host with a chat surface can attach its own chat contribution. Lumi does this with a local `DeviceStatusChatContribution` that lives next to `ProviderMessage` / `ProviderMessageRendering`:

```swift
DevicePlugin(chat: DeviceStatusChatContribution())
```

## Precise Temperature (Optional)

The core product never references private IOHID symbols. It always reports
`ProcessInfo.thermalState` (nominal / fair / serious / critical), which is safe
for App Store submission.

Hosts distributed outside the App Store can additionally link the optional
product to show per-sensor Celsius readings and temperature history:

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

`ThermalSensors.install()` must run before the plugin is created. App Store
hosts must not depend on `PluginDeviceThermalSensors`; linking it puts the
private IOHID symbols into the final binary and triggers review rejection.

## Testing

```sh
swift test
```
