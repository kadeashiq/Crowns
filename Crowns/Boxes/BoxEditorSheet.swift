import SwiftUI
import SwiftData

/// Name and columns for a box. `box` nil creates a new one.
struct BoxEditorSheet: View {
    let box: Box?
    /// Called with the box that was saved, or nil if cancelled or deleted.
    let onDone: (Box?) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    @State private var name = ""
    @State private var columns = 2
    @State private var confirmDelete = false

    private var watchCount: Int { box?.watches?.count ?? 0 }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: box == nil ? "New box" : "Edit box") {
                Button("Save", action: save)
                    .buttonStyle(.pill(.primary, size: .small))
                    .disabled(!canSave)
            }

            ScrollView {
                VStack(spacing: Space.lg) {
                    FormSection(title: "Name") {
                        TextField("Name", text: $name)
                            .textInputAutocapitalization(.words)
                            .filledField()
                    }

                    FormSection(title: "Layout") {
                        CountStepper(title: "Columns", value: $columns, range: 1...4)
                    }

                    if let box, boxes.count > 1 {
                        VStack(spacing: Space.xs) {
                            Button("Delete box") { confirmDelete = true }
                                .buttonStyle(.pill(.secondary))
                                .disabled(watchCount > 0)
                            if watchCount > 0 {
                                Text("Move its watches first.")
                                    .font(Typeface.caption)
                                    .foregroundStyle(Theme.inkTertiary)
                            }
                        }
                        .confirmationDialog("Delete \(box.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) { delete(box) }
                        }
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.xs)
                .padding(.bottom, Space.xl)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.canvas)
        .onAppear {
            guard let box else { return }
            name = box.name
            columns = box.columns
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let target: Box
        if let box {
            target = box
        } else {
            target = Box(name: trimmed, sortIndex: (boxes.map(\.sortIndex).max() ?? -1) + 1)
            context.insert(target)
        }
        target.name = trimmed
        target.columns = columns
        target.compactSlots()
        try? context.save()
        onDone(target)
    }

    private func delete(_ box: Box) {
        context.delete(box)
        try? context.save()
        onDone(nil)
    }
}
