import SwiftUI

struct BrushColorSettings: View {
    @Binding var brush: Brush
    @State private var palette = ColorPalette.original

    private let swatchCount = 7
    private let touchSize: CGFloat = 44
    private let panelPadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 12) {
            Text("Цвет карандаша").font(.headline)
            HueRing(hue: visibleHue, color: Color(uiColor: brush.color))
            paletteChoices
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(touchSize), spacing: 0), count: swatchCount), spacing: 0) {
                ForEach(palette.swatches(for: brush)) { swatch in
                    colorButton(swatch)
                }
            }
            ToolSlider("Насыщенность", value: $brush.saturation, range: 0...1, percent: true)
            ToolSlider("Яркость", value: $brush.brightness, range: 0...1, percent: true)
        }
        .padding(panelPadding)
        .frame(width: CGFloat(swatchCount) * touchSize + 2 * panelPadding)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var paletteChoices: some View {
        HStack(spacing: 0) {
            ForEach(ColorPalette.allCases) { choice in
                Button {
                    palette = choice
                } label: {
                    Group {
                        if choice == .current {
                            Circle()
                                .fill(Color(hue: brush.hue, saturation: brush.saturation,
                                            brightness: brush.brightness))
                                .overlay(Circle().strokeBorder(NotebookTheme.border))
                        } else if let hue = choice.hue {
                            Circle().fill(Color(hue: hue, saturation: 0.8, brightness: 0.8))
                        } else {
                            Circle().fill(AngularGradient(colors: HueRing.spectrum, center: .center))
                        }
                    }
                    .frame(width: 23, height: 23)
                    .overlay {
                        if palette == choice {
                            Circle()
                                .strokeBorder(NotebookTheme.accent, lineWidth: 2)
                                .padding(-4)
                        }
                    }
                    .frame(width: touchSize, height: touchSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.rawValue)
                .accessibilityAddTraits(palette == choice ? .isSelected : [])
            }
        }
    }

    private var visibleHue: Binding<Double> {
        Binding(get: { brush.hue }, set: { hue in
            brush.hue = hue
            if brush.saturation == 0 {
                brush.saturation = 0.85
                brush.brightness = 0.85
            } else if brush.brightness == 0 {
                brush.brightness = 0.85
            }
        })
    }

    private func colorButton(_ swatch: ColorSwatch) -> some View {
        let selected = swatch.matches(brush)
        return Button {
            brush.hue = swatch.hue
            brush.saturation = swatch.saturation
            brush.brightness = swatch.brightness
        } label: {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hue: swatch.hue, saturation: swatch.saturation, brightness: swatch.brightness))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(selected ? NotebookTheme.accent : NotebookTheme.border,
                                      lineWidth: selected ? 2 : 1)
                }
                .frame(width: 31, height: 31)
                .frame(width: touchSize, height: touchSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(swatch.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}

private enum ColorPalette: String, CaseIterable, Identifiable {
    case red = "Красная гамма"
    case green = "Зелёная гамма"
    case blue = "Синяя гамма"
    case yellow = "Жёлтая гамма"
    case purple = "Фиолетовая гамма"
    case current = "Текущий цвет"
    case original = "Исходная палитра"

    var id: Self { self }

    var hue: Double? {
        switch self {
        case .green: 0.34
        case .blue: 0.60
        case .purple: 0.77
        case .red: 0.0
        case .yellow: 0.15
        case .current, .original: nil
        }
    }

    func swatches(for brush: Brush) -> [ColorSwatch] {
        guard self != .original else { return Self.originalSwatches }
        let hue = self.hue ?? brush.hue
        let isGrayscale = self == .current && brush.saturation == 0

        return (0..<14).map { index in
            let position = Double(index % 7) / 6
            let isLight = index < 7
            let saturation = isLight ? 0.12 + 0.74 * position : 0.88 + 0.10 * position
            return ColorSwatch(
                name: "\(rawValue), оттенок \(index + 1)",
                hue: hue,
                saturation: isGrayscale ? 0 : saturation,
                brightness: isLight ? 0.99 - 0.13 * position : 0.79 - 0.53 * position
            )
        }
    }

    private static let originalSwatches: [ColorSwatch] = {
        let names = ["Красный", "Оранжевый", "Жёлтый", "Лаймовый", "Зелёный", "Мятный",
                     "Бирюзовый", "Голубой", "Синий", "Фиолетовый", "Пурпурный", "Розовый"]
        return names.enumerated().map { index, name in
            ColorSwatch(name: name, hue: Double(index) / 12, saturation: 0.85, brightness: 0.85)
        } + [
            ColorSwatch(name: "Чёрный", hue: 0, saturation: 0, brightness: 0.12),
            ColorSwatch(name: "Белый", hue: 0, saturation: 0, brightness: 1)
        ]
    }()
}

private struct ColorSwatch: Identifiable {
    let name: String
    let hue: Double
    let saturation: Double
    let brightness: Double

    var id: String { name }

    func matches(_ brush: Brush) -> Bool {
        saturation == brush.saturation && brightness == brush.brightness &&
            (saturation == 0 || hue == brush.hue)
    }
}

struct PencilPresetSlots: View {
    @Binding var brush: Brush
    @Binding var selection: Int?
    @AppStorage("pencilPresetOne") private var first = Data()
    @AppStorage("pencilPresetTwo") private var second = Data()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Память карандаша").font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                slot(1, data: $first)
                slot(2, data: $second)
            }
        }
    }

    private func slot(_ number: Int, data: Binding<Data>) -> some View {
        let saved = try? JSONDecoder().decode(PencilPreset.self, from: data.wrappedValue)
        let selected = selection == number && saved?.width == brush.width && saved?.opacity == brush.opacity
        return Button {
            selection = number
            if let saved {
                brush.width = saved.width
                brush.opacity = saved.opacity
            } else {
                store(in: data)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Label("Ячейка \(number)", systemImage: saved == nil ? "plus" : "bookmark.fill")
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(NotebookTheme.accent)
                            .accessibilityHidden(true)
                    }
                }
                .font(.caption.weight(.semibold))
                Text(saved?.summary ?? "Записать")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 8)
            .background(selected ? NotebookTheme.selection : NotebookTheme.surface,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? NotebookTheme.accent : NotebookTheme.border,
                                  lineWidth: selected ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(saved == nil ? "Сохраняет текущие настройки" : "Применяет сохранённые настройки")
        .contextMenu {
            Button("Записать текущие настройки", systemImage: "square.and.arrow.down") {
                store(in: data)
                selection = number
            }
        }
    }

    private func store(in data: Binding<Data>) {
        let preset = PencilPreset(width: brush.width, opacity: brush.opacity)
        if let encoded = try? JSONEncoder().encode(preset) {
            data.wrappedValue = encoded
        }
    }
}

