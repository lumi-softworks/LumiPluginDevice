#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import Foundation

/// 趋势图 Y 轴量程与格式化。
///
/// 网络 / 磁盘速率不能写死上限：空闲时 10 MB/s 的量程会把曲线压成一条直线。
/// 这里把窗口最大值归入 1 / 2 / 5 / 10 … × 1 KB 的档位，保证微小波动也可见。
enum TrendScale {
    /// 速率图的最小量程：1 KB/s。
    static let minimumRate: Double = 1024

    /// 返回不小于 `rawMax` 的「好看」量程（按 1 KB 递进的 1/2/5/10… 档位）。
    static func niceRateMax(_ rawMax: Double) -> Double {
        guard rawMax.isFinite, rawMax > 0 else { return minimumRate }
        let target = max(rawMax, minimumRate)
        let factors: [Double] = [1, 2, 5, 10, 20, 50, 100, 200, 500]

        for exponent in 0..<6 {
            let unit = pow(1024, Double(exponent))
            for factor in factors {
                let candidate = factor * unit
                if candidate >= target {
                    return candidate
                }
            }
        }
        return pow(1024, 6)
    }

    /// 温度图量程（℃）：以 60℃ 为下限，按 10℃ 向上取整。
    static func niceCelsiusMax(_ rawMax: Double) -> Double {
        guard rawMax.isFinite, rawMax > 0 else { return 60 }
        return max(60, ceil(rawMax / 10) * 10)
    }

    /// 速率文本，与网络/磁盘读数保持同一口径（二进制单位 + /s）。
    static func rateText(_ bytesPerSecond: Double) -> String {
        let value = bytesPerSecond.isFinite ? max(0, bytesPerSecond) : 0
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary) + "/s"
    }
}

#endif
