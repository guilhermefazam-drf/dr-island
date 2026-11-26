import SwiftUI
import Charts

extension View {
    /// Tracks the x value under the pointer over a chart's plot (nil once it leaves), for the hover tooltip.
    func chartHover<X: Plottable>(_ value: Binding<X?>) -> some View {
        chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            guard let plot = proxy.plotFrame else { return }
                            value.wrappedValue = proxy.value(atX: point.x - geo[plot].origin.x, as: X.self)
                        case .ended:
                            value.wrappedValue = nil
                        }
                    }
            }
        }
    }
}
