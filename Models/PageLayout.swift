import Foundation

enum PageLayout {
    static let bounds = CGRect(x: 0, y: 0, width: 680, height: 880)

    static let coverLabelBounds = CGRect(x: 0, y: 0, width: bounds.width, height: 500)

    static func fit(_ size: CGSize) -> CGRect {
        let page = bounds
        let scale = min(page.width / size.width, page.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: (page.width - width) / 2, y: (page.height - height) / 2,
                      width: width, height: height)
    }
}
