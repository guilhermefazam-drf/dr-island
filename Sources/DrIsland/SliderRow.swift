import ServiceManagement
import SwiftUI
import DrIslandCore

/// Title and current value on one line, the slider under them.
struct SliderRow: View {
    let title: String
    let value: String
    @Binding var number: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value).foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $number, in: range, step: step)
        }
    }
}
