import SwiftUI

struct NotebookCover: View {
    let notebook: Notebook
    @State private var handwriting: UIImage?

    var body: some View {
        cover
            .padding(.trailing, 5)
            .padding(.bottom, 5)
            .background(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color(red: 0.91, green: 0.87, blue: 0.79))
                    .padding(.leading, 10)
                    .padding(.top, 8)
            }
            .shadow(color: .black.opacity(0.17), radius: 8, x: 2, y: 6)
            .accessibilityElement(children: .combine)
            .task(id: notebook.coverStorageKey) {
                handwriting = PageRenderer.coverPreview(key: notebook.coverStorageKey)
            }
    }

    private var cover: some View {
        RoundedRectangle(cornerRadius: 11)
            .fill(NotebookTheme.coverColor(for: notebook.id).gradient)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .frame(width: 13)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    if let handwriting {
                        Image(uiImage: handwriting)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 4))
                            .padding(.top, 42)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 4)
                    Text(notebook.title)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .lineLimit(3)
                    Text(notebook.paperStyle.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Листов: \(notebook.pageCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)
                .padding(.leading, 25)
                .padding(.trailing, 12)
                .padding(.bottom, 16)
            }
            .clipShape(.rect(cornerRadius: 11))
            .aspectRatio(0.77, contentMode: .fit)
    }
}
