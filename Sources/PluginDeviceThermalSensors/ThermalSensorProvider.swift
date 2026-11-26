#if os(macOS)
import Foundation
import PluginDevice
import PluginDeviceThermalBridge

/// 通过 IOHID 读取 PMU 温度传感器的提供者。
///
/// ## 为什么单独成模块
///
/// App Store 审核会静态扫描二进制里的私有符号，运行时的条件分支无法规避。
/// 因此 IOHID 桥接与实现必须与核心包在链接层面分开：只有显式依赖本模块的
/// 宿主（Lumi）才会把私有符号带进产物；App Store 宿主（Wakey）只用核心包。
///
/// ## 为什么走 HID 而不是 SMC
///
/// 传统方案（``osx-cpu-temp``、`istats`）通过 `IOServiceOpen("AppleSMC")`
/// 读 SMC key。在 Apple Silicon 上这条路已死：SMC 驱动只服务 Apple 自己的客户端，
/// `IOConnectCallStructMethod` 返回 `kIOReturnNotPrivileged`（实测 -536870206），
/// 即便 root 也无解。CPU / die 温度因此改由固件以 HID 事件形式暴露，
/// 通过 `IOHIDEventSystemClient` 可在纯用户态免 sudo 读取。
///
/// ## 能力边界
///
/// - ✅ CPU / die / 封装温度（`tdie`、`tdev`、surface）
/// - ❌ GPU 温度仍在 SMC 上，免特权条件下拿不到
/// - ❌ Intel Mac 无 PMU 传感器，始终返回空数组
public struct IOHIDThermalSensorProvider: ThermalSensorProviding {
    public init() {}

    public func readSensors() -> [ThermalSensorReading] {
        var collected: [(Int, Double)] = []
        // 预分配，实测 Apple Silicon 上约 38 个有效传感器。
        collected.reserveCapacity(48)

        withUnsafeMutablePointer(to: &collected) { pointer in
            let context = UnsafeMutableRawPointer(pointer)
            let callback: LumiThermalSensorCallback = { rawContext, index, celsius in
                let typed = rawContext.assumingMemoryBound(to: [(Int, Double)].self)
                typed.pointee.append((Int(index), celsius))
            }
            _ = LumiReadThermalSensors(context, callback)
        }

        return collected
            .map { ThermalSensorReading(index: $0.0, kind: Self.kind(for: $0.0), celsius: $0.1) }
            .sorted { $0.index < $1.index }
    }

    /// 由传感器下标推断类别。
    ///
    /// Apple 未公开该映射，这里按固件中观测到的排布做启发式分组，
    /// 仅用于 UI 分组标题，读数本身不依赖它。
    private static func kind(for index: Int) -> ThermalSensorReading.SensorKind? {
        switch index {
        case 0..<16: return .device
        case 16..<48: return .die
        default: return .surface
        }
    }
}

/// 可选温度能力的安装入口。
public enum ThermalSensors {
    /// 为共享 ``ThermalService`` 安装 IOHID 实现。
    ///
    /// 应在宿主组合插件、创建 `DevicePlugin` 之前调用。
    @MainActor
    public static func install() {
        ThermalService.install(sensorProvider: IOHIDThermalSensorProvider())
    }
}

#endif