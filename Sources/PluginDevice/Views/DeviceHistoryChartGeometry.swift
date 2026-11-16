#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

/// Device 历史图表共用的「时间戳 → 绘制坐标」映射。
///
/// 采样间隔并不均匀（睡眠、应用未运行都会留下空洞），因此 X 坐标必须按
/// 时间戳比例计算，而不能用数组下标等距排列。
enum DeviceHistoryChartGeometry {
    /// 把时间戳映射到 `0...width`，超出当前显示范围的值会被钳制。
    static func x(
        for timestamp: TimeInterval,
        start: TimeInterval,
        end: TimeInterval,
        width: CGFloat
    ) -> CGFloat {
        guard width > 0, start.isFinite, end.isFinite, timestamp.isFinite, end > start else {
            return 0
        }
        let ratio = (timestamp - start) / (end - start)
        return CGFloat(min(1, max(0, ratio))) * width
    }

    /// 找到横坐标 `x` 在时间轴上最近的采样点下标。
    ///
    /// 时间戳需按升序排列；空数组返回 nil，时间跨度为零时返回第一个点。
    static func nearestIndex(
        to x: CGFloat,
        timestamps: [TimeInterval],
        width: CGFloat
    ) -> Int? {
        guard let start = timestamps.first, let end = timestamps.last else { return nil }
        guard width > 0, end > start else { return 0 }

        let clampedX = min(max(x, 0), width)
        let target = start + Double(clampedX / width) * (end - start)
        return timestamps.indices.min {
            abs(timestamps[$0] - target) < abs(timestamps[$1] - target)
        }
    }
}

#endif
