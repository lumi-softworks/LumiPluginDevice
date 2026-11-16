#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import CoreGraphics

/// 仪表盘响应式断点。
enum DashboardLayout {
    /// 英雄区列数：<720 单列，720–1080 双列，更宽四列（三个环 + 诊断）。
    static func heroColumns(for width: CGFloat) -> Int {
        if width >= 1080 { return 4 }
        if width >= 720 { return 2 }
        return 1
    }

    /// 趋势卡列数：<760 单列，否则双列。
    static func trendColumns(for width: CGFloat) -> Int {
        width >= 760 ? 2 : 1
    }

    /// 进程榜与明细是否纵向堆叠。
    static func stacksBottom(for width: CGFloat) -> Bool {
        width < 900
    }
}

#endif
