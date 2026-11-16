#if os(macOS)
// 设备信息插件是 macOS 专属能力（AppKit / IOKit / 进程与硬件监控）。
// iOS 目标只需要本模块可编译、不参与插件装配，因此整模块在 iOS 上为空。
import AppKit
import SwiftUI

/// 菜单栏 CPU 柱状图图片生成器
struct CPUMenuBarChartRenderer {
    
    // MARK: - Constants
    
    private static let barWidth: CGFloat = 4
    private static let horizontalSpacing: CGFloat = 1
    private static let minimumBarHeight: CGFloat = 1
    private static let cornerRadius: CGFloat = 0.5
    private static let imageHeight: CGFloat = 14
    
    // MARK: - Public Methods
    
    static func makeImage(from usage: [Double]) -> NSImage {
        let barCount = max(usage.count, 1)
        let totalSpacing = horizontalSpacing * CGFloat(max(0, barCount - 1))
        let totalWidth = CGFloat(barCount) * barWidth + totalSpacing
        let imageSize = NSSize(width: totalWidth, height: imageHeight)
        
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        
        let values = normalizedValues(from: usage)
        let chartHeight = imageSize.height - 1
        
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * (barWidth + horizontalSpacing)
            let height = max(minimumBarHeight, chartHeight * value)
            let rect = NSRect(
                x: x,
                y: 0,
                width: barWidth,
                height: min(chartHeight, height)
            )
            
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.labelColor.setFill()
            path.fill()
        }
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    // MARK: - Private Methods
    
    private static func normalizedValues(from usage: [Double]) -> [CGFloat] {
        usage.map { CGFloat(min(max($0, 0), 100) / 100) }
    }
}

#endif
