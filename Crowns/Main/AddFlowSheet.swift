import SwiftUI
import SwiftData

/// Adding inside the app: a link (same reader as the share extension) or
/// typing it in by hand. The form opens as its own sheet on top of this one.
struct AddFlowSheet: View {
    let boxID: UUID?
    /// A wide window shows this as a floating card, which wants more room
    /// around and between things than a sheet at the foot of a phone.
    var isRoomy = false
    let onDone: (String?) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var model: AddWatchModel?
    @State private var contentHeight: CGFloat = 238
    @State private var sheetHeight: CGFloat = 238
    @State private var detentHeight: CGFloat = 212
    @State private var link = ""
    @State private var isEnteringLink = false

    var body: some View {
        chooser
            .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.height(detentHeight)])
            .presentationDragIndicator(.hidden)
            .presentationSizing(.form.fitted(horizontal: false, vertical: true))
            .sheet(isPresented: isShowingForm) {
                if let model {
                    NavigationStack {
                        AddWatchForm(model: model, photoActions: model.isManual ? AnyView(ManualPhotoRows(model: model)) : nil)
                    }
                    .tint(Theme.ink)
                    .presentationDragIndicator(.visible)
                }
            }
    }

    /// Swiping the form away comes back here, ready to start again.
    private var isShowingForm: Binding<Bool> {
        Binding(
            get: { model != nil },
            set: { showing in
                guard !showing else { return }
                model?.stop()
                model = nil
            }
        )
    }

    private var typedURL: URL? { ShareInputReader.firstLink(in: link) }

    private var chooser: some View {
        Group {
            if isRoomy {
                // A floating card fits itself to the background's height,
                // with the content centred in it.
                Color(.systemGroupedBackground)
                    // Measured here, so it counts any inset the sheet adds.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
                    .frame(idealHeight: contentHeight)
                    .overlay { chooserContent }
                    .ignoresSafeArea(.container)
            } else {
                chooserContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    // All edges: a device's side column is nowhere near this short sheet.
                    .ignoresSafeArea(.container)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { sheetHeight = $0 }
            }
        }
        // Size the sheet from its real height until that matches the content.
        .onChange(of: contentHeight - sheetHeight) { _, difference in
            if abs(difference) > 0.5 { detentHeight += difference }
        }
        .alert("Extract from URL", isPresented: $isEnteringLink) {
            TextField("Paste or type a URL", text: $link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Extract", action: openTypedLink)
                .disabled(typedURL == nil)
        }
    }

    private var chooserContent: some View {
        VStack(spacing: isRoomy ? Space.lg : Space.md) {
            VStack(spacing: isRoomy ? Space.sm : Space.xs) {
                Text("Add a watch")
                    .font(Typeface.title)
                    .foregroundStyle(Theme.ink)
                Text("**Found one online?** Paste the link and we'll do the rest.\n**Already on your wrist?** Enter it yourself.")
                    .font(Typeface.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: isRoomy ? Space.sm : 10) {
                Button {
                    link = ""
                    isEnteringLink = true
                } label: {
                    Text("Extract from URL")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill())

                Button {
                    begin(.manual)
                } label: {
                    Text("Add manually")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pill(.secondary, bordered: true))
            }
        }
        .padding(isRoomy ? Space.xl : Space.md)
        // Its full height at any text size, for the sheet to grow to.
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
    }

    private func openTypedLink() {
        guard let url = typedURL else { return }
        begin(.link(url))
    }

    private func begin(_ source: AddWatchSource) {
        let model = AddWatchModel(context: context, isExtension: false, boxID: boxID, finish: onDone)
        self.model = model
        Task { await model.start(source) }
    }
}

/// The photo rows for a watch being added by hand.
private struct ManualPhotoRows: View {
    @Bindable var model: AddWatchModel

    var body: some View {
        WatchPhotoButtons(
            hasPhoto: !model.photos.isEmpty,
            isTakingPhoto: $model.isTakingPhoto,
            rows: true,
            onPhoto: model.setPhoto,
            onFailure: { model.errorText = "Couldn't read that photo" }
        )
    }
}
