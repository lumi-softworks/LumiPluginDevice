import CoreGraphics
import Testing
@testable import PluginDevice

@Suite("DashboardLayout")
struct DashboardLayoutTests {
    @Test(
        "英雄区列数：<720 单列、720–1080 双列、≥1080 四列",
        arguments: [
            (320.0, 1),
            (719.0, 1),
            (720.0, 2),
            (1079.0, 2),
            (1080.0, 4),
            (1240.0, 4),
        ]
    )
    func heroColumns(width: CGFloat, expected: Int) {
        #expect(DashboardLayout.heroColumns(for: width) == expected)
    }

    @Test(
        "趋势卡列数：<760 单列、否则双列",
        arguments: [
            (600.0, 1),
            (759.0, 1),
            (760.0, 2),
        ]
    )
    func trendColumns(width: CGFloat, expected: Int) {
        #expect(DashboardLayout.trendColumns(for: width) == expected)
    }

    @Test("底部在 <900 时纵向堆叠")
    func bottomStackBreakpoint() {
        #expect(DashboardLayout.stacksBottom(for: 899) == true)
        #expect(DashboardLayout.stacksBottom(for: 900) == false)
    }
}
