import Foundation
import AVFoundation
import CoreGraphics

class DemoProject: ObservableObject {
    @Published var videoURL: URL?
    @Published var videoDuration: CMTime = .zero
    @Published var videoSize: CGSize = .zero
    @Published var interactions: [InteractionPoint] = []
    @Published var currentTime: CMTime = .zero
    @Published var selectedInteractionID: UUID?

    var canAddInteraction: Bool {
        interactions.count < 10
    }

    var selectedInteraction: InteractionPoint? {
        guard let id = selectedInteractionID else { return nil }
        return interactions.first { $0.id == id }
    }

    func addInteraction(at time: CMTime, position: CGPoint) {
        guard canAddInteraction else { return }

        let newInteraction = InteractionPoint(
            timestamp: time,
            position: position,
            zoomLevel: 1.0,
            frameSize: videoSize
        )

        interactions.append(newInteraction)
        interactions.sort { $0.timestamp.seconds < $1.timestamp.seconds }
        selectedInteractionID = newInteraction.id
    }

    func updateInteraction(id: UUID, zoomLevel: Double? = nil, frameSize: CGSize? = nil) {
        guard let index = interactions.firstIndex(where: { $0.id == id }) else { return }

        if let zoomLevel = zoomLevel {
            interactions[index].zoomLevel = max(0.0, min(2.0, zoomLevel))
        }

        if let frameSize = frameSize {
            interactions[index].frameSize = frameSize
        }
    }

    func removeInteraction(id: UUID) {
        interactions.removeAll { $0.id == id }
        if selectedInteractionID == id {
            selectedInteractionID = interactions.first?.id
        }
    }

    func loadVideo(from url: URL) async throws {
        let asset = AVAsset(url: url)

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "DemoZoom", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let duration = try await asset.load(.duration)
        let naturalSize = try await track.load(.naturalSize)

        await MainActor.run {
            self.videoURL = url
            self.videoDuration = duration
            self.videoSize = naturalSize
            self.interactions = []
            self.currentTime = .zero
            self.selectedInteractionID = nil
        }
    }
}
