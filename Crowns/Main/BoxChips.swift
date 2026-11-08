import SwiftUI

/// The boxes, as chips across the top. Long-press a chip to edit its box.
struct BoxChips: View {
    let boxes: [Box]
    let selectedID: UUID?
    let onSelect: (Box) -> Void
    let onAdd: () -> Void
    let onEdit: (Box) -> Void
    let onReorder: () -> Void

    @Namespace private var selection

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: Space.xs) {
                    ForEach(boxes) { box in
                        Button {
                            onSelect(box)
                        } label: {
                            Chip(title: box.name, selected: box.id == selectedID, namespace: selection)
                        }
                        .buttonStyle(PressableStyle())
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
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.circle(diameter: 40))
                    .accessibilityLabel("New box")
                    if boxes.count > 1 {
                        Button(action: onReorder) {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .buttonStyle(.circle(diameter: 40))
                        .accessibilityLabel("Reorder boxes")
                    }
                }
                .animation(Motion.selection, value: selectedID)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.sm)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}
