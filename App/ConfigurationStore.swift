import SwiftUI

/// Mantiene la configuración editable en la app y la guarda en el App Group
/// cada vez que cambia, para que la extensión la lea al mostrarse.
final class ConfigurationStore: ObservableObject {
    @Published var configuration: KeyboardConfiguration {
        didSet {
            if configuration != oldValue {
                ConfigurationStorage.save(configuration)
            }
        }
    }

    init() {
        configuration = ConfigurationStorage.load()
    }

    func resetToDefault() {
        configuration = .default
    }

    // MARK: - Edición de teclas

    func key(rowID: UUID, keyID: UUID) -> KeyDefinition? {
        configuration.layout.rows.first { $0.id == rowID }?.keys.first { $0.id == keyID }
    }

    func updateKey(_ key: KeyDefinition, inRow rowID: UUID) {
        guard let rowIndex = rowIndex(rowID),
              let keyIndex = configuration.layout.rows[rowIndex].keys.firstIndex(where: { $0.id == key.id })
        else { return }
        configuration.layout.rows[rowIndex].keys[keyIndex] = key
    }

    func deleteKey(_ keyID: UUID, inRow rowID: UUID) {
        guard let rowIndex = rowIndex(rowID) else { return }
        configuration.layout.rows[rowIndex].keys.removeAll { $0.id == keyID }
    }

    @discardableResult
    func addKey(toRow rowID: UUID) -> KeyDefinition? {
        guard let rowIndex = rowIndex(rowID) else { return nil }
        let key = KeyDefinition(primary: .character("a"))
        configuration.layout.rows[rowIndex].keys.append(key)
        return key
    }

    func moveKey(_ keyID: UUID, fromRow rowID: UUID, toRow targetRowID: UUID) {
        guard rowID != targetRowID,
              let from = rowIndex(rowID),
              let to = rowIndex(targetRowID),
              let keyIndex = configuration.layout.rows[from].keys.firstIndex(where: { $0.id == keyID })
        else { return }
        let key = configuration.layout.rows[from].keys.remove(at: keyIndex)
        configuration.layout.rows[to].keys.append(key)
    }

    // MARK: - Edición de filas

    func addRow() {
        configuration.layout.rows.append(KeyRow(keys: [KeyDefinition(primary: .character("a"))]))
    }

    func deleteRow(_ rowID: UUID) {
        configuration.layout.rows.removeAll { $0.id == rowID }
    }

    func moveRow(_ rowID: UUID, by offset: Int) {
        guard let index = rowIndex(rowID) else { return }
        let target = index + offset
        guard configuration.layout.rows.indices.contains(target) else { return }
        configuration.layout.rows.swapAt(index, target)
    }

    func rowIndex(_ rowID: UUID) -> Int? {
        configuration.layout.rows.firstIndex { $0.id == rowID }
    }
}
