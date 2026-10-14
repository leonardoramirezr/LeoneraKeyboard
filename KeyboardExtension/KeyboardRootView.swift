import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var state: KeyboardState
    let dictation: DictationController
    let perform: (KeyAction) -> Void

    var body: some View {
        Group {
            if state.showingDictation {
                DictationPanel(state: state, dictation: dictation, perform: perform)
            } else if state.showingEmoji {
                EmojiPanel(state: state, perform: perform)
            } else {
                KeyboardGrid(rows: state.rows, rowHeight: state.rowHeight) { key in
                    KeyCell(key: key, state: state, perform: perform)
                }
            }
        }
        .padding(.horizontal, KeyboardMetrics.horizontalPadding)
        .padding(.vertical, KeyboardMetrics.verticalPadding)
        .frame(height: state.keyboardHeight)
        .frame(maxWidth: .infinity)
    }
}

/// Una tecla interactiva: tocar ejecuta la acción principal y deslizar hacia
/// abajo ejecuta la secundaria. Vibra al tocarla, antes de saber cuál de las dos
/// se ejecutará. Las teclas de borrar o mover el cursor se repiten mientras se
/// mantienen pulsadas. Mantener pulsada la barra espaciadora activa el modo
/// trackpad: el teclado se queda vacío y arrastrar a izquierda o derecha mueve
/// el cursor.
struct KeyCell: View {
    let key: KeyDefinition
    @ObservedObject var state: KeyboardState
    let perform: (KeyAction) -> Void

    @State private var isPressed = false
    @State private var isSwiping = false
    @State private var didRepeat = false
    @State private var repeatTimer: Timer?
    @State private var trackpadTimer: Timer?
    @State private var isTrackpad = false
    /// Desplazamiento horizontal del dedo en el último evento del gesto.
    @State private var dragX: CGFloat = 0
    /// Posición horizontal a partir de la cual se cuenta el siguiente movimiento del cursor.
    @State private var trackpadAnchorX: CGFloat = 0

    /// Tiempo que hay que mantener pulsada la barra espaciadora para activar el trackpad.
    private static let trackpadDelay: TimeInterval = 0.4

    init(key: KeyDefinition, state: KeyboardState, perform: @escaping (KeyAction) -> Void) {
        self.key = key
        _state = ObservedObject(wrappedValue: state)
        self.perform = perform
    }

    var body: some View {
        KeyCapView(
            key: key,
            shift: state.shift,
            showLowercase: state.settings.showLowercase,
            isPressed: isPressed,
            isSwiping: isSwiping,
            isBlank: state.isTrackpadActive,
            rowHeight: state.rowHeight
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    dragX = value.translation.width
                    if !isPressed {
                        isPressed = true
                        state.playKeyFeedback()
                        startRepeatingIfNeeded()
                        startTrackpadTimerIfNeeded()
                    }
                    if isTrackpad {
                        moveCursor()
                        return
                    }
                    let swiping = isSwipe(value.translation)
                    if swiping != isSwiping {
                        isSwiping = swiping
                        if swiping {
                            stopRepeating()
                            stopTrackpadTimer()
                        }
                    }
                }
                .onEnded { value in
                    stopRepeating()
                    stopTrackpadTimer()
                    if isTrackpad {
                        endTrackpad()
                    } else if isSwipe(value.translation), let secondary = key.secondary {
                        perform(secondary)
                    } else if !didRepeat {
                        perform(key.primary)
                    }
                    isPressed = false
                    isSwiping = false
                    didRepeat = false
                }
        )
        .onDisappear {
            stopRepeating()
            stopTrackpadTimer()
            if isTrackpad { endTrackpad() }
        }
    }

    private func isSwipe(_ translation: CGSize) -> Bool {
        guard let secondary = key.secondary, secondary.type != .none else { return false }
        return translation.height > CGFloat(state.settings.swipeThreshold)
    }

    private func startRepeatingIfNeeded() {
        guard key.primary.type.repeatsWhileHeld else { return }
        stopRepeating()
        let action = key.primary
        let timer = Timer(fire: Date().addingTimeInterval(0.45), interval: 0.08, repeats: true) { _ in
            didRepeat = true
            state.playKeyFeedback()
            perform(action)
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    // MARK: - Trackpad

    private func startTrackpadTimerIfNeeded() {
        guard key.primary.type == .space else { return }
        stopTrackpadTimer()
        let timer = Timer(timeInterval: Self.trackpadDelay, repeats: false) { _ in
            trackpadTimer = nil
            guard isPressed, !isSwiping else { return }
            isTrackpad = true
            trackpadAnchorX = dragX
            state.isTrackpadActive = true
            state.playKeyFeedback()
        }
        RunLoop.main.add(timer, forMode: .common)
        trackpadTimer = timer
    }

    private func stopTrackpadTimer() {
        trackpadTimer?.invalidate()
        trackpadTimer = nil
    }

    /// Mueve el cursor un carácter por cada tramo que el dedo se ha desplazado desde
    /// el último movimiento. El tamaño del tramo depende de la sensibilidad.
    private func moveCursor() {
        let step = CGFloat(state.settings.cursorPointsPerCharacter)
        let steps = Int((dragX - trackpadAnchorX) / step)
        guard steps != 0 else { return }
        trackpadAnchorX += CGFloat(steps) * step
        let action = KeyAction(steps < 0 ? .cursorLeft : .cursorRight)
        for _ in 0..<abs(steps) {
            perform(action)
        }
    }

    private func endTrackpad() {
        isTrackpad = false
        state.isTrackpadActive = false
    }
}
