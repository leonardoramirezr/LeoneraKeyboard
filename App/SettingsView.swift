import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ConfigurationStore

    private var settings: Binding<KeyboardSettings> { $store.configuration.settings }

    var body: some View {
        Form {
            Section {
                KeyboardPreview(configuration: store.configuration)
                    .listRowInsets(EdgeInsets())
            }

            Section("Escritura") {
                Toggle("Mayúscula automática", isOn: settings.autoCapitalize)
                Toggle("Mostrar teclas en minúscula", isOn: settings.showLowercase)
            }

            Section {
                Toggle("Vibración", isOn: settings.haptics)
                Toggle("Sonido de teclas", isOn: settings.keyClicks)
            } header: {
                Text("Respuesta")
            } footer: {
                Text("La vibración, el sonido y la acción «Pegar» requieren «Permitir acceso completo» en los ajustes del teclado.")
            }

            Section {
                VStack(alignment: .leading) {
                    Text("Alto de fila: \(Int(store.configuration.settings.rowHeight)) pt")
                    Slider(value: settings.rowHeight, in: 36...64, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Distancia para deslizar: \(Int(store.configuration.settings.swipeThreshold)) pt")
                    Slider(value: settings.swipeThreshold, in: 8...40, step: 1)
                }
            } header: {
                Text("Tamaño y gestos")
            } footer: {
                Text("La distancia para deslizar es cuánto hay que arrastrar una tecla hacia abajo para usar su símbolo secundario.")
            }
        }
        .navigationTitle("Ajustes del teclado")
        .navigationBarTitleDisplayMode(.inline)
    }
}
