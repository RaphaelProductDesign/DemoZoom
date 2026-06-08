import Foundation
import AVFoundation
import CoreMedia
import SwiftUI

class VideoProcessor {
    func generateComposition(
        for asset: AVAsset,
        interactions: [InteractionPoint],
        videoSize: CGSize,
        backgroundColor: Color = Color(red: 1.0, green: 0.92, blue: 0.23)
    ) async throws -> AVVideoComposition {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw NSError(domain: "DemoZoom", code: 3, userInfo: [NSLocalizedDescriptionKey: "No video track"])
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await videoTrack.load(.naturalSize)
        let trackID = videoTrack.trackID

        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = ZoomCompositor.self
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.renderSize = naturalSize

        let instruction = ZoomInstruction(
            timeRange: CMTimeRange(start: .zero, duration: duration),
            interactions: interactions,
            videoSize: naturalSize,
            trackID: trackID,
            backgroundColor: backgroundColor
        )

        composition.instructions = [instruction]

        return composition
    }

    func exportVideo(
        asset: AVAsset,
        composition: AVVideoComposition,
        outputURL: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        try? FileManager.default.removeItem(at: outputURL)

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "DemoZoom", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
        }

        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.videoComposition = composition

        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progress(Double(export.progress))
        }

        await export.export()
        progressTimer.invalidate()

        guard export.status == .completed else {
            throw export.error ?? NSError(domain: "DemoZoom", code: 5, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
    }
}
