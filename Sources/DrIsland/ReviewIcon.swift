import SwiftUI
import DrIslandCore

/// A PR's review state as an icon with its tooltip.
struct ReviewIcon: View {
    let pr: PullRequest
    @Environment(\.islandPalette) private var palette

    var body: some View {
        // My own approval on a review request is not the PR's: it is only "approved" once the approval bar is met.
        if pr.role == .reviewRequested, pr.review == .approved, pr.teamReview != .approved {
            Image(systemName: "checkmark.circle").foregroundStyle(Color(palette.neutral)).islandTip("Aprovaste; faltam aprovações")
        } else {
            switch pr.review {
            case .approved: Image(systemName: "checkmark.seal.fill").foregroundStyle(Color(palette.green)).islandTip("Aprovado")
            case .changesRequested: Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(Color(palette.amber)).islandTip("Alterações pedidas")
            case .reviewRequired: Image(systemName: "eye").foregroundStyle(Color(palette.neutral)).islandTip("Aguarda review")
            case .none: EmptyView()
            }
        }
    }
}
