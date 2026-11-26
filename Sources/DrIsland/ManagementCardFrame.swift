import SwiftUI
import DrIslandCore

/// The frame every «Gestão» card shares: the island's card, one fixed height so a row lines up, the header on top and,
/// when given, the summary pills pinned to the bottom.
struct ManagementCardFrame<Accessory: View, Content: View, Footer: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer
    @Environment(\.islandMetrics) private var metrics

    init(title: String, icon: String, @ViewBuilder accessory: () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer = { EmptyView() }) {
        self.title = title
        self.icon = icon
        self.accessory = accessory()
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardHeader(title: title, icon: icon, source: .sprint) { accessory }
            content
            Spacer(minLength: 0)
            HStack(spacing: 6) { footer; Spacer(minLength: 0) }
                .frame(height: IslandLayout.managementSummary)
        }
        .frame(maxWidth: .infinity, minHeight: IslandLayout.managementCardContent(metrics),
               maxHeight: IslandLayout.managementCardContent(metrics), alignment: .topLeading)
        .blockCard()
    }
}
