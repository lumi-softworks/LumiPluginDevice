import Foundation
import Testing
@testable import PluginDevice

/// 历史图表的 X 坐标按时间戳映射，而不是按数组下标等距排列。
@Suite("DeviceHistoryChartGeometry")
struct DeviceHistoryChartGeometryTests {

    @Test("X 坐标按时间戳比例映射")
    func xMapsTimestampsProportionally() {
        let x0 = DeviceHistoryChartGeometry.x(for: 0, start: 0, end: 7200, width: 200)
        let x1 = DeviceHistoryChartGeometry.x(for: 3600, start: 0, end: 7200, width: 200)
        let x2 = DeviceHistoryChartGeometry.x(for: 7200, start: 0, end: 7200, width: 200)

        #expect(x0 == 0)
        #expect(abs(x1 - 100) < 0.001)
        #expect(x2 == 200)
    }

    @Test("长时间空洞占据真实水平距离")
    func longGapKeepsProportionalWidth() {
        // 0s 与 60s 相邻，之后直接跳到 3660s：等距下标会把 60s 画在中间。
        let shortGap = DeviceHistoryChartGeometry.x(for: 60, start: 0, end: 3660, width: 100)
        #expect(abs(shortGap - 1.639) < 0.01)
    }

    @Test("超出时间范围的值被钳制在边界")
    func xClampsOutOfRangeTimestamps() {
        #expect(DeviceHistoryChartGeometry.x(for: -10, start: 0, end: 100, width: 50) == 0)
        #expect(DeviceHistoryChartGeometry.x(for: 200, start: 0, end: 100, width: 50) == 50)
        #expect(DeviceHistoryChartGeometry.x(for: 10, start: 10, end: 10, width: 50) == 0)
    }

    @Test("悬浮选点按时间轴就近命中")
    func hoverSelectsNearestTimestamp() {
        let timestamps: [TimeInterval] = [0, 60, 3660]
        // 60s 对应 x≈1.639；按下标等距会命中第 0 个点。
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 1.639, timestamps: timestamps, width: 100) == 1)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 50, timestamps: timestamps, width: 100) == 1)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 99, timestamps: timestamps, width: 100) == 2)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 0, timestamps: timestamps, width: 100) == 0)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 10, timestamps: [], width: 100) == nil)
    }

    @Test("单点与零跨度时间轴直接命中第一个点")
    func singlePointAndZeroSpanReturnFirstIndex() {
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 50, timestamps: [100], width: 100) == 0)
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 50, timestamps: [100, 100, 100], width: 100) == 0)
        #expect(
            DeviceHistoryChartGeometry.nearestSampleIndex(
                to: 50, samples: [TestSample(timestamp: 100)], width: 100
            ) == 0
        )
    }

    @Test("距离相同的平局取更小下标")
    func tieBreaksToLowerIndex() {
        // 两点 0s 与 200s 的中点 x=50：两个候选距离相等，线性扫描首个最小值即下标 0。
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 50, timestamps: [0, 200], width: 100) == 0)
        // 三点 0/200/400 全宽 400，x=25 映射到目标 100：下标 0 与 1 距离相等，取 0。
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 25, timestamps: [0, 200, 400], width: 100) == 0)
        // x=75 映射到目标 300：下标 1 与 2 距离相等，取 1。
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 75, timestamps: [0, 200, 400], width: 100) == 1)
    }

    @Test("目标落在重复时间戳上时命中首个重复点")
    func duplicateTimestampsHitFirstOccurrence() {
        // x=30 恰好映射到时间戳 60（重复三次）：三者距离都为 0，取首个。
        let timestamps: [TimeInterval] = [0, 60, 60, 60, 200]
        #expect(DeviceHistoryChartGeometry.nearestIndex(to: 30, timestamps: timestamps, width: 100) == 1)
    }

    @Test("二分查找与线性扫描基准在全宽度上等价")
    func binarySearchMatchesLinearReference() {
        // 固定种子的伪随机升序时间轴（含采样空洞），覆盖整条横轴比对。
        var generator = SeededGenerator(seed: 0x1206)
        var timestamps: [TimeInterval] = [0]
        while timestamps.count < 400 {
            timestamps.append(timestamps.last! + Double.random(in: 1...600, using: &generator))
        }
        let samples = timestamps.map(TestSample.init(timestamp:))
        let width: CGFloat = 1000
        let span = timestamps.last! - timestamps.first!

        func linearReference(_ x: CGFloat) -> Int {
            let target = timestamps[0] + Double(x / width) * span
            return timestamps.indices.min {
                abs(timestamps[$0] - target) < abs(timestamps[$1] - target)
            }!
        }

        var sampleX: [CGFloat] = stride(from: 0 as CGFloat, through: width, by: 0.5).map { $0 }
        // 再叠加一批伪随机横坐标，覆盖越界钳制与边界附近取值。
        for _ in 0..<500 {
            sampleX.append(CGFloat.random(in: -50...(width + 50), using: &generator))
        }

        for x in sampleX {
            let expected = linearReference(x)
            #expect(
                DeviceHistoryChartGeometry.nearestIndex(to: x, timestamps: timestamps, width: width) == expected,
                "x=\(x) 二分结果与线性基准不一致"
            )
            #expect(
                DeviceHistoryChartGeometry.nearestSampleIndex(to: x, samples: samples, width: width) == expected,
                "x=\(x) 样本序列版与线性基准不一致"
            )
        }
    }
}

/// 悬浮选点测试用的最小采样点。
private struct TestSample: DeviceHistorySample {
    let timestamp: TimeInterval
}

/// 固定种子伪随机数生成器，保证等价性测试可复现。
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
