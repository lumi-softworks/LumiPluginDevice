import LumiUI
import SwiftUI

struct TrendPoint: Equatable {
    let timestamp: TimeInterval
    let value: Double
}

struct TrendSeries: Identifiable {
    let id: String
    let name: String
    let color: Color
    let points: [TrendPoint]
}

enum TrendValueFormat {
    case percent
    case rate
    case celsius

    func text(_ value: Double) -> String {
        switch self {
        case .percent:
            return String(format: "%.0f%%", value)
        case .rate:
            return TrendScale.rateText(value)
        case .celsius:
            return String(format: "%.0f°C", value)
        }
    }

    func axisText(_ value: Double) -> String {
        value <= 0 ? "0" : text(value)
    }
}

/// 多序列趋势图：图例在卡头，轴刻度 10pt，悬停给出逐序列数值。
///
/// 时间窗固定为最近 60 秒；X 坐标按时间戳比例映射，睡眠或暂停留下的空洞不会被压缩。
struct TrendChartView: View {
    @LumiTheme private var theme

    let series: [TrendSeries]
    let format: TrendValueFormat
    var fixedMax: Double?
    var chartHeight: CGFloat = 128

    @State private var hover: HoverState?

    private struct HoverState: Equatable {
        let x: CGFloat
        let time: TimeInterval
    }

    private struct HoverValue: Identifiable {
        let id: String
        let name: String
        let color: Color
        let value: Double
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                yAxis
                    .frame(width: 50, height: chartHeight)

                GeometryReader { geometry in
                    plot(size: geometry.size)
                }
                .frame(height: chartHeight)
            }

