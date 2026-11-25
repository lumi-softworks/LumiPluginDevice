#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import SwiftUI
import LumiUI

struct MemoryHistoryDetailView: View {
    @ObservedObject private var viewModel: DeviceHistoryViewModel<MemoryDataPoint>
    @ObservedObject private var processViewModel: MemoryManagerViewModel
    @State private var selectedRange: MemoryTimeRange = .hour1

    init(
        viewModel: DeviceHistoryViewModel<MemoryDataPoint>,
        processViewModel: MemoryManagerViewModel
    ) {
        self.viewModel = viewModel
        self.processViewModel = processViewModel
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(pluginLocalization.string("Memory Usage Trend"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Picker(pluginLocalization.string("Time Range"), selection: $selectedRange) {
                    ForEach(MemoryTimeRange.allCases) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.mini)
                .frame(width: 160)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            VStack(spacing: 0) {
                MemoryHistoryGraphView(
                    dataPoints: viewModel.data(for: selectedRange),
                    timeRange: selectedRange
                )
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 180)

            // 全部进程：主弹窗只展示前 5 条，这里给出完整列表。
            HStack {
                Text(pluginLocalization.string("All Processes"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(processViewModel.topProcesses.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            VStack(spacing: 0) {
                if processViewModel.topProcesses.isEmpty {
                    Text(pluginLocalization.string("Collecting..."))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        // 懒加载容器：进程榜单每秒都在变，非懒加载会把
                        // 视口外的每一行都在 1Hz 更新里重新物化（#1306）。
                        LazyVStack(spacing: 2) {
                            ForEach(processViewModel.topProcesses) { metric in
                                ProcessMetricRow(
                                    process: metric,
                                    metric: .memory,
                                    maxMemoryUsage: maxMemoryUsage
                                )
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .background(Color.secondary.opacity(0.06))
            .frame(height: 160)
            .padding(.bottom, 12)
        }
    }

    /// 内存进度条以榜首进程为满格，方便比较相对占用。
    private var maxMemoryUsage: Int64 {
        processViewModel.topProcesses.map(\.memoryUsage).max() ?? 0
    }
}

#endif
