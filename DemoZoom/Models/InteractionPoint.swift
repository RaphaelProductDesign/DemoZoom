import Foundation
import AVFoundation
import CoreGraphics

struct InteractionPoint: Identifiable, Codable {
    let id: UUID
    var timestamp: CMTime
    var position: CGPoint
    var zoomLevel: Double
    var frameSize: CGSize
    var transitionDuration: Double  // 0.4 to 1.5 seconds

    init(
        id: UUID = UUID(),
        timestamp: CMTime,
        position: CGPoint,
        zoomLevel: Double = 2.0,  // Default 200%
        frameSize: CGSize,
        transitionDuration: Double = 0.8  // Default 0.8s
    ) {
        self.id = id
        self.timestamp = timestamp
        self.position = position
        self.zoomLevel = zoomLevel
        self.frameSize = frameSize
        self.transitionDuration = transitionDuration
    }

    enum CodingKeys: String, CodingKey {
        case id, position, zoomLevel, frameSize, transitionDuration
        case timestampSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let seconds = try container.decode(Double.self, forKey: .timestampSeconds)
        timestamp = CMTime(seconds: seconds, preferredTimescale: 600)
        position = try container.decode(CGPoint.self, forKey: .position)
        zoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        frameSize = try container.decode(CGSize.self, forKey: .frameSize)
        transitionDuration = try container.decodeIfPresent(Double.self, forKey: .transitionDuration) ?? 0.8
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp.seconds, forKey: .timestampSeconds)
        try container.encode(position, forKey: .position)
        try container.encode(zoomLevel, forKey: .zoomLevel)
        try container.encode(frameSize, forKey: .frameSize)
        try container.encode(transitionDuration, forKey: .transitionDuration)
    }
}
