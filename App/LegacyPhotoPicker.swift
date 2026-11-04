#if os(iOS)
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// @brief The provider is used only for its asynchronous file-loading API.
/// @note Each callback copies its temporary file before returning; no shared mutable state.
struct LegacyPhotoItem: @unchecked Sendable {
    let provider: NSItemProvider
    func copyFile() async throws -> URL? {
        let type = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) ? UTType.movie.identifier : UTType.image.identifier
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                if let error { continuation.resume(throwing: error); return }
                guard let url else { continuation.resume(returning: nil); return }
                do { continuation.resume(returning: try PickedFile(copying: url).url) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

/// @brief Photos and videos remain selectable on iOS 15, with ordered multiple selection.
struct LegacyPhotoPicker: UIViewControllerRepresentable {
    let limit: Int
    @Binding var isPresented: Bool
    let selected: ([LegacyPhotoItem]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = max(1, limit)
        configuration.selection = .ordered
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) { context.coordinator.parent = self }
    @MainActor final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: LegacyPhotoPicker
        init(_ parent: LegacyPhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            parent.selected(results.map { LegacyPhotoItem(provider: $0.itemProvider) })
        }
    }
}
#endif
