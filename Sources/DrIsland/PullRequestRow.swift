import AppKit
import SwiftUI
import DrIslandCore

/// One PR: CI, review state, #number, title, then why it needs attention and who owns it.
/// Clicking opens it; the context menu copies the link or silences it.
struct PullRequestRow: View {
    let pr: PullRequest
    /// The unseen change on this PR, shown as a tag and a tinted row (nil with row alerts off).
    let change: PRChange?
    @AppStorage(SettingsKey.prMutes) private var mutesJSON = "[]"
    @Environment(\.islandPalette) private var palette
    @Environment(\.islandMetrics) private var metrics

    var body: some View {
        Button { NSWorkspace.shared.open(pr.url) } label: {
            ListRow(key: "#\(pr.number)", title: pr.title, meta: meta, tint: tint) {
                Image(systemName: Self.ciSymbol(pr.ci)).foregroundStyle(Self.ciColor(pr.ci, palette)).frame(width: 14)
                    .islandTip(Self.ciText(pr.ci))
                ReviewIcon(pr: pr).frame(width: 18)
            } trailing: {
                // At the right end, so a conflict does not push this row's key and title out of line with the others.
                if pr.hasConflicts { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(palette.amber)).islandTip("Conflitos com a branch base") }
                if let change {
                    Pill(change.label, change.tone.color(in: palette))
                } else if let reason = attentionReason {
                    Pill(reason.text, reason.tone.color(in: palette))
                }
                if pr.role == .authored, let comments = pr.unresolvedThreadCount, comments > 0, !metrics.rowHasMeta {
                    Pill("\(comments) por resolver", Color(palette.textSecondary))
                        .islandTip("\(comments) thread\(comments == 1 ? "" : "s") por resolver")
                }
                if pr.isDraft { Pill("draft", Color(palette.neutral)) }
                Avatar(name: pr.author, isMine: pr.isMine)
            }
        }
        .buttonStyle(.plain)
        .islandTip(pr.title)
        .opacity(PRMutes.isMuted(prID: pr.id, in: PRMutes.decode(mutesJSON)) ? 0.45 : 1)
        .contextMenu { menu }
    }

    /// The details line: repository, the author on others' PRs, and threads left to resolve on the user's own.
    private var meta: String {
        // The repository's name from the PR's URL (github.com/<owner>/<repo>/pull/<n>); the stored field can be the owner alone.
        let path = pr.url.pathComponents
        var parts = [path.count > 2 ? path[2] : pr.repository]
        if pr.role == .reviewRequested, let author = pr.author, !author.isEmpty { parts.append(author) }
        if pr.role == .authored, let comments = pr.unresolvedThreadCount, comments > 0 {
            parts.append("\(comments) thread\(comments == 1 ? "" : "s") por resolver")
        }
        return parts.joined(separator: " · ")
    }

    /// An unseen change paints the row; so does a review that waits on the user for a reason other than "new".
    private var tint: Color? {
        if let change { return change.tone.color(in: palette).opacity(0.16) }
        if pr.role == .reviewRequested, let reason = attentionReason, reason.tone != .info { return reason.tone.color(in: palette).opacity(0.12) }
        return nil
    }

    @ViewBuilder private var menu: some View {
        Button("Abrir no navegador") { NSWorkspace.shared.open(pr.url) }
        Button("Copiar link", action: copyLink)
        if pr.ci == .failing {
            Button("Abrir o CI com falha") { NSWorkspace.shared.open(pr.url.appendingPathComponent("checks")) }
        }
        Divider()
        if PRMutes.isMuted(prID: pr.id, in: PRMutes.decode(mutesJSON)) {
            Button("Reativar avisos", action: unmute)
        } else {
            Menu("Silenciar este PR") {
                Button("1 hora") { mute(.pr(pr, until: Date().addingTimeInterval(3600))) }
                Button("1 dia") { mute(.pr(pr, until: Date().addingTimeInterval(86400))) }
                Button("Até eu reativar") { mute(.pr(pr, until: nil)) }
            }
            Menu("Silenciar o repositório") {
                Button("1 dia") { mute(.repository(pr, until: Date().addingTimeInterval(86400))) }
                Button("Até eu reativar") { mute(.repository(pr, until: nil)) }
            }
        }
    }

    private func copyLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pr.url.absoluteString, forType: .string)
    }

    private func mute(_ mute: PRMute) { mutesJSON = PRMutes.encode(PRMutes.adding(mute, to: PRMutes.decode(mutesJSON))) }

    private func unmute() {
        let mutes = PRMutes.decode(mutesJSON)
        mutesJSON = PRMutes.encode(PRMutes.removing(key: "repo:" + pr.repository, from: PRMutes.removing(key: "pr:" + pr.id, from: mutes)))
    }

    /// Why a PR needs attention right now, so the row says it in words and not only with an icon. In the review block
    /// this is only a label: it never feeds the attention dot or the alerts.
    private var attentionReason: (text: String, tone: PRChange.Tone)? {
        if pr.role == .reviewRequested {
            // The verdict the user gave stays on the row until the PR is merged or closed.
            if pr.review == .changesRequested { return ("rejeitado", .critical) }
            if pr.review == .approved { return pr.teamReview == .approved ? ("aprovado", .success) : ("aprovaste", .info) }
        }
        if pr.ci == .failing { return ("CI falhou", .critical) }
        if pr.hasConflicts { return ("conflitos", .warning) }
        if pr.review == .changesRequested { return ("alterações pedidas", .warning) }
        return nil
    }

    private static func ciSymbol(_ ci: CIState) -> String {
        switch ci {
        case .passing: return "checkmark.circle.fill"
        case .failing: return "xmark.circle.fill"
        case .pending: return "clock.fill"
        case .none: return "circle.dashed"
        }
    }

    private static func ciText(_ ci: CIState) -> String {
        switch ci {
        case .passing: return "CI a passar"
        case .failing: return "CI falhou"
        case .pending: return "CI a correr"
        case .none: return "Sem CI"
        }
    }

    private static func ciColor(_ ci: CIState, _ palette: IslandPalette) -> Color {
        switch ci {
        case .passing: return Color(palette.green)
        case .failing: return Color(palette.red)
        case .pending: return Color(palette.amber)
        case .none: return Color(palette.neutral)
        }
    }
}
