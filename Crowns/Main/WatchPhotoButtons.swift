import SwiftUI
import PhotosUI

/// Camera and library buttons for giving a watch its photo.
struct WatchPhotoButtons: View {
    let hasPhoto: Bool
    @Binding var isTakingPhoto: Bool
    /// Plain form rows rather than pills.
    var rows = false
    let onPhoto: (Data) -> Void
    let onFailure: () -> Void

    @State private var photoItem: PhotosPickerItem?

    private var canUseCamera: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        if rows {
            cameraButton
            libraryButton
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.xs) { cameraButton; libraryButton }
                VStack(spacing: Space.xs) { cameraButton; libraryButton }
            }
            .buttonStyle(.pill(.secondary, size: .small))
        }
    }

    @ViewBuilder
    private var cameraButton: some View {
        if canUseCamera {
            Button {
                isTakingPhoto = true
            } label: {
                Label(hasPhoto ? "Retake" : "Take photo", systemImage: "camera")
            }
            .fullScreenCover(isPresented: $isTakingPhoto) {
                CameraPicker { data in
                    isTakingPhoto = false
                    if let data { onPhoto(data) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var libraryButton: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Label(hasPhoto ? "Choose another" : "Choose photo", systemImage: "photo")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let loaded = try? await item.loadTransferable(type: Data.self)
                if let data = loaded ?? nil {
                    onPhoto(data)
                } else {
                    onFailure()
                }
                photoItem = nil
            }
        }
    }
}

/// The system camera. Reports the photo, or nil if it was cancelled.
private struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (Data?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (Data?) -> Void

        init(onFinish: @escaping (Data?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onFinish(image?.jpegData(compressionQuality: 0.9))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
