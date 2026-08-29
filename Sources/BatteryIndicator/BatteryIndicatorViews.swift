import SwiftUI

struct BatteryIndicatorView: View {
    @ObservedObject var model: BatteryIndicatorModel

    private let height: CGFloat = 13
    private let inset: CGFloat = 1.5

    private var trackColor: Color {
        .primary.opacity(0.35)
    }

    private var fillColor: Color {
        model.batteryLevel <= 10 ? .red : .primary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            RoundedRectangle(cornerRadius: height / 3.25, style: .continuous)
                .fill(trackColor)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        let availableWidth = proxy.size.width - inset * 2
                        let fillHeight = proxy.size.height - inset * 2
                        let width = max(0, (Double(model.batteryLevel) / 100) * availableWidth)
                        RoundedRectangle(cornerRadius: fillHeight / 3, style: .continuous)
                            .fill(fillColor)
                            .frame(width: width, height: fillHeight)
                            .offset(x: inset, y: inset)
                    }
                }
            Capsule()
                .fill(trackColor)
                .frame(width: 1.5, height: height / 3)
        }
        .frame(width: 30, height: height)
        .animation(.default, value: model.batteryLevel)
        .animation(.default, value: model.chargingMode)
        .reverseMask {
            if model.chargingMode == .charging {
                ChargingModeSymbol().offset(x: -2.4, y: 0.1)
                ChargingModeSymbol().offset(x: -0.6, y: -0.1)
                ChargingModeSymbol().offset(x: -2.7, y: 0.7)
                ChargingModeSymbol().offset(x: -0.3, y: -0.7)
            }
        }
        .overlay {
            if model.chargingMode == .charging {
                ChargingModeSymbol()
                    .foregroundStyle(Color.accentColor)
                    .offset(x: -1.5)
            }
            if model.chargingMode == .error {
                Image(systemName: "exclamationmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 9)
                    .foregroundStyle(.red)
                    .offset(x: -1.5)
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
