import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers

struct CameraView: View {
    @State private var selectedVideoURL: URL?
    @State private var selectedVideoThumbnail: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isShowingCameraUnavailableAlert = false
    @State private var cameraUnavailableMessage = ""
    @State private var isProcessing = false
    @State private var vitalsResult: VitalsResponse?
    @State private var processingErrorMessage: String?
    @State private var isShowingProcessingErrorAlert = false

    private let heartRateThresholds = HeartRateThresholds()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 28)
                uploadArea
                    .padding(.top, 32)
                cameraAction
                    .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(VantaTheme.background.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            continueButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(VantaTheme.background.ignoresSafeArea(edges: .bottom))
        }
        .alert("Camera Unavailable", isPresented: $isShowingCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cameraUnavailableMessage)
        }
        .alert("Couldn't Process Video", isPresented: $isShowingProcessingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(processingErrorMessage ?? "")
        }
        .overlay {
            if isProcessing {
                ZStack {
                    VantaTheme.background.opacity(0.75).ignoresSafeArea()
                    ProgressView("Analyzing video…")
                        .tint(VantaTheme.accent)
                        .foregroundStyle(VantaTheme.textPrimary)
                        .padding(24)
                        .background(VantaTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VantaTheme.border, lineWidth: 1))
                }
            }
        }
        .sheet(item: $vitalsResult) { result in
            VitalsResultView(result: result, thresholds: heartRateThresholds) {
                vitalsResult = nil
                selectedVideoURL = nil
                selectedVideoThumbnail = nil
                photosPickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            VideoRecorderView(maxDuration: 45) { url in
                selectedVideoURL = url
                isShowingCamera = false
                Task { selectedVideoThumbnail = await Self.generateThumbnail(for: url) }
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                guard let movie = try? await newItem?.loadTransferable(type: Movie.self) else { return }
                selectedVideoURL = movie.url
                selectedVideoThumbnail = await Self.generateThumbnail(for: movie.url)
            }
        }
    }

    private func startProcessing(_ videoURL: URL) {
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                let response = try await VitalsAPI.process(videoAt: videoURL)
                guard response.hr_bpm != nil else {
                    processingErrorMessage = "The scan finished without a heart-rate measurement. Try a shorter, steadier video and check again."
                    isShowingProcessingErrorAlert = true
                    return
                }
                vitalsResult = response
            } catch let apiError as VitalsAPIError {
                processingErrorMessage = apiError.message
                isShowingProcessingErrorAlert = true
            } catch let urlError as URLError where urlError.code == .timedOut {
                processingErrorMessage = "The server took too long. Try a shorter, still clip after opening the health page."
                isShowingProcessingErrorAlert = true
            } catch {
                processingErrorMessage = "Could not reach the server. Check your connection and try again."
                isShowingProcessingErrorAlert = true
            }
        }
    }

    // grabs the first frame of the video so we have something to show in the upload tile
    private static func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true // otherwise portrait videos come out sideways
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

    // MARK: Heading

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upload a video \(Image(systemName: "video.fill"))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(VantaTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Upload a video")

            Text("Record 15–45 seconds of a still face. Your data stays on this scan.")
                .font(.subheadline)
                .foregroundStyle(VantaTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Upload area

    private var uploadArea: some View {
        PhotosPicker(selection: $photosPickerItem, matching: .videos) {
            uploadAreaContent
        }
        .accessibilityLabel(selectedVideoURL == nil ? "Select file to upload your video" : "Video selected. Tap to choose a different file")
    }

    @ViewBuilder
    private var uploadAreaContent: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(VantaTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(VantaTheme.border, lineWidth: 1)
            )
            .frame(height: 220)
            .overlay {
                if let selectedVideoThumbnail {
                    Image(uiImage: selectedVideoThumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(VantaTheme.background, VantaTheme.accent)
                                .padding(10)
                        }
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(VantaTheme.textPrimary)
                        }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 32, weight: .medium))
                        Text("Select file")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(VantaTheme.textMuted)
                }
            }
    }

    // MARK: Camera action

    private var cameraAction: some View {
        VStack(spacing: 20) {
            Text("or")
                .font(.footnote)
                .foregroundStyle(VantaTheme.textMuted)

            Button {
                requestCameraAccessAndShowCapture()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("Open Camera & Record Video")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(VantaTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(VantaTheme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(VantaTheme.border, lineWidth: 1))
            }
            .accessibilityLabel("Open camera and record a video")
        }
    }

    // MARK: Continue

    private var continueButton: some View {
        Button {
            if let selectedVideoURL {
                startProcessing(selectedVideoURL)
            }
        } label: {
            Text("Continue")
                .font(.body.weight(.semibold))
                .foregroundStyle(VantaTheme.background)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(selectedVideoURL == nil ? VantaTheme.accent.opacity(0.4) : VantaTheme.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(selectedVideoURL == nil)
        .accessibilityLabel("Continue")
    }

    // MARK: Camera permission

    private func requestCameraAccessAndShowCapture() {
        // the simulator has no camera at all, so check that before touching permissions
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            cameraUnavailableMessage = "This device or simulator doesn't have a camera available."
            isShowingCameraUnavailableAlert = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        isShowingCamera = true
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
}

// MARK: - Video transfer

// PhotosPickerItem can't just hand us a `Data` blob for a video (it's too big / lives
// in iCloud), so this teaches it to copy the picked file to a local temp URL instead.
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

// MARK: - Video recorder picker

// SwiftUI has no native camera view, so this wraps the old UIKit picker to get one.
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
        picker.videoQuality = .typeMedium
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

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
