import BatteryData
import SwiftUI

public enum BatteryGraphLayout {
    public static let horizontalInset: CGFloat = 15
    public static let topPadding: CGFloat = 8
    public static let titleHeight: CGFloat = 16
    public static let titleSpacing: CGFloat = 6
    public static let plotHeight: CGFloat = 90
    public static let chargingIndicatorHeight: CGFloat = 13
    public static let timeAxisHeight: CGFloat = 14
    public static let bottomPadding: CGFloat = 8

    public static var totalHeight: CGFloat {
        topPadding + titleHeight + titleSpacing + plotHeight + chargingIndicatorHeight
            + timeAxisHeight + bottomPadding
    }
}

public struct BatteryGraphView: View {
    let graph: BatteryGraph?

    public init(graph: BatteryGraph?) {
        self.graph = graph
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BatteryGraphLayout.titleSpacing) {
            Text("Last 12 hours")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(height: BatteryGraphLayout.titleHeight, alignment: .leading)
            if let graph {
                BatteryGraphCanvas(graph: graph)
                    .frame(
                        height: BatteryGraphLayout.plotHeight
                            + BatteryGraphLayout.chargingIndicatorHeight
                            + BatteryGraphLayout.timeAxisHeight
                    )
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for data…")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, BatteryGraphLayout.topPadding)
        .padding(.bottom, BatteryGraphLayout.bottomPadding)
        .padding(.horizontal, BatteryGraphLayout.horizontalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct BatteryGraphCanvas: View {
    let graph: BatteryGraph

    private enum Metrics {
        static let slotWidth: CGFloat = 4
        static let barFill: CGFloat = 0.8
        static let minBarCount = 24
        static let minBarHeight: CGFloat = 2
        static let axisLabelWidth: CGFloat = 36
        static let timeLabelWidth: CGFloat = 34
        static let timeLabelHeight: CGFloat = 12
        static let chargingLineWidth: CGFloat = 5
        static let chargingBoltGap: CGFloat = 12
        static let minimumBoltSegmentWidth: CGFloat = 28
    }

    private var barColor: Color {
        Color(nsColor: .systemGreen)
    }

    private var lowLevelColor: Color {
        Color(nsColor: .systemRed)
    }

    private var lowPowerColor: Color {
        Color(nsColor: .systemYellow)
    }

    var body: some View {
        Canvas { context, size in
            let plotRect = CGRect(
                x: 0,
                y: 0,
                width: size.width - Metrics.axisLabelWidth,
                height: size.height
                    - BatteryGraphLayout.chargingIndicatorHeight
                    - BatteryGraphLayout.timeAxisHeight
            )
            drawGrid(in: &context, plotRect: plotRect)
            drawPowerHighlights(in: &context, plotRect: plotRect)
            drawBars(in: &context, plotRect: plotRect)
            drawChargingIndicators(in: &context, plotRect: plotRect)
            drawAxisLabels(in: &context, plotRect: plotRect)
        }
    }

    private func x(for date: Date, plotRect: CGRect) -> CGFloat {
        let fraction = date.timeIntervalSince(graph.windowStart) / BatteryGraph.window
        return plotRect.minX + CGFloat(fraction) * plotRect.width
    }

    private func timeTicks() -> [Date] {
        let calendar = Calendar.current
        guard let anchor = calendar.dateInterval(of: .hour, for: graph.windowStart)?.start else {
            return []
        }
        let windowEnd = graph.windowStart.addingTimeInterval(BatteryGraph.window)
        var ticks = [Date]()
        var tick = anchor.addingTimeInterval(3 * 3600)
        while tick <= windowEnd.addingTimeInterval(-10 * 60) {
            if tick.timeIntervalSince(graph.windowStart) >= 20 * 60 {
                ticks.append(tick)
            }
            tick = calendar.date(byAdding: .hour, value: 3, to: tick) ?? tick.addingTimeInterval(3 * 3600)
        }
        return ticks
    }

    private func drawGrid(in context: inout GraphicsContext, plotRect: CGRect) {
        let lineColor = Color.primary.opacity(0.12)
        for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let y = plotRect.maxY - CGFloat(fraction) * plotRect.height
            var line = Path()
            line.move(to: CGPoint(x: plotRect.minX, y: y))
            line.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(line, with: .color(lineColor), lineWidth: 0.5)
        }
        for tick in timeTicks() {
            let tickX = x(for: tick, plotRect: plotRect)
            var line = Path()
            line.move(to: CGPoint(x: tickX, y: plotRect.minY))
            line.addLine(to: CGPoint(x: tickX, y: plotRect.maxY))
            context.stroke(line, with: .color(Color.primary.opacity(0.07)), lineWidth: 0.5)
        }
    }

    private func drawPowerHighlights(in context: inout GraphicsContext, plotRect: CGRect) {
        for segment in graph.highlightSegments {
            let startX = x(for: segment.start, plotRect: plotRect)
            let endX = x(for: segment.end, plotRect: plotRect)
            guard endX - startX >= 1 else { continue }
            let rect = CGRect(x: startX, y: plotRect.minY, width: endX - startX, height: plotRect.height)
            let color = segment.kind == .charging ? barColor : lowPowerColor
            context.fill(Path(rect), with: .color(color.opacity(0.16)))
        }
    }

    private func drawChargingIndicators(in context: inout GraphicsContext, plotRect: CGRect) {
        let centerY = plotRect.maxY + BatteryGraphLayout.chargingIndicatorHeight / 2

        for segment in graph.highlightSegments where segment.kind == .charging {
            let startX = max(x(for: segment.start, plotRect: plotRect), plotRect.minX)
            let endX = min(x(for: segment.end, plotRect: plotRect), plotRect.maxX)
            let width = endX - startX
            guard width >= Metrics.chargingLineWidth else { continue }

            if width >= Metrics.minimumBoltSegmentWidth {
                let centerX = (startX + endX) / 2
                drawChargingLine(
                    in: &context,
                    from: startX,
                    to: centerX - Metrics.chargingBoltGap / 2,
                    centerY: centerY
                )
                drawChargingLine(
                    in: &context,
                    from: centerX + Metrics.chargingBoltGap / 2,
                    to: endX,
                    centerY: centerY
                )
                drawChargingBolt(in: &context, center: CGPoint(x: centerX, y: centerY))
            } else {
                drawChargingLine(in: &context, from: startX, to: endX, centerY: centerY)
            }
        }
    }

    private func drawChargingLine(
        in context: inout GraphicsContext,
        from startX: CGFloat,
        to endX: CGFloat,
        centerY: CGFloat
    ) {
        guard endX > startX else { return }
        let rect = CGRect(
            x: startX,
            y: centerY - Metrics.chargingLineWidth / 2,
            width: endX - startX,
            height: Metrics.chargingLineWidth
        )
        context.fill(
            Path(roundedRect: rect, cornerRadius: Metrics.chargingLineWidth / 2, style: .continuous),
            with: .color(barColor)
        )
    }

    private func drawChargingBolt(in context: inout GraphicsContext, center: CGPoint) {
        var bolt = Path()
        bolt.move(to: CGPoint(x: center.x + 1, y: center.y - 6))
        bolt.addLine(to: CGPoint(x: center.x - 4, y: center.y + 1))
        bolt.addLine(to: CGPoint(x: center.x - 0.5, y: center.y + 1))
        bolt.addLine(to: CGPoint(x: center.x - 2, y: center.y + 6))
        bolt.addLine(to: CGPoint(x: center.x + 4, y: center.y - 2))
        bolt.addLine(to: CGPoint(x: center.x + 0.5, y: center.y - 2))
        bolt.closeSubpath()
        context.fill(bolt, with: .color(barColor))
    }

    private func drawBars(in context: inout GraphicsContext, plotRect: CGRect) {
        let barCount = max(Metrics.minBarCount, Int(plotRect.width / Metrics.slotWidth))
        let slot = plotRect.width / CGFloat(barCount)
        let barWidth = max(slot * Metrics.barFill, 1)
        for index in 0..<barCount {
            let bucketEnd = graph.windowStart.addingTimeInterval(
                BatteryGraph.window * Double(index + 1) / Double(barCount)
            )
            guard let level = graph.level(at: bucketEnd), level > 0 else { continue }
            let height = max(plotRect.height * CGFloat(level) / 100, Metrics.minBarHeight)
            let barX = plotRect.minX + CGFloat(index) * slot + (slot - barWidth) / 2
            let rect = CGRect(x: barX, y: plotRect.maxY - height, width: barWidth, height: height)
            let color = level <= 10 ? lowLevelColor : barColor
            context.fill(topRoundedBarPath(in: rect), with: .color(color))
        }
    }

    private func topRoundedBarPath(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    private func drawAxisLabels(in context: inout GraphicsContext, plotRect: CGRect) {
        for (fraction, label) in [(1.0, "100%"), (0.5, "50%"), (0.0, "0%")] {
            let y = plotRect.maxY - CGFloat(fraction) * plotRect.height
            let rect = CGRect(
                x: plotRect.maxX + 4,
                y: max(y - 7, 0),
                width: Metrics.axisLabelWidth - 4,
                height: 14
            )
            context.draw(
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary),
                in: rect
            )
        }
        let formatter = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute()
        for tick in timeTicks() {
            let tickX = x(for: tick, plotRect: plotRect)
            let rect = CGRect(
                x: min(max(tickX - Metrics.timeLabelWidth / 2, 0), plotRect.width - Metrics.timeLabelWidth),
                y: plotRect.maxY + BatteryGraphLayout.chargingIndicatorHeight + 2,
                width: Metrics.timeLabelWidth,
                height: Metrics.timeLabelHeight
            )
            context.draw(
                Text(tick, format: formatter)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary),
                in: rect
            )
        }
    }
}
