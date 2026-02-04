import Foundation
import CoreMedia
import CoreGraphics

struct VideoSegment: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceURL: URL
    var timeRange: CMTimeRange  // Maintenant mutable pour permettre le trim
    let qualityScore: Float
    let tags: [String]
    let saliencyCenter: CGPoint
    
    init(id: UUID = UUID(),
         sourceURL: URL,
         timeRange: CMTimeRange,
         qualityScore: Float,
         tags: [String] = [],
         saliencyCenter: CGPoint = .zero) {
        self.id = id
        self.sourceURL = sourceURL
        self.timeRange = timeRange
        self.qualityScore = qualityScore
        self.tags = tags
        self.saliencyCenter = saliencyCenter
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VideoSegment, rhs: VideoSegment) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, sourceURL, qualityScore, tags, saliencyCenter
        case timeRangeStart, timeRangeDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        qualityScore = try container.decode(Float.self, forKey: .qualityScore)
        tags = try container.decode([String].self, forKey: .tags)
        saliencyCenter = try container.decode(CGPoint.self, forKey: .saliencyCenter)
        
        let start = try container.decode(Double.self, forKey: .timeRangeStart)
        let duration = try container.decode(Double.self, forKey: .timeRangeDuration)
        timeRange = CMTimeRangeMake(start: CMTime(seconds: start, preferredTimescale: 600),
                                    duration: CMTime(seconds: duration, preferredTimescale: 600))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sourceURL, forKey: .sourceURL)
        try container.encode(qualityScore, forKey: .qualityScore)
        try container.encode(tags, forKey: .tags)
        try container.encode(saliencyCenter, forKey: .saliencyCenter)
        try container.encode(timeRange.start.seconds, forKey: .timeRangeStart)
        try container.encode(timeRange.duration.seconds, forKey: .timeRangeDuration)
    }
    
    // MARK: - Helper Methods
    
    /// Crée une copie avec une nouvelle durée (pour trim)
    func withTimeRange(_ newRange: CMTimeRange) -> VideoSegment {
        VideoSegment(
            id: self.id,
            sourceURL: self.sourceURL,
            timeRange: newRange,
            qualityScore: self.qualityScore,
            tags: self.tags,
            saliencyCenter: self.saliencyCenter
        )
    }
    
    /// Durée en secondes (helper)
    var duration: TimeInterval {
        timeRange.duration.seconds
    }
    
    /// Position de début en secondes (helper)
    var startTime: TimeInterval {
        timeRange.start.seconds
    }
}