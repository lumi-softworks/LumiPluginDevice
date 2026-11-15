import SwiftUI

/// 微型趋势：只表达形状，不画轴与刻度。
///
/// 固定展示最近 60 点；不足时按实际点数绘制，不补 0。
struct SparklineView: View {
    let values: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2, size.width > 0, size.height > 0, maxValue > 0 else { return }

            let stepX = size.width / CGFloat(values.count - 1)
            var points: [CGPoint] = []
            points.reserveCapacity(values.count)

            for (index, value) in values.enumerated() {
                let safeValue = value.isFinite ? value : 0
                let ratio = min(max(safeValue / maxValue, 0), 1)
                let x = CGFloat(index) * stepX
                let y = size.height * (1 - CGFloat(ratio))
                points.append(CGPoint(x: x, y: y))
            }

            var line = Path()
            line.move(to: points[0])
            for point in points.dropFirst() {
                line.addLine(to: point)
            }

            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()

            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.16), color.opacity(0)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            )

            if let last = points.last {
                let dot = CGRect(x: last.x - 2.4, y: last.y - 2.4, width: 4.8, height: 4.8)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
