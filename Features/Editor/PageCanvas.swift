import SwiftUI
import UIKit

struct PageCanvas: UIViewRepresentable {
    let storageKey: String
    let brush: Brush

    let isErasing: Bool
    let style: PaperStyle
    let eraserWidth: Double
    var transparentBackground = false
    @ObservedObject var edits: PageEdits
    let turnPage: (Int) -> Void
    let onPaperInteraction: () -> Void

    func makeUIView(context: Context) -> StylusCanvasView {
        StylusCanvasView(storageKey: storageKey, edits: edits, transparentBackground: transparentBackground)
    }

    func updateUIView(_ view: StylusCanvasView, context: Context) {
        view.turnPage = turnPage
        view.onPaperInteraction = onPaperInteraction
        view.brush = brush
        view.isErasing = isErasing
        view.style = style
        view.eraserWidth = eraserWidth
        view.refreshEdits()
        view.redrawInk()
    }
}

final class StylusCanvasView: UIView {
    var turnPage: ((Int) -> Void)?
    var onPaperInteraction: (() -> Void)?
    private let storageKey: String
    private let edits: PageEdits
    private var revision: Int
    var brush = Brush()
    var isErasing = false
    var style = PaperStyle.ruled
    var eraserWidth = 16.0
    private var draftEraserWidth = 16.0
    private var erasingPass = false

    private var draftBrush = Brush()
    private var strokes: [Stroke] = []
    private var attachmentView: UIImageView?
    private let inkView = CanvasInkView()
    private var draft: [Point] = []
    private var pen: UITouch?

    init(storageKey: String, edits: PageEdits, transparentBackground: Bool) {
        self.storageKey = storageKey
        self.edits = edits
        revision = edits.revision
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        isOpaque = !transparentBackground
        backgroundColor = transparentBackground ? .clear : PageRenderer.paperColor
        clipsToBounds = true
        strokes = PageStorage.standard.loadStrokes(storageKey)
        if let attachment = PageStorage.standard.attachmentImage(for: storageKey) {
            let imageView = UIImageView(image: attachment)
            imageView.contentMode = .scaleAspectFit
            imageView.isUserInteractionEnabled = false
            addSubview(imageView)
            attachmentView = imageView
        }

        // Keep the imported image in its own layer while the stylus redraws the ink.
        inkView.backgroundColor = .clear
        inkView.isOpaque = false
        inkView.contentMode = .redraw
        inkView.isUserInteractionEnabled = false
        inkView.render = { [weak self] context in self?.drawInk(in: context) }
        addSubview(inkView)

        let undo = UITapGestureRecognizer(target: self, action: #selector(undoStroke))
        undo.numberOfTouchesRequired = 2
        undo.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        undo.cancelsTouchesInView = false
        addGestureRecognizer(undo)

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapPaper))
        tap.allowedTouchTypes = undo.allowedTouchTypes
        tap.cancelsTouchesInView = false
        tap.require(toFail: undo)
        addGestureRecognizer(tap)

        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipePage(_:)))
            swipe.direction = direction
            swipe.numberOfTouchesRequired = 1
            swipe.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            swipe.cancelsTouchesInView = false
            swipe.require(toFail: undo)
            addGestureRecognizer(swipe)
        }
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachmentView?.frame = bounds
        inkView.frame = bounds
    }

    func redrawInk() {
        inkView.setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard pen == nil, let touch = touches.first(where: { $0.type == .pencil }) else { return }
        draftBrush = brush
        erasingPass = isErasing
        draftEraserWidth = eraserWidth
        pen = touch
        edits.setDrawing(true, for: storageKey)
        appendSamples(for: touch, event: event)
        onPaperInteraction?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pen, touches.contains(pen) else { return }
        appendSamples(for: pen, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pen, touches.contains(pen) else { return }
        appendSamples(for: pen, event: event)
        if !draft.isEmpty {
            edits.commit(draftStroke, to: storageKey)
        }
        clearDraft()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pen, touches.contains(pen) else { return }
        clearDraft()
    }

    private func appendSamples(for touch: UITouch, event: UIEvent?) {
        let samples = event?.coalescedTouches(for: touch) ?? [touch]
        draft.append(contentsOf: samples.map { Point($0.preciseLocation(in: self)) })
        redrawInk()
    }

    private var draftStroke: Stroke {
        Stroke(points: draft, brush: draftBrush, erases: erasingPass ? true : nil,
               eraserWidth: erasingPass ? draftEraserWidth : nil)
    }

    private func clearDraft() {
        pen = nil
        edits.setDrawing(false, for: storageKey)
        refreshEdits()
        draft.removeAll(keepingCapacity: true)
        redrawInk()
    }

    @objc private func tapPaper() {
        onPaperInteraction?()
    }

    @objc private func swipePage(_ gesture: UISwipeGestureRecognizer) {
        guard pen == nil else { return }
        onPaperInteraction?()
        turnPage?(gesture.direction == .left ? 1 : -1)
    }

    @objc private func undoStroke() {
        edits.undo(storageKey)
        refreshEdits()
        redrawInk()
    }

    func refreshEdits() {
        guard revision != edits.revision else { return }
        revision = edits.revision
        strokes = PageStorage.standard.loadStrokes(storageKey)
    }

    private func drawInk(in context: CGContext) {
        let paperStyle = attachmentView == nil ? style : .blank
        PageRenderer.draw(in: context, style: paperStyle, strokes: strokes, draft: draftStroke)
        drawEraserOutline(in: context)
    }

    private func drawEraserOutline(in context: CGContext) {
        guard pen != nil, erasingPass, let tip = draft.last?.location else { return }
        let diameter = CGFloat(draftEraserWidth)
        let outline = CGRect(x: tip.x - diameter / 2, y: tip.y - diameter / 2,
                             width: diameter, height: diameter)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.5)
        context.strokeEllipse(in: outline)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.75).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: outline)
    }
}


private final class CanvasInkView: UIView {
    var render: ((CGContext) -> Void)?

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        render?(context)
    }
}
