import SwiftUI

struct GlassButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let accent = AppSettings.shared.accentColor
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(prominent ? Color.white : accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(prominent ? accent : accent.opacity(0.14))
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct GlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let accent = AppSettings.shared.accentColor
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                Capsule(style: .continuous)
                    .fill(accent)
            }
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    static func glass(prominent: Bool = false) -> GlassButtonStyle {
        GlassButtonStyle(prominent: prominent)
    }
}

extension ButtonStyle where Self == GlassProminentButtonStyle {
    static func glassProminentButton() -> GlassProminentButtonStyle { GlassProminentButtonStyle() }
}

struct FormActionButton: View {
    @Bindable private var settings = AppSettings.shared

    let title: String
    let systemImage: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(settings.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    Capsule(style: .continuous)
                        .fill(settings.accentColor.opacity(0.14))
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

enum ToolbarIcon {
    static func cancel(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
        }
        .accessibilityLabel(String(localized: "Cancel"))
    }

    static func back(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
        }
        .accessibilityLabel(String(localized: "Back"))
    }

    static func done(_ action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: "checkmark")
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
        .accessibilityLabel(String(localized: "Done"))
    }

    static func save(_ action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: "checkmark")
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
        .accessibilityLabel(String(localized: "Save"))
    }

    static func confirm(
        _ action: @escaping () -> Void,
        systemImage: String = "checkmark",
        label: String = String(localized: "Confirm"),
        disabled: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(.borderedProminent)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    static func edit(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "pencil")
        }
        .accessibilityLabel(String(localized: "Edit"))
    }

    static func delete(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash")
        }
        .accessibilityLabel(String(localized: "Delete"))
    }

    static func add(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(String(localized: "Add"))
    }
}

struct FormLeadingToolbar: ToolbarContent {
    var onCancel: (() -> Void)?
    var showDelete = false
    var onDelete: (() -> Void)?
    var onSave: () -> Void
    var saveDisabled = false

    var body: some ToolbarContent {
        if let onCancel {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIcon.cancel(onCancel)
            }
        }
        if showDelete, let onDelete {
            // Keep delete off the leading cluster so cancel stays isolated on the far left.
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarIcon.delete(onDelete)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            ToolbarIcon.save(onSave, disabled: saveDisabled)
        }
    }
}

struct DeleteLeadingToolbar: ToolbarContent {
    var onDelete: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ToolbarIcon.delete(onDelete)
        }
    }
}

struct RowAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () -> Void
}

extension View {
    func rowContextMenu<Preview: View>(
        @ViewBuilder preview: @escaping () -> Preview,
        actions: [RowAction]
    ) -> some View {
        contextMenu {
            ForEach(actions) { action in
                Button(role: action.role, action: action.action) {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        } preview: {
            preview()
                .background { AccentScreenBackground() }
        }
    }

    func editDeleteSwipe(onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .tint(.blue)
            .accessibilityLabel(String(localized: "Edit"))

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .tint(.red)
            .accessibilityLabel(String(localized: "Delete"))
        }
    }

    func completeSwipe(_ action: @escaping () -> Void, systemImage: String = "checkmark") -> some View {
        swipeActions(edge: .leading) {
            Button(action: action) {
                Image(systemName: systemImage)
            }
            .tint(.green)
            .accessibilityLabel(String(localized: "Complete"))
        }
    }
}
