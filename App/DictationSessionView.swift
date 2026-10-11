import SwiftUI

/// Se muestra cuando el teclado abre la app para activar el micrófono.
struct DictationSessionView: View {
    @EnvironmentObject private var dictation: DictationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: dictation.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 96))
                    .foregroundColor(dictation.isRecording ? Color.red : Color.accentColor)
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(detail)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                if let error = dictation.lastError, !dictation.isSessionActive {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                if dictation.isRecording {
                    Button("Cancelar grabación", role: .destructive) {
                        dictation.cancelCapture()
                    }
                }
                if dictation.isSessionActive {
                    Button("Desactivar micrófono", role: .destructive) {
                        dictation.endSession()
                        dismiss()
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var title: String {
        if dictation.isRecording { return "Grabando para el teclado" }
        if dictation.isSessionActive { return "Micrófono listo" }
        return "Micrófono desactivado"
    }

    private var detail: String {
        if dictation.isSessionActive {
            return "Vuelve a la app en la que estabas escribiendo (toca «◀︎» arriba a la izquierda) y termina la grabación desde el teclado. El micrófono seguirá activo en segundo plano para los siguientes dictados."
        }
        return "Vuelve a tocar el botón de grabar en el teclado para activar el micrófono."
    }
}
