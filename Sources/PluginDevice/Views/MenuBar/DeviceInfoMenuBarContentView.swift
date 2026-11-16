#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import SwiftUI

// MARK: - Local Notification Names

extension Notification.Name {
    static let lumiMenuBarAppearanceDidChange = Notification.Name("lumiMenuBarAppearanceDidChange")
}

/// 菜单栏内容视图（CPU 每核瞬时柱状图 + 内存单柱）
public struct DeviceInfoMenuBarContentView: View {

    // MARK: - Properties

    // 共享 ViewModel 保证 CPU/内存指标持续更新。
    @ObservedObject private var viewModel: DeviceInfoMenuBarContentViewModel

    init(viewModel: DeviceInfoMenuBarContentViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 4) {
            // CPU 柱状图
            Image(nsImage: viewModel.snapshot.cpuImage)
                .interpolation(.none)
                .help(viewModel.snapshot.cpuHelpText)

            // 内存柱状图
            Image(nsImage: viewModel.snapshot.memoryImage)
                .interpolation(.none)
                .help(viewModel.snapshot.memoryHelpText)
        }
    }
}

#endif
