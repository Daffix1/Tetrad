import SwiftUI

struct EditorTools: View {
    @Binding var brush: Brush
    @Binding var isErasing: Bool
    @Binding var openPanel: Panel?

    enum Panel {
        case color, pencil, eraser
    }

    var body: some View {
        HStack(spacing: 4) {
            colorButton

            tool("Карандаш", icon: "pencil", selected: !isErasing) {
                isErasing = false
                toggle(.pencil)
            }

            tool("Ластик", icon: "eraser", selected: isErasing) {
                isErasing = true
                toggle(.eraser)
            }
        }
    }

    private var colorButton: some View {
        Button {
            toggle(.color)
        } label: {
            Circle()
                .fill(Color(uiColor: PageRenderer.paperColor))
                .overlay(Circle().fill(Color(uiColor: brush.color)))
                .overlay(Circle().strokeBorder(NotebookTheme.border))
                .frame(width: 22, height: 22)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Цвет карандаша")
        .help("Цвет карандаша")
    }

    private func toggle(_ panel: Panel) {
        openPanel = openPanel == panel ? nil : panel
    }

    private func tool(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                .background(selected ? NotebookTheme.selection : .clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .help(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct EditorToolSettings: View {
    let panel: EditorTools.Panel
    @Binding var brush: Brush
    @Binding var eraserWidth: Double
    @Binding var selectedPreset: Int?

    var body: some View {
        settings
            .background(NotebookTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(NotebookTheme.border)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 5)
    }

    @ViewBuilder
    private var settings: some View {
        switch panel {
        case .color:
            BrushColorSettings(brush: $brush)
        case .pencil:
            VStack(spacing: 12) {
                ToolSlider("Толщина карандаша", value: $brush.width, range: 1...24)
                ToolSlider("Непрозрачность", value: $brush.opacity, range: 0.05...1, percent: true)
                strokePreview(width: brush.width, color: Color(uiColor: brush.color))
                PencilPresetSlots(brush: $brush, selection: $selectedPreset)
            }
            .padding(16)
            .frame(width: 288)
        case .eraser:
            VStack(spacing: 12) {
                ToolSlider("Толщина ластика", value: $eraserWidth, range: 4...64)
                strokePreview(width: eraserWidth, color: NotebookTheme.selection, outlined: true)
            }
            .padding(16)
            .frame(width: 288)
        }
    }

    private func strokePreview(width: Double, color: Color, outlined: Bool = false) -> some View {
        Capsule()
            .fill(color)
            .overlay {
                if outlined { Capsule().strokeBorder(NotebookTheme.accent) }
            }
            .frame(width: 100, height: width)
            .frame(maxWidth: .infinity)
            .frame(height: outlined ? 72 : 42)
            .background(Color(uiColor: PageRenderer.paperColor), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}
