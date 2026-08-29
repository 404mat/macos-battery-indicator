import SwiftUI

struct BatteryIndicatorView: View {
    @ObservedObject var model: BatteryIndicatorModel

    private let height: CGFloat = 13

    private var cornerRadius: CGFloat {
        height / 3.25
    }

    private var trackColor: Color {
        .primary.opacity(0.35)
    }

    private var fillColor: Color {
        model.batteryLevel <= 10 ? .red : .primary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(trackColor)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        let width = (Double(model.batteryLevel) / 100) * proxy.size.width
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(fillColor)
                            .frame(width: width)
                    }
                }
            HalfCircleShape()
                .fill(trackColor)
                .frame(width: height / 6, height: height / 3)
        }
        .frame(width: 30, height: height)
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

struct HalfCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.midY),
            radius: rect.height / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
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
