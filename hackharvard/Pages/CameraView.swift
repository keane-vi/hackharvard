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
        .safeAreaInset(edge: .bottom) {
            continueButton
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
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
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Analyzing video…")
                        .padding(24)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
                .font(.system(size: 28, weight: .bold))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Upload a video")

            Text("Record 15–45 seconds of a still face. Your data stays on this scan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
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
                                .foregroundStyle(.white, .green)
                                .padding(10)
                        }
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 32, weight: .medium))
                        Text("Select file")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: Camera action

    private var cameraAction: some View {
        VStack(spacing: 20) {
            Text("or")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                requestCameraAccessAndShowCapture()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("Open Camera & Record Video")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.secondary.opacity(0.3), lineWidth: 1))
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(selectedVideoURL == nil ? Color.accentColor.opacity(0.4) : Color.accentColor, in: Capsule())
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

// MARK: - Video recorder

// UIImagePickerController's camera is a black-box system UI with no access to
// AVCaptureDevice, so there is no way to lock exposure/white balance through
// it. rPPG needs a steady exposure - a camera left on continuous auto-exposure
// keeps "hunting" for a correct brightness throughout the recording, and that
// hunting shows up as a real brightness oscillation on top of the much
// smaller pulse-driven color change POS is trying to measure. This wraps a
// custom AVCaptureSession instead so exposure and white balance can be locked
// once they settle, right before recording starts.
private struct VideoRecorderView: UIViewControllerRepresentable {
    let maxDuration: TimeInterval
    let onFinish: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CaptureViewController {
        let controller = CaptureViewController()
        controller.maxDuration = maxDuration
        controller.onFinish = onFinish
        controller.onCancel = onCancel
        return controller
    }

    func updateUIViewController(_ uiViewController: CaptureViewController, context: Context) {}
}

final class CaptureViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var maxDuration: TimeInterval = 45
    var onFinish: ((URL) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var captureDevice: AVCaptureDevice?
    private var recordButton: UIButton!
    private var isRecording = false
    private var didFinish = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
        setupPreviewLayer()
        setupControls()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            session.commitConfiguration()
            return
        }
        captureDevice = device

        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        if let connection = movieOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        session.commitConfiguration()
    }

    private func setupPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    private func setupControls() {
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        let recordButton = UIButton(type: .system)
        recordButton.setTitle("Record", for: .normal)
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.85)
        recordButton.layer.cornerRadius = 35
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recordButton)
        self.recordButton = recordButton

        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 70),
            recordButton.heightAnchor.constraint(equalToConstant: 70),
        ])
    }

    @objc private func cancelTapped() {
        session.stopRunning()
        finishOnce { self.onCancel?() }
    }

    @objc private func recordTapped() {
        if isRecording {
            movieOutput.stopRecording()
            return
        }
        recordButton.isEnabled = false
        lockExposureAndWhiteBalance { [weak self] in
            guard let self else { return }
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            self.movieOutput.maxRecordedDuration = CMTime(seconds: self.maxDuration, preferredTimescale: 600)
            self.movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            self.isRecording = true
            self.recordButton.isEnabled = true
            self.recordButton.setTitle("Stop", for: .normal)
        }
    }

    // Auto exposure/white balance need a moment to converge on the actual
    // scene before they're frozen - locking immediately would just freeze
    // whatever transient starting values the camera hadn't settled on yet.
    private func lockExposureAndWhiteBalance(completion: @escaping () -> Void) {
        guard let device = captureDevice else {
            completion()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            defer { completion() }
            guard self != nil else { return }
            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                }
                device.unlockForConfiguration()
            } catch {
                // Recording still proceeds even if the lock itself failed -
                // an unlocked-but-recorded clip beats no clip at all.
            }
        }
    }

    private func finishOnce(_ action: () -> Void) {
        guard !didFinish else { return }
        didFinish = true
        action()
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false
        recordButton.setTitle("Record", for: .normal)
        session.stopRunning()
        if error == nil {
            finishOnce { self.onFinish?(outputFileURL) }
        } else {
            finishOnce { self.onCancel?() }
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
