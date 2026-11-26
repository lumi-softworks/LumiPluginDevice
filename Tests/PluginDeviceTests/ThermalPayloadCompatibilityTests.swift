import Foundation
import Testing
@testable import PluginDevice

/// 温度载荷的跨版本兼容。
///
/// 历史消息有两种旧格式：只含热压力 `state` 的版本，以及只含传感器
/// `readings` / `peakCelsius` 的版本。解码时都必须成功，否则旧会话里的
/// 设备卡片会降级成纯文本。
@Suite("DeviceThermalStatus 兼容解码")
struct ThermalPayloadCompatibilityTests {

    @Test("旧温度载荷（无 state）解码为 nominal 并保留读数")
    func decodesLegacySensorPayload() throws {
        let json = """
        {"readings":[{"index":3,"kind":"die","celsius":65.5}],"peakCelsius":65.5}
        """
        let status = try JSONDecoder().decode(DeviceThermalStatus.self, from: Data(json.utf8))

        #expect(status.state == .nominal)
        #expect(status.readings == [DeviceThermalReading(index: 3, kind: "die", celsius: 65.5)])
        #expect(status.peakCelsius == 65.5)
    }

    @Test("旧热压力载荷（无读数）解码为空读数")
    func decodesPressureOnlyPayload() throws {
        let status = try JSONDecoder().decode(
            DeviceThermalStatus.self,
            from: Data(#"{"state":"fair"}"#.utf8)
        )

        #expect(status.state == .fair)
        #expect(status.readings.isEmpty)
        #expect(status.peakCelsius == nil)
    }

    @Test("新载荷编码后保留全部字段并可往返")
    func roundTripsDualPayload() throws {
        let original = DeviceThermalStatus(
            state: .serious,
            readings: [DeviceThermalReading(index: 17, kind: "die", celsius: 88.2)],
            peakCelsius: 88.2
        )

        let decoded = try JSONDecoder().decode(
            DeviceThermalStatus.self,
            from: JSONEncoder().encode(original)
        )

        #expect(decoded == original)
    }
}