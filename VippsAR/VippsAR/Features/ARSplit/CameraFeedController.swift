import AVFoundation
import UIKit
import Combine

/// Wraps `AVCaptureSession` and publishes frames as `CVPixelBuffer` for OCR processing.
/// Conforms to `ObservableObject` so SwiftUI can react to permission/session state changes.
final class CameraFeedController: NSObject, ObservableObject {

    // MARK: - Published state
    @Published var isAuthorized: Bool = false
    @Published var isRunning: Bool = false
    @Published var latestFrame: CVPixelBuffer?

    // MARK: - AVFoundation
    let session = AVCaptureSession()
    private let frameOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.nordicsplit.camera", qos: .userInitiated)

    // MARK: - Frame throttle
    /// Only forward one frame every N milliseconds to avoid saturating the OCR actor.
    private let throttleInterval: TimeInterval = 0.35
    private var lastFrameTime: TimeInterval = 0

    // MARK: - Setup

    func requestPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.configureAndStart() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configure()
            self.session.startRunning()
            DispatchQueue.main.async { self.isRunning = true }
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .hd1280x720

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        session.addInput(input)

        frameOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        frameOutput.alwaysDiscardsLateVideoFrames = true
        frameOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if session.canAddOutput(frameOutput) {
            session.addOutput(frameOutput)
        }

        // Lock focus on the centre of the frame — ideal for flat receipts
        try? device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
        }
        device.unlockForConfiguration()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraFeedController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= throttleInterval else { return }
        lastFrameTime = now

        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.latestFrame = buffer
        }
    }
}
