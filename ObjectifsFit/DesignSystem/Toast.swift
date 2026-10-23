import SwiftUI
import SwiftData

/// Messages de confirmation éphémères (« Série ajoutée »...), affichés en pastille au-dessus de la
/// barre d'onglets. Les suppressions passent `undo` pour proposer « Annuler » pendant quelques
/// secondes, plutôt que de demander une confirmation avant.
@Observable
final class ToastCenter {
    struct Toast: Identifiable {
        let id = UUID()
        let message: String
        let undo: (() -> Void)?
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, undo: (() -> Void)? = nil) {
        dismissTask?.cancel()
        current = Toast(message: message, undo: undo)
        let duration: Double = undo == nil ? 2.5 : 5
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    /// Suppression annulable : « Annuler » rejoue l'`UndoManager` du contexte SwiftData.
    func showDeleted(_ message: String, context: ModelContext) {
        show(message) { context.undoManager?.undo() }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

private struct ToastOverlay: ViewModifier {
    @Environment(ToastCenter.self) private var center

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = center.current {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.app(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color(hex: "3E9B88"))
                            .clipShape(Circle())
                        Text(toast.message)
                            .font(.app(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        if let undo = toast.undo {
                            Spacer(minLength: 12)
                            Button {
                                undo()
                                center.dismiss()
                            } label: {
                                Text("Annuler")
                                    .font(.app(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "FFB48F"))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "2A2521"), in: Capsule())
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 84)
                    .id(toast.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: center.current?.id)
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlay()) }
}
