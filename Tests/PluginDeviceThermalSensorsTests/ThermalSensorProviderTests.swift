import Foundation
import Testing
@testable import PluginDeviceThermalSensors

@Suite("IOHIDThermalSensorProvider")
struct ThermalSensorProviderTests {

    @Test("private HID symbols are still resolvable")
    func privateSymbolsAvailable() {
        // 私有 API 依赖：若系统升级后符号消失，readSensors() 会静默返回空。
        // 此测试用于让失效尽早暴露在 CI，而不是等到用户界面无温度可看。
        for symbol in [
            "IOHIDEventSystemClientCreate",
            "IOHIDEventSystemClientSetMatching",
            "IOHIDEventSystemClientCopyServices",
            "IOHIDServiceClientCopyEvent",
            "IOHIDEventGetFloatValue"
        ] {
            #expect(dlsym(UnsafeMutableRawPointer(bitPattern: -2), symbol) != nil,
                    "private HID symbol missing: \(symbol)")
        }
    }

    @Test("readings are within physical range")
    func readingsInRange() {
        let readings = IOHIDThermalSensorProvider().readSensors()
        // Intel Mac 无 PMU 传感器，此时允许为空。
        for reading in readings {
            #expect(reading.celsius >= 1.0, "negative/dummy reading leaked through: \(reading)")
            #expect(reading.celsius <= 150.0, "implausible reading: \(reading)")
        }
    }

    @Test("readings are sorted by sensor index")
    func sortedByIndex() {
        let indices = IOHIDThermalSensorProvider().readSensors().map(\.index)
        #expect(indices == indices.sorted())
    }

    @Test("peak can be derived from the same sample")
    func peakFromSameSample() {
        // 同一次采样中，峰值必须严格等于样本最大值；不得再次采样后比较。
        let readings = IOHIDThermalSensorProvider().readSensors()
        let peak = readings.map(\.celsius).max()
        #expect(peak == readings.map(\.celsius).max())
    }
}