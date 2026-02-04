import XCTest
@testable import Synapse

final class SynapseTests: XCTestCase {
    
    func testProjectStateInitialization() {
        let project = ProjectState()
        
        XCTAssertNotNil(project.id)
        XCTAssertTrue(project.timeline.isEmpty)
        XCTAssertNil(project.musicTrack)
        XCTAssertEqual(project.globalColorProfile, .cinematic)
        XCTAssertEqual(project.aspectRatio.width, 1080)
        XCTAssertEqual(project.aspectRatio.height, 1920)
    }
    
    func testVideoSegmentCreation() {
        let url = URL(fileURLWithPath: "/test/video.mp4")
        let timeRange = CMTimeRange(
            start: CMTime.zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        
        let segment = VideoSegment(
            sourceURL: url,
            timeRange: timeRange,
            qualityScore: 0.8,
            tags: ["test", "sample"],
            saliencyCenter: CGPoint(x: 0.5, y: 0.5)
        )
        
        XCTAssertEqual(segment.sourceURL, url)
        XCTAssertEqual(segment.timeRange.duration.seconds, 5.0, accuracy: 0.1)
        XCTAssertEqual(segment.qualityScore, 0.8)
        XCTAssertEqual(segment.tags.count, 2)
        XCTAssertTrue(segment.tags.contains("test"))
    }
    
    func testAudioTrackInitialization() {
        let url = URL(fileURLWithPath: "/test/audio.mp3")
        let audioTrack = AudioTrack(url: url, bpm: 120.0)
        
        XCTAssertEqual(audioTrack.url, url)
        XCTAssertEqual(audioTrack.bpm, 120.0)
        XCTAssertTrue(audioTrack.beatGrid.isEmpty)
        XCTAssertTrue(audioTrack.energyProfile.isEmpty)
    }
    
    func testBeatMarkerCreation() {
        let beatMarker = BeatMarker(
            timestamp: 1.5,
            confidence: 0.9,
            isDownbeat: true
        )
        
        XCTAssertEqual(beatMarker.timestamp, 1.5)
        XCTAssertEqual(beatMarker.confidence, 0.9)
        XCTAssertTrue(beatMarker.isDownbeat)
    }
    
    func testEnergySegmentCreation() {
        let energySegment = EnergySegment(
            startTime: 0.0,
            duration: 4.0,
            level: .high,
            rmsAmplitude: 0.7
        )
        
        XCTAssertEqual(energySegment.startTime, 0.0)
        XCTAssertEqual(energySegment.duration, 4.0)
        XCTAssertEqual(energySegment.level, .high)
        XCTAssertEqual(energySegment.rmsAmplitude, 0.7)
    }
    
    func testColorProfileEnum() {
        XCTAssertEqual(ColorProfile.cinematic.rawValue, "cinematic")
        XCTAssertEqual(ColorProfile.vivid.rawValue, "vivid")
        XCTAssertEqual(ColorProfile.blackAndWhite.rawValue, "blackAndWhite")
    }
    
    func testEnergyLevelEnum() {
        XCTAssertEqual(EnergyLevel.low.rawValue, "low")
        XCTAssertEqual(EnergyLevel.mid.rawValue, "mid")
        XCTAssertEqual(EnergyLevel.high.rawValue, "high")
    }
}