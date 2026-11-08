import SwiftUI

/// Phase 1 sheet: functional, not final. Phase 4 replaces it with the compact
/// card (carousel, cut-outs, conversion).
struct ShareSheetView: View {
    @Bindable var model: ShareModel

    var body: some View {
        NavigationStack {
            Group {
                if model.stage == .reading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    form
                }
            }
            .navigationTitle("Add watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { model.cancel() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 16) {
                photos
                VStack(spacing: 0) {
                    field("Brand", text: $model.brand)
                    Divider()
                    field("Model", text: $model.model)
                    Divider()
                    HStack(spacing: 4) {
                        Text("£").foregroundStyle(.secondary)
                        TextField("Price", text: $model.priceText)
                            .keyboardType(.decimalPad)
                    }
                    .padding(.vertical, 12)
                    if !model.priceNote.isEmpty {
                        Text(model.priceNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 10)
                    }
                }
                .padding(.horizontal, 16)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))

                if model.boxes.count > 1 {
                    Picker("Box", selection: $model.selectedBoxID) {
                        ForEach(model.boxes) { box in
                            Text(box.name).tag(Optional(box.id))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !model.errorText.isEmpty {
                    Text(model.errorText).font(.footnote).foregroundStyle(.red)
                }

                Button {
                    Task { await model.save() }
                } label: {
                    Text(model.stage == .saved ? "Saved" : "Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(model.stage != .ready)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .padding(.vertical, 12)
    }

    @ViewBuilder
    private var photos: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.04))
            if model.photos.isEmpty {
                if model.photosLoading { ProgressView() }
            } else {
                TabView(selection: $model.coverIndex) {
                    ForEach(Array(model.photos.enumerated()), id: \.element.id) { index, photo in
                        Image(uiImage: photo.preview)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: model.photos.count > 1 ? .automatic : .never))
                .transition(.opacity)
            }
        }
        .frame(height: 280)
        .animation(.smooth(duration: 0.35), value: model.photos.isEmpty)
    }
}
