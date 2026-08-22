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

// MARK: - Video recorder

// UIImagePickerController locks exposure/white-balance the instant it opens, before the
// sensor has adjusted to the subject's skin tone — that miscalibrated first fraction of a
// second is baked into the whole clip and throws off the rPPG signal. This wraps a manual
// AVCaptureSession instead: it lets auto-exposure/auto-WB converge for a beat, locks them
// so lighting doesn't drift mid-recording, and only then starts writing to disk.
private struct VideoRecorderView: UIViewControllerRepresentable {
    let maxDuration: TimeInterval
    let onFinish: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CustomCameraViewController {
        let controller = CustomCameraViewController()
        controller.maxDuration = maxDuration
        controller.onFinish = onFinish
        controller.onCancel = onCancel
        return controller
    }

    func updateUIViewController(_ uiViewController: CustomCameraViewController, context: Context) {}
}

private final class CustomCameraViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var maxDuration: TimeInterval = 45
    var onFinish: ((URL) -> Void)?
    var onCancel: (() -> Void)?

    // ponytail: fixed convergence window, not a metered "confidence" check — tune this if devices still show a color/exposure shift at the start of clips.
    private let convergenceDelay: TimeInterval = 0.6

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var device: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var cameraPosition: AVCaptureDevice.Position = .back

    private let recordButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let switchCameraButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let timerLabel = UILabel()

    private var recordingTimer: Timer?
    private var recordingStartDate: Date?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setUpPreviewAndControls()
        sessionQueue.async { [weak self] in self?.configureSession() }
    }

    private func setUpPreviewAndControls() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        statusLabel.text = "Preparing…"
        statusLabel.textColor = .white
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        recordButton.setTitle("Record", for: .normal)
        recordButton.setTitleColor(.white, for: .normal)
        recordButton.backgroundColor = UIColor.systemRed
        recordButton.layer.cornerRadius = 30
        recordButton.isEnabled = false
        recordButton.alpha = 0.4
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)
        view.addSubview(recordButton)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)

        switchCameraButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
        view.addSubview(switchCameraButton)

        timerLabel.text = "0:00"
        timerLabel.textColor = .white
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .semibold)
        timerLabel.isHidden = true
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: recordButton.topAnchor, constant: -16),

            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            recordButton.widthAnchor.constraint(equalToConstant: 120),
            recordButton.heightAnchor.constraint(equalToConstant: 60),

            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            switchCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 32),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 32),

            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard addCameraInput(position: cameraPosition) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in self?.onCancel?() }
            return
        }

        guard session.canAddOutput(movieOutput) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in self?.onCancel?() }
            return
        }
        session.addOutput(movieOutput)
        movieOutput.maxRecordedDuration = CMTime(seconds: maxDuration, preferredTimescale: 600)

        session.commitConfiguration()
        session.startRunning()

        beginConvergence()
    }

    // Must be called inside `session.beginConfiguration()`/`commitConfiguration()`.
    private func addCameraInput(position: AVCaptureDevice.Position) -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return false
        }
        session.addInput(input)
        self.device = device
        return true
    }

    // Auto-exposure/auto-WB are already running (their default mode) as soon as a camera
    // input is added; give them `convergenceDelay` to settle on the subject before locking.
    private func beginConvergence() {
        sessionQueue.asyncAfter(deadline: .now() + convergenceDelay) { [weak self] in
            self?.lockExposureAndWhiteBalance()
        }
    }

    private func lockExposureAndWhiteBalance() {
        guard let device else { return }
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
            // Locking failed — recording still works, just without the stabilized exposure/WB.
        }
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "Ready"
            self?.recordButton.isEnabled = true
            self?.recordButton.alpha = 1
        }
    }

    @objc private func recordTapped() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
            stopRecordingTimer()
            recordButton.setTitle("Record", for: .normal)
            statusLabel.text = "Ready"
            switchCameraButton.isHidden = false
        } else {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            movieOutput.startRecording(to: url, recordingDelegate: self)
            startRecordingTimer()
            recordButton.setTitle("Stop", for: .normal)
            statusLabel.text = "Recording…"
            switchCameraButton.isHidden = true
        }
    }

    @objc private func switchCameraTapped() {
        guard !movieOutput.isRecording else { return }
        cameraPosition = cameraPosition == .back ? .front : .back

        switchCameraButton.isEnabled = false
        recordButton.isEnabled = false
        recordButton.alpha = 0.4
        statusLabel.text = "Preparing…"

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            if let currentInput = self.session.inputs.first {
                self.session.removeInput(currentInput)
            }
            _ = self.addCameraInput(position: self.cameraPosition)
            self.session.commitConfiguration()
            self.beginConvergence()
            DispatchQueue.main.async { self.switchCameraButton.isEnabled = true }
        }
    }

    private func startRecordingTimer() {
        recordingStartDate = Date()
        timerLabel.text = "0:00"
        timerLabel.isHidden = false
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartDate else { return }
            let seconds = Int(Date().timeIntervalSince(start))
            self.timerLabel.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartDate = nil
        timerLabel.isHidden = true
    }

    @objc private func cancelTapped() {
        sessionQueue.async { [weak self] in self?.session.stopRunning() }
        onCancel?()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        sessionQueue.async { [weak self] in self?.session.stopRunning() }
        if error == nil {
            onFinish?(outputFileURL)
        } else {
            onCancel?()
        }
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
    }
}
