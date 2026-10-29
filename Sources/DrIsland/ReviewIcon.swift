import SwiftUI
import DrIslandCore

/// A PR's review state as an icon with its tooltip.
struct ReviewIcon: View {
    let pr: PullRequest

    var body: some View {
        // My own approval on a review request is not the PR's: it is only "approved" once the approval bar is met.
        if pr.role == .reviewRequested, pr.review == .approved, pr.teamReview != .approved {
            Image(systemName: "checkmark.circle").foregroundStyle(.gray).islandTip("Aprovaste; faltam aprovações")
        } else {
            switch pr.review {
            case .approved: Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).islandTip("Aprovado")
            case .changesRequested: Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange).islandTip("Alterações pedidas")
            case .reviewRequired: Image(systemName: "eye").foregroundStyle(.gray).islandTip("Aguarda review")
            case .none: EmptyView()
            }
        }
    }
}
