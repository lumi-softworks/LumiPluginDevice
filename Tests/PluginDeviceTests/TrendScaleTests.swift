import Foundation
import Testing
@testable import PluginDevice

@Suite("TrendScale")
struct TrendScaleTests {
    private static let kb: Double = 1024

    @Test(
        "速率量程吸附到 1/2/5/10… 档位",
        arguments: [
            (0.0, 1024.0),
            (-10.0, 1024.0),
            (512.0, 1024.0),
            (3072.0, 5120.0),
            (1_258_291.2, 2_097_152.0),
            (9_856_614.4, 10_485_760.0),
            (10_485_760.0, 10_485_760.0),
            (12_582_912.0, 20_971_520.0),
        ]
    )
    func niceRateMax(raw: Double, expected: Double) {
        #expect(TrendScale.niceRateMax(raw) == expected)
    }

    @Test("非法速率输入回退到 1 KB/s")
    func niceRateMaxRejectsNonFinite() {
        #expect(TrendScale.niceRateMax(.nan) == TrendScale.minimumRate)
        #expect(TrendScale.niceRateMax(.infinity) == 1 * Self.kb)
    }

    @Test(
        "温度量程以 60℃ 为下限，按 10℃ 取整",
        arguments: [
            (0.0, 60.0),
            (55.0, 60.0),
            (61.0, 70.0),
            (99.0, 100.0),
            (100.0, 100.0),
        ]
    )
    func niceCelsiusMax(raw: Double, expected: Double) {
        #expect(TrendScale.niceCelsiusMax(raw) == expected)
    }

    @Test("速率文本带 /s 后缀")
    func rateTextHasPerSecondSuffix() {
        #expect(TrendScale.rateText(1024).hasSuffix("/s"))
        #expect(TrendScale.rateText(0).hasSuffix("/s"))
    }
}
