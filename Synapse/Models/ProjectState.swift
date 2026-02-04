import Foundation
import CoreGraphics

enum ColorProfile: String, Codable, CaseIterable {
    case cinematic
    case vivid
    case blackAndWhite
    case natural
}

struct ProjectState: Codable {
    var id: UUID
    var timeline: [VideoSegment]
    var musicTrack: AudioTrack?
    var globalColorProfile: ColorProfile
    var aspectRatio: CGSize
    var createdAt: Date
    var modifiedAt: Date
    
    init(id: UUID = UUID(),
         timeline: [VideoSegment] = [],
         musicTrack: AudioTrack? = nil,
         globalColorProfile: ColorProfile = .cinematic,
         aspectRatio: CGSize = CGSize(width: 1080, height: 1920),
         createdAt: Date = Date(),
         modifiedAt: Date = Date()) {
        self.id = id
        self.timeline = timeline
        self.musicTrack = musicTrack
        self.globalColorProfile = globalColorProfile
        self.aspectRatio = aspectRatio
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}