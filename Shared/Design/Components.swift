import SwiftUI

/// Content on a raised card.
struct Card<Content: View>: View {
    var padding: CGFloat = Space.md
    var radius: CGFloat = Radius.lg
    var elevation: Elevation = .low
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .surface(radius: radius, elevation: elevation)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typeface.label)
            .foregroundStyle(Theme.inkSecondary)
            .padding(.horizontal, Space.xxs)
    }
}

/// A titled card for forms and settings.
struct FormSection<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    var padding: CGFloat = Space.sm
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if let title { SectionLabel(text: title) }
            Card(padding: padding) { content() }
            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(Typeface.caption)
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, Space.xxs)
            }
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 0.5)
            .padding(.leading, Space.md)
    }
}

/// A title on the left and a quiet value on the right.
struct ValueRow<Value: View>: View {
    let title: String
    var showsChevron = false
    @ViewBuilder var value: () -> Value

    var body: some View {
        HStack(spacing: Space.xs) {
            Text(title)
                .font(Typeface.body)
                .foregroundStyle(Theme.ink)
            Spacer(minLength: Space.xs)
            value()
                .font(Typeface.secondary)
                .foregroundStyle(Theme.inkSecondary)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(Typeface.micro)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .padding(.horizontal, Space.md)
        .frame(minHeight: 50)
        .contentShape(.rect)
    }
}

extension ValueRow where Value == EmptyView {
    init(title: String, showsChevron: Bool = false) {
        self.init(title: title, showsChevron: showsChevron) { EmptyView() }
    }
}

extension ValueRow where Value == Text {
    init(title: String, value: String, showsChevron: Bool = false) {
        self.init(title: title, showsChevron: showsChevron) { Text(value) }
    }
}

extension View {
    /// A text field in a soft grey well.
    func filledField() -> some View {
        font(Typeface.body)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Space.md)
            .frame(minHeight: 48)
            .background(Theme.well, in: .rect(cornerRadius: Radius.sm + 2, style: .continuous))
    }

    /// Sheets on the page colour, without the glass, closed by swiping.
    func crownsSheet() -> some View {
        presentationBackground(Theme.canvas)
            .presentationCornerRadius(Radius.xl)
            .presentationDragIndicator(.visible)
    }
}

/// Title in the middle, an action on the right. Sheets close with a swipe.
struct SheetHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(Typeface.heading)
                .foregroundStyle(Theme.ink)
            HStack {
                Spacer()
                trailing()
            }
        }
        .frame(minHeight: 40)
        .padding(.horizontal, Space.md)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xs)
    }
}

extension SheetHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// A capsule label. Pass the same namespace to a row of chips and the black
/// selection slides from one to the next.
struct Chip: View {
    let title: String
    let selected: Bool
    let namespace: Namespace.ID

    var body: some View {
        Text(title)
            .font(Typeface.label)
            .lineLimit(1)
            .foregroundStyle(selected ? Theme.onInk : Theme.inkSecondary)
            .padding(.horizontal, Space.md)
            .frame(height: 40)
            .background {
                ZStack {
                    Capsule().fill(Theme.surface).elevation(.low)
                    if selected {
                        Capsule()
                            .fill(Theme.ink)
                            .elevation(.mid)
                            .matchedGeometryEffect(id: "chip.selection", in: namespace)
                    }
                }
            }
            .contentShape(.capsule)
    }
}

/// Icon-only segments with a sliding thumb.
struct IconSegments<Value: Hashable>: View {
    struct Option {
        let value: Value
        let icon: String
        let label: String
    }

    let options: [Option]
    @Binding var selection: Value
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    guard !selected else { return }
                    Haptics.tick()
                    selection = option.value
                } label: {
                    Image(systemName: option.icon)
                        .font(Typeface.label)
                        .foregroundStyle(selected ? Theme.onInk : Theme.inkSecondary)
                        .frame(width: 40, height: 38)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Theme.ink)
                                    .matchedGeometryEffect(id: "segment.thumb", in: thumb)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .animation(Motion.selection, value: selection)
        .padding(3)
        .background { Capsule().fill(Theme.surface).elevation(.low) }
    }
}

/// A number with round minus and plus buttons.
struct CountStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: Space.sm) {
            Text(title)
                .font(Typeface.body)
                .foregroundStyle(Theme.ink)
            Spacer()
            stepButton("minus", label: "Fewer \(title.lowercased())", enabled: value > range.lowerBound, by: -1)
            Text("\(value)")
                .font(Typeface.heading.monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 24)
            stepButton("plus", label: "More \(title.lowercased())", enabled: value < range.upperBound, by: 1)
        }
        .padding(.horizontal, Space.xxs)
        .frame(minHeight: 50)
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, by delta: Int) -> some View {
        Button {
            Haptics.tick()
            value += delta
        } label: {
            Image(systemName: icon)
        }
        .buttonStyle(.circle(.flat, diameter: 36))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
