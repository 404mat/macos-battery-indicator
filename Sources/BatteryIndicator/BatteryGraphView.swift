import SwiftUI

enum BatteryGraphLayout {
    static let horizontalInset: CGFloat = 15
    static let topPadding: CGFloat = 8
    static let titleHeight: CGFloat = 16
    static let titleSpacing: CGFloat = 6
    static let plotHeight: CGFloat = 90
    static let timeAxisHeight: CGFloat = 14
    static let bottomPadding: CGFloat = 8

    static var totalHeight: CGFloat {
        topPadding + titleHeight + titleSpacing + plotHeight + timeAxisHeight + bottomPadding
    }
}

struct BatteryGraphView: View {
    @ObservedObject var model: BatteryIndicatorModel

    var body: some View {
        VStack(alignment: .leading, spacing: BatteryGraphLayout.titleSpacing) {
            Text("Last 12 hours")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(height: BatteryGraphLayout.titleHeight, alignment: .leading)
            if let graph = model.batteryGraph {
                BatteryGraphCanvas(graph: graph)
                    .frame(height: BatteryGraphLayout.plotHeight + BatteryGraphLayout.timeAxisHeight)
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
        static let slotWidth: CGFloat = 2.8
        static let barFill: CGFloat = 0.55
        static let minBarCount = 24
        static let minBarHeight: CGFloat = 2
        static let axisLabelWidth: CGFloat = 36
        static let timeLabelWidth: CGFloat = 34
        static let timeLabelHeight: CGFloat = 12
    }

    private var barColor: Color {
        Color(nsColor: .systemGreen)
    }

    var body: some View {
        Canvas { context, size in
            let plotRect = CGRect(
                x: 0,
                y: 0,
                width: size.width - Metrics.axisLabelWidth,
                height: size.height - BatteryGraphLayout.timeAxisHeight
            )
            drawGrid(in: &context, plotRect: plotRect)
            drawACPowerHighlights(in: &context, plotRect: plotRect)
            drawBars(in: &context, plotRect: plotRect)
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

    private func drawACPowerHighlights(in context: inout GraphicsContext, plotRect: CGRect) {
        for segment in graph.acPowerSegments {
            let startX = x(for: segment.start, plotRect: plotRect)
            let endX = x(for: segment.end, plotRect: plotRect)
            guard endX - startX >= 1 else { continue }
            let rect = CGRect(x: startX, y: plotRect.minY, width: endX - startX, height: plotRect.height)
            context.fill(Path(rect), with: .color(barColor.opacity(0.16)))
        }
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
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2, style: .continuous)
            context.fill(path, with: .color(barColor))
        }
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
                y: plotRect.maxY + 2,
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
