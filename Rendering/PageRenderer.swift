import UIKit

enum PageRenderer {
    static let bounds = PageLayout.bounds
    static let paperColor = UIColor(red: 1, green: 0.99, blue: 0.96, alpha: 1)

    static func image(key: String, style: PaperStyle, scale: CGFloat,
                      storage: PageStorage = .standard) -> UIImage {
        rasterImage(in: bounds, scale: scale, style: style, strokes: storage.loadStrokes(key),
                    attachment: storage.attachmentImage(for: key))
    }

    static func coverPreview(key: String, storage: PageStorage = .standard) -> UIImage? {
        let strokes = storage.loadStrokes(key)
        guard strokes.contains(where: { $0.erases != true }) else { return nil }
        return rasterImage(in: PageLayout.coverLabelBounds, scale: 0.6, style: .blank,
                           strokes: strokes, background: nil)
    }

    private static func rasterImage(in bounds: CGRect, scale: CGFloat, style: PaperStyle,
                                    strokes: [Stroke], attachment: UIImage? = nil,
                                    background: UIColor? = paperColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = background != nil
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { render in
            if let background {
                background.setFill()
                render.fill(bounds)
            }
            draw(in: render.cgContext, style: style, strokes: strokes, attachment: attachment)
        }
    }

    static func draw(in context: CGContext, style: PaperStyle, strokes: [Stroke], attachment: UIImage? = nil, draft: Stroke? = nil) {
        if attachment == nil {
            drawGuides(style, in: context)
        }

        if let attachment { attachment.draw(in: PageLayout.fit(attachment.size)) }

        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for stroke in strokes { draw(stroke, in: context) }
        if let draft { draw(draft, in: context) }
        context.setBlendMode(.normal)
        context.endTransparencyLayer()
    }

    private static let guideColor = UIColor(red: 0.85, green: 0.87, blue: 0.89, alpha: 1).cgColor
    private static let guideSpacing: CGFloat = 28 / 1.5
    private static let gridColumns = centeredGuides(from: bounds.minX, length: bounds.width)
    private static let gridRows = centeredGuides(from: bounds.minY, length: bounds.height)

    private static let gridPattern: CGPath = {
        let path = CGMutablePath()
        guard let left = gridColumns.first, let right = gridColumns.last,
              let top = gridRows.first, let bottom = gridRows.last else { return path }

        for x in gridColumns {
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
        for y in gridRows {
            path.move(to: CGPoint(x: left, y: y))
            path.addLine(to: CGPoint(x: right, y: y))
        }
        return path
    }()

    private static let dotPattern: CGPath = {
        let path = CGMutablePath()
        for y in gridRows {
            for x in gridColumns {
                path.addEllipse(in: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1))
            }
        }
        return path
    }()

    private static func centeredGuides(from origin: CGFloat, length: CGFloat) -> [CGFloat] {
        let cells = Int((length / guideSpacing).rounded(.down))
        let margin = (length - CGFloat(cells) * guideSpacing) / 2
        return (0...cells).map { origin + margin + CGFloat($0) * guideSpacing }
    }

    private static func drawGuides(_ style: PaperStyle, in context: CGContext) {
        context.setStrokeColor(guideColor)
        context.setLineWidth(0.5)
        switch style {
        case .ruled:
            for y in stride(from: CGFloat(32), to: bounds.height, by: guideSpacing) {
                context.move(to: CGPoint(x: bounds.minX, y: y))
                context.addLine(to: CGPoint(x: bounds.maxX, y: y))
            }
            context.strokePath()
        case .grid:
            context.addPath(gridPattern)
            context.strokePath()
        case .dots:
            context.setFillColor(guideColor)
            context.addPath(dotPattern)
            context.fillPath()
        case .blank:
            break
        }
    }

    private static func draw(_ stroke: Stroke, in context: CGContext) {
        guard !stroke.points.isEmpty else { return }
        let erases = stroke.erases == true
        context.setBlendMode(erases ? .clear : .normal)
        context.setStrokeColor(erases ? UIColor.black.cgColor : stroke.brush.color.cgColor)
        context.setLineWidth(erases ? (stroke.eraserWidth ?? 16) : stroke.brush.width)
        context.addPath(stroke.path)
        context.strokePath()
    }
}

extension Brush {
    var color: UIColor {
        UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: opacity)
    }
}

private extension Stroke {
    var path: CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first.location)
        path.addLine(to: CGPoint(x: first.x + 0.001, y: first.y))
        for point in points.dropFirst() { path.addLine(to: point.location) }
        return path
    }
}

extension PageStorage {
    func attachmentImage(for key: String) -> UIImage? {
        UIImage(contentsOfFile: attachmentURL(for: key).path)
    }
}
