import SwiftUI

/// The boxes, as chips across the top. Long-press a chip to edit its box.
struct BoxChips: View {
    let boxes: [Box]
    let selectedID: UUID?
    let onSelect: (Box) -> Void
    let onAdd: () -> Void
    let onEdit: (Box) -> Void
    let onReorder: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Space.xs) {
                    ForEach(boxes) { box in
                        ChipButton(title: box.name, selected: box.id == selectedID) {
                            onSelect(box)
                        }
                        .contextMenu {
                            Button("Edit box") { onEdit(box) }
                            if boxes.count > 1 {
                                Button("Reorder boxes", action: onReorder)
                            }
                        }
                        // Keeps the next chip's shadow off the selected one.
                        .zIndex(box.id == selectedID ? 1 : 0)
                        .id(box.id)
                    }
                    Menu {
                        Button("New box", systemImage: "plus", action: onAdd)
                        if boxes.count > 1 {
                            Button("Reorder boxes", systemImage: "arrow.up.arrow.down", action: onReorder)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .buttonStyle(.circle(diameter: 40))
                    .accessibilityLabel("Box options")
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}
