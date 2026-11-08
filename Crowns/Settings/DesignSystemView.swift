import SwiftUI

/// Every token and component on one page. Developer tool, linked from Settings.
struct DesignSystemView: View {
    @State private var segment = 0
    @State private var chip = 0
    @State private var count = 3
    @State private var field = ""
    @Namespace private var chips

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Space.sm) {
                        swatch("canvas", Theme.canvas)
                        swatch("surface", Theme.surface)
                        swatch("well", Theme.well)
                        swatch("ink", Theme.ink)
                        swatch("ink 2", Theme.inkSecondary)
                        swatch("ink 3", Theme.inkTertiary)
                    }
                }

                section("Type") {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Display").font(Typeface.display)
                        Text("Title").font(Typeface.title)
                        Text("Heading").font(Typeface.heading)
                        Text("Body").font(Typeface.body)
                        Text("Label").font(Typeface.label)
                        Text("Secondary").font(Typeface.secondary)
                        Text("Caption").font(Typeface.caption)
                        Text("REF-126610").font(Typeface.reference)
                    }
                    .foregroundStyle(Theme.ink)
                }

                section("Elevation") {
                    HStack(spacing: Space.md) {
                        level("flat", .flat)
                        level("low", .low)
                        level("mid", .mid)
                        level("high", .high)
                    }
                }

                section("Buttons") {
                    VStack(spacing: Space.sm) {
                        Button("Primary") {}.buttonStyle(.pill())
                        Button("Secondary") {}.buttonStyle(.pill(.secondary))
                        Button("Quiet") {}.buttonStyle(.pill(.quiet))
                        Button("Disabled") {}.buttonStyle(.pill()).disabled(true)
                        HStack(spacing: Space.md) {
                            Button {} label: { Image(systemName: "plus") }.buttonStyle(.circle(.primary, diameter: 64))
                            Button {} label: { Image(systemName: "gearshape.fill") }.buttonStyle(.circle())
                            Button {} label: { Image(systemName: "minus") }.buttonStyle(.circle(.flat, diameter: 36))
                            Button("Small") {}.buttonStyle(.pill(.primary, size: .small))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                section("Selection") {
                    VStack(alignment: .leading, spacing: Space.md) {
                        HStack(spacing: Space.xs) {
                            ForEach(0..<3, id: \.self) { index in
                                Button {
                                    chip = index
                                } label: {
                                    Chip(title: ["Collection", "Wishlist", "Sold"][index], selected: chip == index, namespace: chips)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .animation(Motion.selection, value: chip)
                        IconSegments(
                            options: [
                                .init(value: 0, icon: "square.grid.2x2.fill", label: "Grid"),
                                .init(value: 1, icon: "list.bullet", label: "List"),
                            ],
                            selection: $segment
                        )
                    }
                }

                section("Forms") {
                    Card(padding: Space.sm) {
                        VStack(spacing: Space.xs) {
                            TextField("Text field", text: $field).filledField()
                            CountStepper(title: "Columns", value: $count, range: 1...4)
                        }
                    }
                }
            }
            .padding(Space.md)
        }
        .scrollIndicators(.hidden)
        .background(Theme.canvas)
        .navigationTitle("Design system")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionLabel(text: title)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: Space.xxs) {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(color)
                .frame(height: 56)
                .elevation(.low)
            Text(name)
                .font(.caption2)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private func level(_ name: String, _ elevation: Elevation) -> some View {
        Text(name)
            .font(Typeface.micro)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .surface(radius: Radius.md, elevation: elevation)
    }
}
