import AppKit
import SwiftUI

/// The error log, readable without leaving the app, plus the way out of a stuck island.
struct LogPage: View {
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                Text("Erros das fontes (Claude, GitHub, Jira), exceções, crashes e momentos em que a interface deixou de responder. Fica em \(ErrorLog.fileURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Atualizar", action: reload)
                    Button("Copiar") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }.disabled(text.isEmpty)
                    Button("Mostrar no Finder") { NSWorkspace.shared.activateFileViewerSelecting([ErrorLog.fileURL]) }
                    Button("Limpar", role: .destructive) { ErrorLog.clear(); reload() }.disabled(text.isEmpty)
                    Spacer()
                    Button("Reiniciar a app") { ErrorLog.relaunch() }
                }
            }
            Section("Últimas entradas") {
                if text.isEmpty {
                    Text("Sem erros registados.").foregroundStyle(.secondary)
                } else {
                    Text(text)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
    }

    private func reload() { text = ErrorLog.tail() }
}
