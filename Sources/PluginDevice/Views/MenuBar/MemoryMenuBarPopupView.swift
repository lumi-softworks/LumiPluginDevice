#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import LumiUI
import SwiftUI

public struct MemoryMenuBarPopupView: View {
    @ObservedObject private var viewModel: MemoryManagerViewModel
    private let historyViewModel: DeviceHistoryViewModel<MemoryDataPoint>

    init(viewModel: MemoryManagerViewModel, historyViewModel: DeviceHistoryViewModel<MemoryDataPoint>) {
        self.viewModel = viewModel
        self.historyViewModel = historyViewModel
    }

    public var body: some View {
        HoverableContainerView(
            detailView: MemoryHistoryDetailView(
                viewModel: historyViewModel,
                processViewModel: viewModel
            )
        ) {
            VStack(spacing: 0) {
                liveStatsView

                // Top 5 内存占用进程
                TopProcessesView(processes: viewModel.topProcessesPreview, metric: .memory)
            }
        }
    }

    private var liveStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pluginLocalization.string("Memory"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(viewModel.usedMemory) / \(viewModel.totalMemory)")
                    .font(.system(size: 12, weight: .medium))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.accentColor, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(viewModel.memoryUsagePercentage / 100.0))
                }
            }
            .frame(height: 6)
        }
        .padding(10)
    }
}

#endif
