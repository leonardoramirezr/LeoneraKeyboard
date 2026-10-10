import SwiftUI

struct EditingKey: Identifiable {
    let rowID: UUID
    let key: KeyDefinition
    var id: UUID { key.id }
}

struct LayoutEditorView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @State private var editing: EditingKey?

    private var rows: [KeyRow] { store.configuration.layout.rows }

    var body: some View {
        VStack(spacing: 0) {
            KeyboardPreview(configuration: store.configuration, selectedKeyID: editing?.key.id) { row, key in
                editing = EditingKey(rowID: row.id, key: key)
            }

            List {
                Section {
                    TextField("Nombre de la distribución", text: $store.configuration.layout.name)
                } footer: {
                    Text("Toca una tecla en la vista previa o en la lista para editarla. Usa «Editar» para reordenar o eliminar teclas.")
                }

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Section {
                        ForEach(row.keys) { key in
                            Button {
                                editing = EditingKey(rowID: row.id, key: key)
                            } label: {
                                HStack {
                                    Text(key.summary)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("×\(key.width.formatted())")
                                        .foregroundColor(.secondary)
                                        .font(.caption.monospacedDigit())
                                }
                            }
                        }
                        .onDelete { offsets in
                            guard let rowIndex = store.rowIndex(row.id) else { return }
                            store.configuration.layout.rows[rowIndex].keys.remove(atOffsets: offsets)
                        }
                        .onMove { source, destination in
                            guard let rowIndex = store.rowIndex(row.id) else { return }
                            store.configuration.layout.rows[rowIndex].keys.move(fromOffsets: source, toOffset: destination)
                        }

                        Button {
                            if let key = store.addKey(toRow: row.id) {
                                editing = EditingKey(rowID: row.id, key: key)
                            }
                        } label: {
                            Label("Añadir tecla", systemImage: "plus")
                        }
                    } header: {
                        HStack {
                            Text("Fila \(index + 1)")
                            Spacer()
                            Menu {
                                Button {
                                    store.moveRow(row.id, by: -1)
                                } label: {
                                    Label("Subir fila", systemImage: "arrow.up")
                                }
                                .disabled(index == 0)
                                Button {
                                    store.moveRow(row.id, by: 1)
                                } label: {
                                    Label("Bajar fila", systemImage: "arrow.down")
                                }
                                .disabled(index == rows.count - 1)
                                Button(role: .destructive) {
                                    store.deleteRow(row.id)
                                } label: {
                                    Label("Eliminar fila", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }

                Section {
                    Button {
                        store.addRow()
                    } label: {
                        Label("Añadir fila", systemImage: "plus.rectangle")
                    }
                }
            }
        }
        .navigationTitle("Distribución")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(item: $editing) { item in
            KeyEditorView(rowID: item.rowID, original: item.key)
                .environmentObject(store)
        }
    }
}
