import SwiftUI
import SwiftData

/// Drag boxes into the order they appear across the top.
struct BoxOrderSheet: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Box.sortIndex), SortDescriptor(\Box.createdAt)]) private var boxes: [Box]

    var body: some View {
        List {
            ForEach(boxes) { box in
                Text(box.name)
                    .font(Typeface.body)
                    .foregroundStyle(Theme.ink)
                    .listRowBackground(Theme.surface)
            }
            .onMove(perform: move)
        }
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .fadingBar(.top) {
            SheetHeader(title: "Box order")
        }
        .background(Theme.canvas)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = boxes
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, box) in ordered.enumerated() { box.sortIndex = index }
        try? context.save()
    }
}
