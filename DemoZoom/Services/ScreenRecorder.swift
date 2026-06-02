import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

@MainActor
class ScreenRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var availableWindows: [SCWindow] = []
    @Published var selectedWindow: SCWindow?

    private var streamOutput: CaptureStreamOutput?
    private var stream: SCStream?

    func fetchAvailableWindows() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        let simulatorWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == "com.apple.iphonesimulator" ||
            window.title?.contains("Simulator") == true
        }

        availableWindows = simulatorWindows

        if selectedWindow == nil, let first = simulatorWindows.first {
            selectedWindow = first
        }
    }

    func startRecording() async throws -> URL {
        guard let window = selectedWindow else {
            throw NSError(domain: "DemoZoom", code: 2, userInfo: [NSLocalizedDescriptionKey: "No window selected"])
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2
        config.height = Int(window.frame.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DemoZoom")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let output = CaptureStreamOutput(outputURL: outputURL, videoSize: CGSize(width: config.width, height: config.height))
        streamOutput = output

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        self.stream = stream

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global())
        try await stream.startCapture()

        isRecording = true

        return outputURL
    }

    func stopRecording() async throws {
        guard let stream = stream else { return }

        try await stream.stopCapture()
        await streamOutput?.finishWriting()

        self.stream = nil
        self.streamOutput = nil
        isRecording = false
    }
}

private class CaptureStreamOutput: NSObject, SCStreamOutput {
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private var isWriting = false
    private var startTime: CMTime?

    init(outputURL: URL, videoSize: CGSize) {
        self.assetWriter = try! AVAssetWriter(url: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        self.videoInput.expectsMediaDataInRealTime = true

        self.adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )

        assetWriter.add(videoInput)

        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if !isWriting {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: presentationTime)
            isWriting = true
            startTime = presentationTime
        }

        if videoInput.isReadyForMoreMediaData {
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }
    }

    func finishWriting() async {
        guard isWriting else { return }

        videoInput.markAsFinished()
        await assetWriter.finishWriting()
        isWriting = false
    }
}
