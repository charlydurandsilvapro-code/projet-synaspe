import Foundation
import CoreMedia
import CoreGraphics

struct VideoSegment: Identifiable, Codable {
    let id: UUID
    let sourceURL: URL
    let timeRange: CMTimeRange
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
}