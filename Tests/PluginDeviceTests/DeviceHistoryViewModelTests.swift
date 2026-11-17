import Combine
import Foundation
import Testing
@testable import PluginDevice

/// 历史视图模型按时间范围裁剪数据的行为。
@Suite("DeviceHistoryViewModel")
@MainActor
struct DeviceHistoryViewModelTests {

    @Test("1 小时范围取高频缓冲并剔除过期样本")
    func oneHourRangeUsesHighResolutionBuffer() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.applyRecent([
            CPUDataPoint(timestamp: now - 60, usage: 10),
            CPUDataPoint(timestamp: now - 7200, usage: 20),
        ])
        viewModel.applyLongTerm([])

        let points = viewModel.data(for: CPUTimeRange.hour1)

        #expect(points.count == 1)
        #expect(points.first?.usage == 10)
    }

    @Test("4 小时范围剔除超出范围的长期样本")
    func fourHourRangeTrimsLongTermBuffer() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.applyRecent([])
        viewModel.applyLongTerm([
            CPUDataPoint(timestamp: now - 3600, usage: 30),
            CPUDataPoint(timestamp: now - 14401, usage: 40),
        ])

        let points = viewModel.data(for: CPUTimeRange.hour4)

        #expect(points.count == 1)
        #expect(points.first?.usage == 30)
    }

    @Test("24 小时与 30 天范围返回不同的数据量")
    func differentLongRangesReturnDifferentData() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.applyRecent([])
        viewModel.applyLongTerm([
            CPUDataPoint(timestamp: now - 3600, usage: 30),
            CPUDataPoint(timestamp: now - 43200, usage: 40),
            CPUDataPoint(timestamp: now - 86401, usage: 50),
        ])

        let day = viewModel.data(for: CPUTimeRange.hour24)
        let month = viewModel.data(for: CPUTimeRange.month1)

        #expect(day.count == 2)
        #expect(month.count == 3)
        #expect(day.count != month.count)
    }

    @Test("内存历史同样按范围裁剪")
    func memoryHistoryTrimsByRange() {
        let viewModel = DeviceHistoryViewModel<MemoryDataPoint>()
        let now = Date().timeIntervalSince1970

        viewModel.applyRecent([])
        viewModel.applyLongTerm([
            MemoryDataPoint(timestamp: now - 60, usagePercentage: 55, usedBytes: 100),
            MemoryDataPoint(timestamp: now - 20000, usagePercentage: 45, usedBytes: 200),
        ])

        let fourHours = viewModel.data(for: MemoryTimeRange.hour4)
        let oneDay = viewModel.data(for: MemoryTimeRange.hour24)

        #expect(fourHours.count == 1)
        #expect(fourHours.first?.usagePercentage == 55)
        #expect(oneDay.count == 2)
    }

    @Test("recent-only 更新不得重复发布长期缓冲（回归 #1209）")
    func recentOnlyUpdateDoesNotRepublishLongTermHistory() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970
        viewModel.applyLongTerm([CPUDataPoint(timestamp: now - 60, usage: 30)])

        var longTermPublications = 0
        let cancellable = viewModel.$longTermHistory.dropFirst().sink { _ in longTermPublications += 1 }

        viewModel.applyRecent([CPUDataPoint(timestamp: now - 10, usage: 10)])
        viewModel.applyRecent([CPUDataPoint(timestamp: now - 10, usage: 12)])

        #expect(longTermPublications == 0)
        cancellable.cancel()
    }

    @Test("长期缓冲更新后发布并失效长期范围缓存（回归 #1209）")
    func longTermUpdateRepublishesAndInvalidatesLongRangeCache() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970
        viewModel.applyLongTerm([CPUDataPoint(timestamp: now - 60, usage: 30)])
        #expect(viewModel.data(for: CPUTimeRange.month1).count == 1)

        var longTermPublications = 0
        let cancellable = viewModel.$longTermHistory.dropFirst().sink { _ in longTermPublications += 1 }
        viewModel.applyLongTerm([
            CPUDataPoint(timestamp: now - 60, usage: 30),
            CPUDataPoint(timestamp: now - 30, usage: 35),
        ])

        #expect(longTermPublications == 1)
        #expect(viewModel.data(for: CPUTimeRange.month1).count == 2)
        cancellable.cancel()
    }

    @Test("高频缓冲更新后失效小时范围缓存")
    func recentUpdateInvalidatesHighResolutionCache() {
        let viewModel = DeviceHistoryViewModel<CPUDataPoint>()
        let now = Date().timeIntervalSince1970
        viewModel.applyRecent([CPUDataPoint(timestamp: now - 60, usage: 10)])
        #expect(viewModel.data(for: CPUTimeRange.hour1).count == 1)

        viewModel.applyRecent([
            CPUDataPoint(timestamp: now - 60, usage: 10),
            CPUDataPoint(timestamp: now - 10, usage: 12),
        ])

        #expect(viewModel.data(for: CPUTimeRange.hour1).count == 2)
    }
}
