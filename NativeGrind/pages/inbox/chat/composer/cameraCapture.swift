//
//  cameraCapture.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

#if os(iOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct cameraCapture: UIViewControllerRepresentable {
    enum captureMode {
        case photo
        case video
    }

    let mode: captureMode
    let onCapture: (chatOutgoingMedia?) -> Void

    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [mode == .photo ? UTType.image.identifier : UTType.movie.identifier]
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: cameraCapture

        init(parent: cameraCapture) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            let movie = info[.mediaURL] as? URL
            let onCapture = parent.onCapture
            parent.dismiss()

            Task { @MainActor in
                if let movie {
                    onCapture(await chatOutgoingMedia.video(from: movie))
                } else if let data = image?.jpegData(compressionQuality: 0.9) {
                    onCapture(chatOutgoingMedia.photo(from: data))
                } else {
                    onCapture(nil)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
