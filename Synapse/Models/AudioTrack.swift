import Foundation

struct AudioTrack: Codable {
    let url: URL
    let bpm: Float
    let beatGrid: [BeatMarker]
    let energyProfile: [EnergySegment]
    
    init(url: URL, bpm: Float = 0, beatGrid: [BeatMarker] = [], energyProfile: [EnergySegment] = []) {
        self.url = url
        self.bpm = bpm
        self.beatGrid = beatGrid
        self.energyProfile = energyProfile
    }
}

struct BeatMarker: Codable {
    let timestamp: TimeInterval
    let confidence: Float
    let isDownbeat: Bool
}

enum EnergyLevel: String, Codable {
    case low, mid, high
}

struct EnergySegment: Codable {
    let startTime: TimeInterval
    let duration: TimeInterval
    let level: EnergyLevel
    let rmsAmplitude: Float
}