import SwiftUI

struct KeyEditorView: View {
    let rowID: UUID
    let original: KeyDefinition

    @EnvironmentObject private var store: ConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var key: KeyDefinition
    @State private var targetRowID: UUID
    @State private var previewSwipe = false

    init(rowID: UUID, original: KeyDefinition) {
        self.rowID = rowID
        self.original = original
        _key = State(initialValue: original)
        _targetRowID = State(initialValue: rowID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        KeyCapView(key: key, isSwiping: previewSwipe, rowHeight: 56)
                            .frame(width: min(64 * CGFloat(key.width), 280), height: 56)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(KeyboardPalette.background(colorScheme))
                    .listRowInsets(EdgeInsets())

                    if key.secondary != nil {
                        Toggle("Ver como deslizada", isOn: $previewSwipe)
                    }
                }

                Section("Al tocar") {
                    ActionEditor(action: $key.primary)
                }

                Section {
                    Toggle("Acción al deslizar hacia abajo", isOn: hasSecondary)
                    if let secondary = Binding($key.secondary) {
                        ActionEditor(action: secondary)
                    }
                } header: {
                    Text("Al deslizar hacia abajo")
                } footer: {
                    Text("Se muestra como el símbolo pequeño en la parte superior de la tecla.")
                }

                Section("Apariencia") {
                    TextField("Etiqueta personalizada (opcional)", text: label)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Stepper(value: $key.width, in: 0.25...10, step: 0.25) {
                        Text("Ancho: \(key.width.formatted())")
                    }
                }

                Section("Fila") {
                    Picker("Fila", selection: $targetRowID) {
                        ForEach(Array(store.configuration.layout.rows.enumerated()), id: \.element.id) { index, row in
                            Text("Fila \(index + 1)").tag(row.id)
                        }
                    }
                }

                Section {
                    Button("Eliminar tecla", role: .destructive) {
                        store.deleteKey(original.id, inRow: rowID)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Editar tecla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        store.updateKey(key, inRow: rowID)
                        store.moveKey(key.id, fromRow: rowID, toRow: targetRowID)
                        dismiss()
                    }
                }
            }
        }
    }

    private var hasSecondary: Binding<Bool> {
        Binding(
            get: { key.secondary != nil },
            set: { enabled in
                key.secondary = enabled ? (key.secondary ?? .character("")) : nil
                if !enabled { previewSwipe = false }
            }
        )
    }

    private var label: Binding<String> {
        Binding(
            get: { key.label ?? "" },
            set: { key.label = $0.isEmpty ? nil : $0 }
        )
    }
}

struct ActionEditor: View {
    @Binding var action: KeyAction

    var body: some View {
        Picker("Acción", selection: $action.type) {
            ForEach(KeyActionType.allCases) { type in
                if let symbol = type.systemImage {
                    Label(type.displayName, systemImage: symbol).tag(type)
                } else {
                    Text(type.displayName).tag(type)
                }
            }
        }
        if action.type == .character {
            TextField("Texto a escribir", text: $action.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }
}
