import AppKit
import SwiftUI
import DrIslandCore

/// One PR: CI, review state, repository#number, title, then why it needs attention and who owns it.
/// Clicking opens it; the context menu copies the link or silences it.
struct PullRequestRow: View {
    let pr: PullRequest
    /// The unseen change on this PR, shown as a tag and a tinted row (nil with row alerts off).
    let change: PRChange?
    @AppStorage(SettingsKey.prMutes) private var mutesJSON = "[]"

    var body: some View {
        Button { NSWorkspace.shared.open(pr.url) } label: {
            HStack(spacing: 8) {
                Image(systemName: Self.ciSymbol(pr.ci)).foregroundStyle(Self.ciColor(pr.ci)).frame(width: 14)
                    .islandTip(Self.ciText(pr.ci))
                if pr.hasConflicts { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).islandTip("Conflitos com a branch base") }
                ReviewIcon(pr: pr)
                Text("\(pr.repository.split(separator: "/").last.map(String.init) ?? pr.repository)#\(pr.number)")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                Text(pr.title).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                if let change {
                    RowTag(change.label, change.tone.color)
                } else if let reason = attentionReason {
                    RowTag(reason.text, reason.tone.color)
                }
                if pr.role == .authored, let comments = pr.unresolvedThreadCount, comments > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left.fill").font(.system(size: 8))
                        Text("\(comments)").font(.system(size: 9, weight: .semibold).monospacedDigit())
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 5).padding(.vertical, 1).background(Capsule().fill(Color.white.opacity(0.14)))
                    .islandTip("\(comments) thread\(comments == 1 ? "" : "s") por resolver")
                }
                if pr.isDraft { RowTag("draft", .gray) }
                OwnerTag(name: pr.author, isMine: pr.isMine)
            }
            .frame(height: IslandLayout.prRowHeight)
            .background {
                if let change {
                    RoundedRectangle(cornerRadius: 5).fill(change.tone.color.opacity(0.16)).padding(.horizontal, -6)
                } else if pr.role == .reviewRequested, let reason = attentionReason, reason.tone != .info {
                    RoundedRectangle(cornerRadius: 5).fill(reason.tone.color.opacity(0.12)).padding(.horizontal, -6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .islandTip(pr.title)
        .opacity(PRMutes.isMuted(prID: pr.id, in: PRMutes.decode(mutesJSON)) ? 0.45 : 1)
        .contextMenu { menu }
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

    private static func ciColor(_ ci: CIState) -> Color {
        switch ci {
        case .passing: return .green
        case .failing: return .red
        case .pending: return .yellow
        case .none: return .gray
        }
    }
}