            xAxis
        }
    }

    // MARK: - Axes

    private var yAxis: some View {
        VStack(alignment: .trailing, spacing: 0) {
            axisLabel(format.axisText(maxValue))
            Spacer(minLength: 0)
            axisLabel(format.axisText(maxValue / 2))
            Spacer(minLength: 0)
            axisLabel(format.axisText(0))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var xAxis: some View {
        HStack(spacing: 0) {
            axisLabel(pluginLocalization.string("60s ago"))
            Spacer(minLength: 8)
            axisLabel(pluginLocalization.string("Now"))
        }
        .padding(.leading, 56)
    }

    private func axisLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(theme.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    // MARK: - Plot

    private func plot(size: CGSize) -> some View {
        let window = window
        let maxValue = maxValue

        return ZStack(alignment: .topLeading) {
            gridLines(size: size)

            ForEach(Array(series.enumerated()), id: \.element.id) { index, item in
                let points = plotPoints(
                    item.points,
                    window: window,
                    size: size,
                    maxValue: maxValue
                )

                if points.count >= 2 {
                    if index == 0 {
                        areaPath(points, height: size.height)
                            .fill(
                                LinearGradient(
                                    colors: [item.color.opacity(0.14), item.color.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    linePath(points)
                        .stroke(
                            item.color,
                            style: StrokeStyle(
                                lineWidth: index == 0 ? 1.6 : 1.3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                } else if let only = points.first {
                    Circle()
                        .fill(item.color)
                        .frame(width: 4, height: 4)
                        .position(only)
                }
            }

            if allSeriesEmpty {
                Text(pluginLocalization.string("Collecting..."))
                    .font(.appMicro)
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: size.width, height: size.height)
            }

            if let hover, !allSeriesEmpty {
                hoverOverlay(size: size, window: window, maxValue: maxValue, hover: hover)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                guard size.width > 0 else { return }
                let clampedX = min(max(location.x, 0), size.width)
                let time = window.start
                    + Double(clampedX / size.width) * (window.end - window.start)
                hover = HoverState(x: clampedX, time: time)
            case .ended:
                hover = nil
            }
        }
    }

    private func gridLines(size: CGSize) -> some View {
        Path { path in
            for fraction in [0.0, 0.5, 1.0] {
                let y = size.height * fraction
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(theme.divider, lineWidth: 1)
    }

    // MARK: - Hover

    @ViewBuilder
    private func hoverOverlay(
        size: CGSize,
        window: (start: TimeInterval, end: TimeInterval),
        maxValue: Double,
        hover: HoverState
    ) -> some View {
        let readings = hoverValues(at: hover.time)
        let tooltipWidth: CGFloat = 132

        ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: CGPoint(x: hover.x, y: 0))
                path.addLine(to: CGPoint(x: hover.x, y: size.height))
            }
            .stroke(
                theme.textTertiary.opacity(0.5),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )

            ForEach(readings) { reading in
                Circle()
                    .fill(reading.color)
                    .frame(width: 5.5, height: 5.5)
                    .position(
                        x: hover.x,
                        y: yPosition(reading.value, maxValue: maxValue, height: size.height)
                    )
            }

            tooltip(readings: readings, time: hover.time, windowEnd: window.end)
                .offset(
                    x: min(max(hover.x - tooltipWidth / 2, 0), max(0, size.width - tooltipWidth)),
                    y: 4
                )
        }
    }

    private func hoverValues(at time: TimeInterval) -> [HoverValue] {
        series.map { item in
            let nearest = item.points.min {
                abs($0.timestamp - time) < abs($1.timestamp - time)
            }
            return HoverValue(
                id: item.id,
                name: item.name,
                color: item.color,
                value: nearest?.value ?? 0
            )
        }
    }

    private func tooltip(
        readings: [HoverValue],
        time: TimeInterval,
        windowEnd: TimeInterval
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(timeText(time, windowEnd: windowEnd))
                .font(.appMicro)
                .foregroundStyle(theme.textTertiary)

            ForEach(readings) { reading in
                HStack(spacing: 5) {
                    Circle()
                        .fill(reading.color)
                        .frame(width: 5, height: 5)

                    Text(reading.name)
                        .font(.appMicro)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(format.text(reading.value))
                        .font(.appMonoMicro)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }
            }
        }
        .padding(7)
        .frame(width: 132)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.divider, lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private func timeText(_ time: TimeInterval, windowEnd: TimeInterval) -> String {
        let seconds = Int((windowEnd - time).rounded())
        if seconds <= 0 {
            return pluginLocalization.string("Now")
        }
        return "\(seconds)s"
    }

    // MARK: - Geometry

    private var window: (start: TimeInterval, end: TimeInterval) {
        let now = Date().timeIntervalSince1970
        let last = series.compactMap { $0.points.last?.timestamp }.max() ?? now
        let end = max(now, last)
        return (end - 60, end)
    }

    private var maxValue: Double {
        if let fixedMax, fixedMax > 0 {
            return fixedMax
        }

        let dataMax = series
            .flatMap(\.points)
            .map(\.value)
            .filter { $0.isFinite }
            .max() ?? 0

        switch format {
        case .percent: return 100
        case .rate: return TrendScale.niceRateMax(dataMax)
        case .celsius: return TrendScale.niceCelsiusMax(dataMax)
        }
    }

    private var allSeriesEmpty: Bool {
        series.allSatisfy { $0.points.isEmpty }
    }

    private func plotPoints(
        _ points: [TrendPoint],
        window: (start: TimeInterval, end: TimeInterval),
        size: CGSize,
        maxValue: Double
    ) -> [CGPoint] {
        guard size.width > 0, size.height > 0, maxValue > 0 else { return [] }

        return points.compactMap { point in
            guard point.timestamp >= window.start,
                  point.timestamp <= window.end,
                  point.value.isFinite
            else {
                return nil
            }

            let x = DeviceHistoryChartGeometry.x(
                for: point.timestamp,
                start: window.start,
                end: window.end,
                width: size.width
            )
            let ratio = min(max(point.value / maxValue, 0), 1)
            return CGPoint(x: x, y: size.height * (1 - CGFloat(ratio)))
        }
    }

    private func yPosition(_ value: Double, maxValue: Double, height: CGFloat) -> CGFloat {
        guard maxValue > 0, value.isFinite else { return height }
        let ratio = min(max(value / maxValue, 0), 1)
        return height * (1 - CGFloat(ratio))
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func areaPath(_ points: [CGPoint], height: CGFloat) -> Path {
        var path = linePath(points)
        path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: height))
        path.addLine(to: CGPoint(x: points.first?.x ?? 0, y: height))
        path.closeSubpath()
        return path
    }
}
