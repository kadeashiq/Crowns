import SwiftUI

/// The boxes, as chips across the top. Long-press a chip to edit its box.
struct BoxChips: View {
    let boxes: [Box]
    let selectedID: UUID?
    let onSelect: (Box) -> Void
    let onAdd: () -> Void
    let onEdit: (Box) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(boxes) { box in
                        chip(box)
                            .id(box.id)
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.05), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New box")
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedID) { _, id in
                guard let id else { return }
                withAnimation(Motion.standard) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func chip(_ box: Box) -> some View {
        let selected = box.id == selectedID
        return Button {
            onSelect(box)
        } label: {
            Text(box.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(selected ? Theme.ink : Theme.inkSecondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(selected ? Theme.brass.opacity(0.2) : Color.white.opacity(0.05), in: .capsule)
                .overlay(Capsule().strokeBorder(selected ? Theme.brass.opacity(0.5) : .clear, lineWidth: 0.6))
                .animation(Motion.standard, value: selected)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit box") { onEdit(box) }
        }
    }
}
