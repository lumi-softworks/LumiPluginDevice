// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiPluginDevice",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginDevice",
            targets: ["PluginDevice"]
        ),
        // 可选：通过 IOHID 读取精确温度。App Store 宿主不要依赖此产品。
        .library(
            name: "PluginDeviceThermalSensors",
            targets: ["PluginDeviceThermalSensors"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginDevice",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginDevice",
            exclude: [
                "Models/README.md",
                "Services/README.md",
                "ViewModels/README.md",
                "Views/README.md",
                "Views/MenuBar/README.md",
                "Support/README.md",
            ],
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        // 可选温度模块：唯一引用 IOHID 私有符号的 Swift target。
        // 只有明确依赖本产品的宿主才会链接这些符号。
        .target(
            name: "PluginDeviceThermalSensors",
            dependencies: [
                "PluginDevice",
                "PluginDeviceThermalBridge",
            ],
            path: "Sources/PluginDeviceThermalSensors"
        ),
        // 温度采集桥接层：纯 ObjC，封装 IOKit 私有 HID API。
        // SwiftPM 单 target 不支持混编，故拆为独立 target。
        .target(
            name: "PluginDeviceThermalBridge",
            path: "Sources/PluginDeviceThermalBridge"
        ),
        .testTarget(
            name: "PluginDeviceTests",
            dependencies: [
                "PluginDevice",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderMenuBar", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
            ]
        ),
        .testTarget(
            name: "PluginDeviceThermalSensorsTests",
            dependencies: [
                "PluginDeviceThermalSensors",
            ]
        ),
    ]
)
