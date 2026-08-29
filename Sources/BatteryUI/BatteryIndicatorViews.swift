import BatteryCore
import SwiftUI

public struct BatteryIndicatorView: View {
    @ObservedObject var model: BatteryIndicatorModel

    public init(model: BatteryIndicatorModel) {
        self.model = model
    }

    public enum Metrics {
        public static let height: CGFloat = 13
        public static let width: CGFloat = 31
        public static let knobGap: CGFloat = 1.5
        public static let knobWidth: CGFloat = height * 0.18
        public static let knobHeight: CGFloat = height * 0.36
        public static let cornerRadius: CGFloat = height * 0.36
        public static let statusItemLength: CGFloat = width + 1
        public static let bodyCenterOffsetX: CGFloat = -(knobGap + knobWidth) / 2
    }

    private var trackColor: Color {
        .primary.opacity(0.35)
    }

    private var fillColor: Color {
        if model.chargingMode == .charging {
            return Color(nsColor: .systemGreen)
        }
        return model.batteryLevel <= 10 ? .red : .primary
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Metrics.knobGap) {
            RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                .fill(trackColor)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        let width = (Double(model.batteryLevel) / 100) * proxy.size.width
                        Group {
                            if model.batteryLevel >= 100 {
                                RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous)
                                    .fill(fillColor)
                            } else {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: Metrics.cornerRadius,
                                    bottomLeadingRadius: Metrics.cornerRadius,
                                    style: .continuous
                                )
                                .fill(fillColor)
                            }
                        }
                        .frame(width: width)
                    }
                }
            KnobShape()
                .fill(trackColor)
                .frame(width: Metrics.knobWidth, height: Metrics.knobHeight)
        }
        .frame(width: Metrics.width, height: Metrics.height)
        .animation(.default, value: model.batteryLevel)
        .animation(.default, value: model.chargingMode)
        .reverseMask {
            if model.chargingMode == .charging {
                ChargingModeCutoutSymbol()
                    .offset(x: Metrics.bodyCenterOffsetX)
            }
        }
        .overlay {
            if model.chargingMode == .charging {
                ChargingModeSymbol()
                    .foregroundStyle(.primary)
                    .offset(x: Metrics.bodyCenterOffsetX)
            }
            if model.chargingMode == .error {
                Image(systemName: "exclamationmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 9)
                    .foregroundStyle(.red)
                    .offset(x: -1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ChargingModeSymbol: View {
    var body: some View {
        LightningBoltShape()
            .fill()
            .frame(width: 11, height: 17)
    }
}

struct ChargingModeCutoutSymbol: View {
    var body: some View {
        LightningBoltShape()
            .fill()
            .overlay {
                LightningBoltShape()
                    .stroke(style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            }
            .frame(width: 11, height: 17)
    }
}

struct LightningBoltShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY),
            CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.57),
            CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.57),
            CGPoint(x: rect.minX + rect.width * 0.27, y: rect.maxY),
            CGPoint(x: rect.minX + rect.width * 0.98, y: rect.minY + rect.height * 0.39),
            CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.39),
        ]
        let cornerOffset = min(rect.width, rect.height) * 0.075
        var path = Path()

        for index in points.indices {
            let point = points[index]
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let beforeCorner = offsetPoint(from: point, toward: previous, by: cornerOffset)
            let afterCorner = offsetPoint(from: point, toward: next, by: cornerOffset)

            if index == points.startIndex {
                path.move(to: beforeCorner)
            } else {
                path.addLine(to: beforeCorner)
            }
            path.addQuadCurve(to: afterCorner, control: point)
        }

        path.closeSubpath()
        return path
    }

    private func offsetPoint(from point: CGPoint, toward target: CGPoint, by distance: CGFloat) -> CGPoint {
        let deltaX = target.x - point.x
        let deltaY = target.y - point.y
        let length = hypot(deltaX, deltaY)
        guard length > 0 else { return point }

        let offset = min(distance, length / 2)
        return CGPoint(
            x: point.x + deltaX / length * offset,
            y: point.y + deltaY / length * offset
        )
    }
}

struct KnobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control1: CGPoint(x: rect.minX + rect.width * 4 / 3, y: rect.minY),
            control2: CGPoint(x: rect.minX + rect.width * 4 / 3, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

extension View {
    @ViewBuilder
    func reverseMask<Mask: View>(
        alignment: Alignment = .center,
        @ViewBuilder _ mask: () -> Mask
    ) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: alignment) {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}
