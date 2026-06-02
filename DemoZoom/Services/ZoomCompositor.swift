import AVFoundation
import CoreImage
import CoreMedia

class ZoomCompositor: NSObject, AVVideoCompositing {
    private let renderQueue = DispatchQueue(label: "com.demozoom.compositor")
    private let renderContext = CIContext()

    var sourcePixelBufferAttributes: [String: Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]

    var requiredPixelBufferAttributesForRenderContext: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
    }

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        renderQueue.async { [weak self] in
            guard let self = self else {
                request.finish(with: NSError(domain: "DemoZoom", code: 6, userInfo: nil))
                return
            }

            guard let instruction = request.videoCompositionInstruction as? ZoomInstruction,
                  let sourceBuffer = request.sourceFrame(byTrackID: request.sourceTrackIDs[0].int32Value) else {
                request.finish(with: NSError(domain: "DemoZoom", code: 7, userInfo: nil))
                return
            }

            let time = request.compositionTime
            let cropRect = instruction.cropRect(at: time)

            let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)
            let croppedImage = sourceImage.cropped(to: cropRect)

            let scaleX = instruction.videoSize.width / cropRect.width
            let scaleY = instruction.videoSize.height / cropRect.height
            let translateX = -cropRect.origin.x * scaleX
            let translateY = -cropRect.origin.y * scaleY

            let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                .concatenating(CGAffineTransform(translationX: translateX, y: translateY))

            let finalImage = croppedImage.transformed(by: transform)

            guard let outputBuffer = request.renderContext.newPixelBuffer() else {
                request.finish(with: NSError(domain: "DemoZoom", code: 8, userInfo: nil))
                return
            }

            self.renderContext.render(finalImage, to: outputBuffer)
            request.finish(withComposedVideoFrame: outputBuffer)
        }
    }
}

class ZoomInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let interactions: [InteractionPoint]
    let videoSize: CGSize
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    init(timeRange: CMTimeRange, interactions: [InteractionPoint], videoSize: CGSize, trackID: CMPersistentTrackID) {
        self.timeRange = timeRange
        self.interactions = interactions.sorted { $0.timestamp.seconds < $1.timestamp.seconds }
        self.videoSize = videoSize
        self.requiredSourceTrackIDs = [NSNumber(value: trackID)]
        super.init()
    }

    func cropRect(at time: CMTime) -> CGRect {
        let t = time.seconds

        guard !interactions.isEmpty else {
            return CGRect(origin: .zero, size: videoSize)
        }

        if interactions.count == 1 {
            return cropRect(for: interactions[0])
        }

        if t <= interactions.first!.timestamp.seconds {
            return cropRect(for: interactions.first!)
        }

        if t >= interactions.last!.timestamp.seconds {
            return cropRect(for: interactions.last!)
        }

        var prevInteraction = interactions[0]
        var nextInteraction = interactions[0]

        for i in 0..<interactions.count - 1 {
            if t >= interactions[i].timestamp.seconds && t <= interactions[i + 1].timestamp.seconds {
                prevInteraction = interactions[i]
                nextInteraction = interactions[i + 1]
                break
            }
        }

        let duration = nextInteraction.timestamp.seconds - prevInteraction.timestamp.seconds
        guard duration > 0 else {
            return cropRect(for: prevInteraction)
        }

        let normalizedT = (t - prevInteraction.timestamp.seconds) / duration
        let easedT = EasingFunctions.easeInOutCubic(normalizedT)

        let center = EasingFunctions.lerpPoint(from: prevInteraction.position, to: nextInteraction.position, t: easedT)
        let frameSize = EasingFunctions.lerpSize(from: prevInteraction.frameSize, to: nextInteraction.frameSize, t: easedT)

        return cropRect(for: center, frameSize: frameSize)
    }

    private func cropRect(for interaction: InteractionPoint) -> CGRect {
        return cropRect(for: interaction.position, frameSize: interaction.frameSize)
    }

    private func cropRect(for center: CGPoint, zoom: Double, frameSize: CGSize) -> CGRect {
        let visibleWidth = frameSize.width
        let visibleHeight = frameSize.height

        let centerX = center.x * videoSize.width
        let centerY = center.y * videoSize.height

        var cropX = centerX - visibleWidth / 2
        var cropY = centerY - visibleHeight / 2

        cropX = max(0, min(cropX, videoSize.width - visibleWidth))
        cropY = max(0, min(cropY, videoSize.height - visibleHeight))

        return CGRect(x: cropX, y: cropY, width: visibleWidth, height: visibleHeight)
    }

    private func cropRect(for center: CGPoint, frameSize: CGSize) -> CGRect {
        let centerX = center.x * videoSize.width
        let centerY = center.y * videoSize.height

        var cropX = centerX - frameSize.width / 2
        var cropY = centerY - frameSize.height / 2

        cropX = max(0, min(cropX, videoSize.width - frameSize.width))
        cropY = max(0, min(cropY, videoSize.height - frameSize.height))

        return CGRect(x: cropX, y: cropY, width: frameSize.width, height: frameSize.height)
    }
}
