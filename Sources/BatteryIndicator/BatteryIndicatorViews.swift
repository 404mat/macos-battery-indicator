import SwiftUI

struct BatteryIndicatorView: View {
    @ObservedObject var model: BatteryIndicatorModel

    private let height: CGFloat = 13

    var body: some View {
        HStack(alignment: .center, spacing: 1) {
            BasicBatteryIndicatorView(model: model, height: height)
                .animation(.default, value: model.batteryLevel)
                .animation(.default, value: model.chargingMode)
            HalfCircleShape()
                .foregroundStyle(.primary)
                .opacity(0.4)
                .frame(width: 2, height: height / 6)
                .offset(x: -0.5)
        }
        .frame(width: 30, height: height)
        .overlay {
            if model.chargingMode == .error {
                Image(systemName: "exclamationmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 9)
                    .foregroundStyle(.red)
                    .padding(.leading, 2)
            }
        }
    }
}

struct BasicBatteryIndicatorView: View {
    @ObservedObject var model: BatteryIndicatorModel
    let height: CGFloat

    private var fillColor: Color {
        model.batteryLevel <= 10 ? .red : .primary.opacity(0.9)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: height / 4, style: .continuous)
                .stroke(lineWidth: 1)
                .padding(1)
                .foregroundStyle(.primary)
                .opacity(0.5)
            GeometryReader { innerProxy in
                let width = (Double(model.batteryLevel) / 100) * innerProxy.size.width
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: width)
                    .foregroundStyle(fillColor)
            }
            .mask {
                RoundedRectangle(cornerRadius: height / 6, style: .continuous)
            }
            .padding(2.5)
        }
        .reverseMask {
            if model.chargingMode == .charging {
                ChargingModeSymbol()
                    .offset(x: -0.9, y: 0.1)
                ChargingModeSymbol()
                    .offset(x: 0.9, y: -0.1)
                ChargingModeSymbol()
                    .offset(x: -1.2, y: 0.7)
                ChargingModeSymbol()
                    .offset(x: 1.2, y: -0.7)
            }
        }
        .overlay {
            if model.chargingMode == .charging {
                ChargingModeSymbol()
                    .foregroundStyle(Color.accentColor)
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
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.maxX + rect.width * 1.5, y: rect.midY)
        )
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