private struct PencilPreset: Codable {
    let width: Double
    let opacity: Double

    var summary: String {
        let thickness = width.formatted(.number.precision(.fractionLength(0...1)))
        let alpha = opacity.formatted(.percent.precision(.fractionLength(0)))
        return "\(thickness) пт · \(alpha)"
    }
}

struct ToolSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let percent: Bool

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, percent: Bool = false) {
        self.title = title
        _value = value
        self.range = range
        self.percent = percent
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(summary).monospacedDigit()
            }
            .font(.subheadline)
            .accessibilityHidden(true)
            Slider(value: $value, in: range) { Text(title) }
                .accessibilityValue(summary)
        }
    }

    private var summary: String {
        if percent {
            return value.formatted(.percent.precision(.fractionLength(0)))
        }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) пт"
    }
}

private struct HueRing: View {
    @Binding var hue: Double
    let color: Color
    private let size: CGFloat = 124
    private let band: CGFloat = 25

    var body: some View {
        let radius = (size - band) / 2
        let angle = hue * 2 * .pi
        ZStack {
            Circle()
                .fill(Color(uiColor: PageRenderer.paperColor))
                .overlay(Circle().fill(color))
                .overlay(Circle().strokeBorder(NotebookTheme.border))
                .frame(width: 52, height: 52)
                .allowsHitTesting(false)
            Circle()
                .strokeBorder(AngularGradient(colors: Self.spectrum, center: .center), lineWidth: band)
            Circle()
                .fill(Color(hue: hue, saturation: 1, brightness: 1))
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: 19, height: 19)
                .shadow(color: .black.opacity(0.35), radius: 2)
                .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            let x = drag.location.x - size / 2
            let y = drag.location.y - size / 2
            guard hypot(x, y) > 20 else { return }
            let turn = atan2(y, x) / (2 * .pi)
            hue = turn < 0 ? turn + 1 : turn
        })
        .accessibilityLabel("Оттенок")
        .accessibilityValue("\(Int(hue * 360))°")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: hue = (hue + 1.0 / 24).truncatingRemainder(dividingBy: 1)
            case .decrement: hue = (hue + 23.0 / 24).truncatingRemainder(dividingBy: 1)
            @unknown default: break
            }
        }
    }

    static let spectrum = (0...12).map {
        Color(hue: Double($0) / 12, saturation: 1, brightness: 1)
    }
}
