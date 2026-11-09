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
            .padding(.horizontal, Space.md)
    }
}

/// A small rounded black tile holding a row's symbol.
private struct RowIcon: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.onInk)
            .frame(width: 30, height: 30)
            .background(Theme.ink, in: .rect(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A title on the left and a quiet value on the right.
struct ValueRow<Value: View>: View {
    let title: String
    var icon: String? = nil
    var showsChevron = false
    @ViewBuilder var value: () -> Value

    var body: some View {
        HStack(spacing: Space.sm) {
            if let icon { RowIcon(symbol: icon) }
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
        .frame(minHeight: 54)
        .contentShape(.rect)
    }
}

extension ValueRow where Value == EmptyView {
    init(title: String, icon: String? = nil, showsChevron: Bool = false) {
        self.init(title: title, icon: icon, showsChevron: showsChevron) { EmptyView() }
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

/// The page colour, fading to clear away from a screen edge.
private struct EdgeFade: View {
    let edge: VerticalEdge
    let subtle: Bool

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.canvas.opacity(subtle ? 0.45 : 1), location: 0),
                .init(color: Theme.canvas.opacity(subtle ? 0.18 : 0.9), location: 0.6),
                .init(color: Theme.canvas.opacity(0), location: 1),
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .ignoresSafeArea(edges: edge == .top ? .top : .bottom)
        .allowsHitTesting(false)
    }
}

/// Holds a view to the main screen's content width, centred.
private struct ContentColumn: ViewModifier {
    @Environment(\.contentWidth) private var width

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: width)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Centres the view in the main screen's content column, which is
    /// narrower than a large landscape window.
    func contentColumn() -> some View {
        modifier(ContentColumn())
    }

    /// A `fadingBar` for content that manages its own scrolling, such as
    /// paged views, which clip to any safe area they're given. Reports its
    /// height so the content can leave room.
    func fadingOverlay<Bar: View>(_ edge: VerticalEdge, subtle: Bool = false, height: Binding<CGFloat>, @ViewBuilder bar: () -> Bar) -> some View {
        overlay(alignment: edge == .top ? .top : .bottom) {
            bar()
                .frame(maxWidth: .infinity)
                .padding(edge == .top ? .bottom : .top, Space.md)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height.wrappedValue = $0 }
                .background { EdgeFade(edge: edge, subtle: subtle) }
        }
    }

    /// Pins buttons to a screen edge, with content scrolling softly beneath
    /// them. Use this rather than a solid bar. `subtle` barely tints what's
    /// behind, for controls that float over photos.
    func fadingBar<Bar: View>(_ edge: VerticalEdge, subtle: Bool = false, @ViewBuilder bar: () -> Bar) -> some View {
        scrollEdgeEffectHidden(true, for: edge == .top ? .top : .bottom)
            .safeAreaInset(edge: edge, spacing: 0) {
                bar()
                    .frame(maxWidth: .infinity)
                    .padding(edge == .top ? .bottom : .top, Space.md)
                    .background { EdgeFade(edge: edge, subtle: subtle) }
            }
    }
}

/// A capsule on the page. The selected one is black.
struct ChipButton: View {
    let title: String
    var selected = false
    /// No shadow, for chips inside a form row, which would clip it.
    var flat = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.label)
                .lineLimit(1)
                .foregroundStyle(selected ? Theme.onInk : Theme.inkSecondary)
                .padding(.horizontal, Space.md)
                .frame(height: 40)
                .background {
                    ZStack {
                        if flat {
                            Capsule().fill(Theme.well)
                        } else {
                            Capsule().fill(Theme.surface).elevation(.low)
                        }
                        if selected {
                            Capsule().fill(Theme.ink).elevation(.mid)
                        }
                    }
                }
                // A 44pt touch target around the 40pt capsule.
                .padding(.vertical, 2)
                .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
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
