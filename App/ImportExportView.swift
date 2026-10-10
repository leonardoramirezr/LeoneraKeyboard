import SwiftUI

struct ImportExportView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @State private var importText = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                ShareLink(item: store.configuration.jsonString()) {
                    Label("Compartir JSON", systemImage: "square.and.arrow.up")
                }
                Button {
                    UIPasteboard.general.string = store.configuration.jsonString()
                    message = "Configuración copiada al portapapeles."
                } label: {
                    Label("Copiar JSON", systemImage: "doc.on.doc")
                }
            } header: {
                Text("Exportar")
            } footer: {
                Text("Incluye la distribución completa y los ajustes del teclado.")
            }

            Section("Importar") {
                TextEditor(text: $importText)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 200)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button {
                    importText = UIPasteboard.general.string ?? ""
                } label: {
                    Label("Pegar del portapapeles", systemImage: "doc.on.clipboard")
                }
                Button {
                    importConfiguration()
                } label: {
                    Label("Importar", systemImage: "square.and.arrow.down")
                }
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Importar / exportar")
        .navigationBarTitleDisplayMode(.inline)
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private func importConfiguration() {
        do {
            store.configuration = try KeyboardConfiguration.fromJSON(importText)
            message = "Configuración importada."
        } catch {
            message = "No se pudo importar: \(error.localizedDescription)"
        }
    }
}
