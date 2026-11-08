import SwiftUI
import SwiftData

/// Name, grid size and finish for a box. `box` nil creates a new one.
struct BoxEditorSheet: View {
    let box: Box?
    /// Called with the box that was saved, or nil if cancelled or deleted.
    let onDone: (Box?) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    @State private var name = ""
    @State private var columns = 2
    @State private var rows = 3
    @State private var finish: BoxFinish = .walnut
    @State private var confirmDelete = false

    private var watchCount: Int { box?.watches?.count ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WatchBoxView(name: name.isEmpty ? "Box" : name, finish: finish, seed: box?.id ?? previewSeed, columns: columns, rows: rows, width: previewWidth) { _ in
                        EmptyView()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .animation(Motion.standard, value: columns)
                    .animation(Motion.standard, value: rows)
                    .animation(Motion.standard, value: finish)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Stepper("Columns  \(columns)", value: $columns, in: 1...4)
                    Stepper("Rows  \(rows)", value: $rows, in: 1...10)
                }

                Section("Finish") {
                    HStack(spacing: 14) {
                        ForEach(BoxFinish.allCases) { option in
                            Button {
                                Haptics.tick()
                                finish = option
                            } label: {
                                VStack(spacing: 6) {
                                    let palette = FinishPalette.for(option)
                                    Circle()
                                        .fill(LinearGradient(colors: [palette.woodLight, palette.woodDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .overlay(Circle().fill(palette.suede).padding(10))
                                        .overlay(Circle().strokeBorder(Theme.brass, lineWidth: finish == option ? 2 : 0))
                                        .frame(width: 44, height: 44)
                                    Text(option.title)
                                        .font(.caption)
                                        .foregroundStyle(finish == option ? Theme.ink : Theme.inkSecondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if let box, boxes.count > 1 {
                    Section {
                        Button("Delete box", role: .destructive) { confirmDelete = true }
                            .disabled(watchCount > 0)
                    } footer: {
                        if watchCount > 0 { Text("Move its watches first.") }
                    }
                    .confirmationDialog("Delete \(box.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) { delete(box) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.desk)
            .navigationTitle(box == nil ? "New box" : "Edit box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDone(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            guard let box else { return }
            name = box.name
            columns = box.columns
            rows = box.rows
            finish = box.finish
        }
    }

    @State private var previewSeed = UUID()
    private var previewWidth: CGFloat { columns >= 3 ? 250 : 200 }

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
        target.rows = rows
        target.finish = finish
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
