import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @State private var testText = ""
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    KeyboardPreview(configuration: store.configuration)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text("Toca una tecla para escribir el carácter grande. Deslízala hacia abajo para escribir el símbolo pequeño o ejecutar su acción.")
                }

                Section("Activar el teclado") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. Abre Ajustes › General › Teclado › Teclados.")
                        Text("2. Pulsa «Añadir teclado» y elige «Leonera».")
                        Text("3. Activa «Permitir acceso completo» para pegar, vibración y cargar tu distribución personalizada.")
                    }
                    .font(.callout)

                    Button("Abrir Ajustes") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("Probar") {
                    TextField("Escribe aquí para probar el teclado", text: $testText, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Personalizar") {
                    NavigationLink {
                        LayoutEditorView()
                    } label: {
                        Label("Editar distribución", systemImage: "keyboard")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Ajustes del teclado", systemImage: "slider.horizontal.3")
                    }
                    NavigationLink {
                        ImportExportView()
                    } label: {
                        Label("Importar / exportar", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                Section {
                    Button("Restablecer teclado por defecto", role: .destructive) {
                        confirmingReset = true
                    }
                }
            }
            .navigationTitle("Leonera Keyboard")
            .scrollDismissesKeyboard(.interactively)
            .confirmationDialog("¿Restablecer la distribución y los ajustes por defecto?",
                                isPresented: $confirmingReset,
                                titleVisibility: .visible) {
                Button("Restablecer", role: .destructive) {
                    store.resetToDefault()
                }
            }
        }
    }
}

/// Vista previa estática del teclado. Si se pasa `onSelect`, las teclas se pueden tocar.
struct KeyboardPreview: View {
    let configuration: KeyboardConfiguration
    var selectedKeyID: UUID?
    var onSelect: ((KeyRow, KeyDefinition) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var rowHeight: CGFloat { CGFloat(min(max(configuration.settings.rowHeight, 30), 80)) }

    var body: some View {
        KeyboardGrid(rows: configuration.layout.rows, rowHeight: rowHeight) { key in
            KeyCapView(
                key: key,
                shift: .off,
                showLowercase: configuration.settings.showLowercase,
                isSelected: key.id == selectedKeyID,
                rowHeight: rowHeight
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if let onSelect, let row = configuration.layout.rows.first(where: { $0.keys.contains { $0.id == key.id } }) {
                    onSelect(row, key)
                }
            }
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 6)
        .background(KeyboardPalette.background(colorScheme))
    }
}
