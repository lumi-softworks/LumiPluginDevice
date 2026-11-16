#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import AppKit
import Combine
import Foundation

/// Observes menu-bar appearance broadcasts and refreshes the rendered snapshot.
@MainActor
final class MenuBarAppearanceObserver {
    private var cancellable: AnyCancellable?

    init(onChange: @escaping (NSStatusBarButton?) -> Void) {
        cancellable = NotificationCenter.default.publisher(for: .lumiMenuBarAppearanceDidChange)
            .receive(on: RunLoop.main)
            .sink { notification in
                onChange(notification.object as? NSStatusBarButton)
            }
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

#endif
