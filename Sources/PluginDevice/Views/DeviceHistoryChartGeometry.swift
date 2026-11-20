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
        nearestIndex(
            to: x,
            count: timestamps.count,
            timestampAt: { timestamps[$0] },
            width: width
        )
    }

    /// 在已按时间戳升序排列的采样序列中找到横坐标 `x` 的最近样本下标。
    ///
    /// 与时间戳数组版语义一致；直接对样本二分，悬浮交互无需每次事件
    /// 重新物化整条时间戳数组（#1206）。
    static func nearestSampleIndex<T: DeviceHistorySample>(
        to x: CGFloat,
        samples: [T],
        width: CGFloat
    ) -> Int? {
        nearestIndex(
            to: x,
            count: samples.count,
            timestampAt: { samples[$0].timestamp },
            width: width
        )
    }

    /// 二分收敛到夹住目标的两点后按距离取近者；距离相同取更小下标，
    /// 与原线性扫描 `indices.min` 的平局语义保持一致。
    private static func nearestIndex(
        to x: CGFloat,
        count: Int,
        timestampAt: (Int) -> TimeInterval,
        width: CGFloat
    ) -> Int? {
        guard count > 0 else { return nil }
        let start = timestampAt(0)
        let end = timestampAt(count - 1)
        guard width > 0, end > start else { return 0 }

        let clampedX = min(max(x, 0), width)
        let target = start + Double(clampedX / width) * (end - start)

        var low = 0
        var high = count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if timestampAt(mid) < target {
                low = mid
            } else {
                high = mid
            }
        }
        return abs(timestampAt(low) - target) <= abs(timestampAt(high) - target) ? low : high
    }
}

#endif
