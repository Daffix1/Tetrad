import Foundation

struct Brush: Codable {
    var hue = 0.61
    var saturation = 0.65
    var brightness = 0.35
    var width = 2.4
    var opacity = 1.0
}

struct Stroke: Codable {
    let points: [Point]
    let brush: Brush
    var erases: Bool? = nil
    var eraserWidth: Double? = nil
}

struct Point: Codable {
    let x: CGFloat
    let y: CGFloat

    init(_ point: CGPoint) {
        x = point.x
        y = point.y
    }

    var location: CGPoint { CGPoint(x: x, y: y) }
}
