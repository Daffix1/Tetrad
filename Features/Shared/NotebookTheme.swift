import SwiftUI

enum NotebookTheme {
    static let background = adaptive(light: 0xEFE9DF, dark: 0x242720)
    static let surface = adaptive(light: 0xFCF8F1, dark: 0x30342B)
    static let ink = adaptive(light: 0x252B24, dark: 0xF0EDE4)
    static let accent = adaptive(light: 0x385444, dark: 0xAFD5BB)
    static let primaryButton = adaptive(light: 0x385444, dark: 0x466550)
    static let selection = adaptive(light: 0xDCE8DA, dark: 0x35493D)
    static let border = adaptive(light: 0xD9D1C3, dark: 0x53594B)

    static func coverColor(for notebookID: UUID) -> Color {
        let colors = [Color(red: 0.22, green: 0.33, blue: 0.47),
                      Color(red: 0.43, green: 0.22, blue: 0.26),
                      Color(red: 0.22, green: 0.36, blue: 0.31),
                      Color(red: 0.40, green: 0.29, blue: 0.19)]
        return colors[Int(notebookID.uuid.0) % colors.count]
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
}
