import SwiftUI

struct KeyboardRootView: View {
    @ObservedObject var state: KeyboardState
    let perform: (KeyAction) -> Void

    var body: some View {
        Group {
            if state.showingEmoji {
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
/// abajo ejecuta la secundaria. Las teclas de borrar o mover el cursor se repiten
/// mientras se mantienen pulsadas.
struct KeyCell: View {
    let key: KeyDefinition
    @ObservedObject var state: KeyboardState
    let perform: (KeyAction) -> Void

    @State private var isPressed = false
    @State private var isSwiping = false
    @State private var didRepeat = false
    @State private var repeatTimer: Timer?

    var body: some View {
        KeyCapView(
            key: key,
            shift: state.shift,
            showLowercase: state.settings.showLowercase,
            isPressed: isPressed,
            isSwiping: isSwiping,
            rowHeight: state.rowHeight
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        startRepeatingIfNeeded()
                    }
                    let swiping = isSwipe(value.translation)
                    if swiping != isSwiping {
                        isSwiping = swiping
                        if swiping { stopRepeating() }
                    }
                }
                .onEnded { value in
                    stopRepeating()
                    if isSwipe(value.translation), let secondary = key.secondary {
                        perform(secondary)
                    } else if !didRepeat {
                        perform(key.primary)
                    }
                    isPressed = false
                    isSwiping = false
                    didRepeat = false
                }
        )
        .onDisappear(perform: stopRepeating)
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
            perform(action)
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
