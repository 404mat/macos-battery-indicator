import SwiftUI

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct StatusItemRootView: View {
    @ObservedObject var model: BatteryIndicatorModel
    let onSizeChange: (CGSize) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            BatteryIndicatorView(model: model)
                .frame(width: 30, height: 13)
            if model.showPercentage && model.showPercentageNextToIndicator && model.chargingMode != .error {
                Text(model.batteryLevel, format: .percent)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: SizePreferenceKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onSizeChange)
    }
}
