import SwiftUI

struct BatteryIndicatorView: View {
    @ObservedObject var model: BatteryIndicatorModel

    private let height: CGFloat = 13

    private var cornerRadius: CGFloat {
        height * 0.36
    }

    private var trackColor: Color {
        .primary.opacity(0.35)
    }

    private var fillColor: Color {
        model.batteryLevel <= 10 ? .red : .primary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(trackColor)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        let width = (Double(model.batteryLevel) / 100) * proxy.size.width
                        Group {
                            if model.batteryLevel >= 100 {
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(fillColor)
                            } else {
                                BatteryFillShape(radius: cornerRadius)
                                    .fill(fillColor)
                            }
                        }
                        .frame(width: width)
                    }
                }
            KnobShape()
                .fill(trackColor)
                .frame(width: height * 0.225, height: height * 0.45)
        }
        .frame(width: 31, height: height)
        .animation(.default, value: model.batteryLevel)
        .animation(.default, value: model.chargingMode)
        .reverseMask {
            if model.chargingMode == .charging {
                ChargingModeSymbol().offset(x: -1.9, y: 0.1)
                ChargingModeSymbol().offset(x: -0.1, y: -0.1)
                ChargingModeSymbol().offset(x: -2.2, y: 0.7)
                ChargingModeSymbol().offset(x: 0.2, y: -0.7)
            }
        }
        .overlay {
            if model.chargingMode == .charging {
                ChargingModeSymbol()
                    .foregroundStyle(Color.accentColor)
                    .offset(x: -1)
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
    }
}

struct ChargingModeSymbol: View {
    var body: some View {
        Image(systemName: "bolt.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 9)
    }
}

struct BatteryFillShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + r),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
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
