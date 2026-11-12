import SwiftUI

struct NotebookSettingsForm: View {
    let title: String
    let actionTitle: String
    let save: (String, PaperStyle) -> Void

    @State var name = ""
    @State var paper = PaperStyle.ruled
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Название", text: $name)
                Picker("Бумага", selection: $paper) {
                    ForEach(PaperStyle.allCases, id: \.self) { Text($0.rawValue) }
                }
            }
            .navigationTitle(title)
            .toolbar {
                Button("Отмена") { dismiss() }
                Button(actionTitle) {
                    dismiss()
                    save(name, paper)
                }
            }
        }
    }
}
