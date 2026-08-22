import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers

struct CameraView: View {
    @State private var isShowingCameraRecorder = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var uploadedVideoURL: URL?
    @State private var uploadedVideoThumbnail: UIImage?
    @State private var recordedVideoURL: URL?
    @State private var isShowingCameraUnavailableAlert = false
    @State private var cameraUnavailableMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Scan")
                .font(.largeTitle.bold())

            PhotosPicker(selection: $photosPickerItem, matching: .videos) {
                uploadFieldContent
            }

            Button {
                requestCameraAccessAndShowRecorder()
            } label: {
                Label("Record Video (45s)", systemImage: "video.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .alert("Camera Unavailable", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cameraUnavailableMessage)
        }
        .fullScreenCover(isPresented: $isShowingCameraRecorder) {
            VideoRecorderView(maxDuration: 45) { url in
                recordedVideoURL = url
                isShowingCameraRecorder = false
            } onCancel: {
                isShowingCameraRecorder = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                guard let movie = try? await newItem?.loadTransferable(type: Movie.self) else { return }
                uploadedVideoURL = movie.url
                uploadedVideoThumbnail = await Self.generateThumbnail(for: movie.url)
            }
        }
    }

    @ViewBuilder
    private var uploadFieldContent: some View {
        if let uploadedVideoThumbnail {
            Image(uiImage: uploadedVideoThumbnail)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .padding(8)
                }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.largeTitle)
                Text("Tap to upload a video")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(.secondary)
            )
        }
    }

    private func requestCameraAccessAndShowRecorder() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraUnavailableMessage = "This device or simulator doesn't have a camera available."
            isShowingCameraUnavailableAlert = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingCameraRecorder = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        isShowingCameraRecorder = true
                    } else {
                        cameraUnavailableMessage = "Camera access was denied. Enable it in Settings to record a video."
                        isShowingCameraUnavailableAlert = true
                    }
                }
            }
        default:
            cameraUnavailableMessage = "Camera access is disabled. Enable it in Settings to record a video."
            isShowingCameraUnavailableAlert = true
        }
    }

    private static func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: .zero) { cgImage, _, _ in
                if let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return Self(url: destination)
        }
    }
}

private struct VideoRecorderView: UIViewControllerRepresentable {
    let maxDuration: TimeInterval
    let onFinish: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.cameraDevice = .rear
        picker.videoMaximumDuration = maxDuration
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (URL) -> Void
        let onCancel: () -> Void

        init(onFinish: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true) {
                if let url = info[.mediaURL] as? URL {
                    self.onFinish(url)
                } else {
                    self.onCancel()
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onCancel()
            }
        }
    }
}
