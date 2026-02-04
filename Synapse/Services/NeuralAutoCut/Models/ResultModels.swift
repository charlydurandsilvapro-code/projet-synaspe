import Foundation
import AVFoundation
import CoreMedia

// MARK: - Edit Result

/// Résultat final du traitement Neural Auto-Cut
public struct EditResult {
    public let composition: AVMutableComposition
    public let audioMix: AVMutableAudioMix
    public let videoComposition: AVMutableVideoComposition?
    public let statistics: EditStatistics
    public let timeline: [TimelineSegment]
    public let metadata: EditMetadata
    
    public init(
        composition: AVMutableComposition,
        audioMix: AVMutableAudioMix,
        videoComposition: AVMutableVideoComposition? = nil,
        statistics: EditStatistics,
        timeline: [TimelineSegment],
        metadata: EditMetadata = EditMetadata()
    ) {
        self.composition = composition
        self.audioMix = audioMix
        self.videoComposition = videoComposition
        self.statistics = statistics
        self.timeline = timeline
        self.metadata = metadata
    }
    
    /// Durée totale de la composition finale
    public var totalDuration: TimeInterval {
        timeline.reduce(0) { $0 + $1.duration }
    }
    
    /// Nombre de segments conservés
    public var segmentCount: Int {
        timeline.count
    }
}

// MARK: - Edit Statistics

/// Statistiques détaillées du traitement
public struct EditStatistics {
    public let originalDuration: TimeInterval
    public let finalDuration: TimeInterval
    public let reductionPercentage: Float
    public let segmentsKept: Int
    public let segmentsRemoved: Int
    public let qualityScore: Float
    public let processingTime: TimeInterval
    public let memoryUsage: MemoryUsageStats
    public let analysisStats: AnalysisStatistics
    
    public init(
        originalDuration: TimeInterval,
        finalDuration: TimeInterval,
        reductionPercentage: Float,
        segmentsKept: Int,
        segmentsRemoved: Int,
        qualityScore: Float,
        processingTime: TimeInterval,
        memoryUsage: MemoryUsageStats = MemoryUsageStats(),
        analysisStats: AnalysisStatistics = AnalysisStatistics()
    ) {
        self.originalDuration = originalDuration
        self.finalDuration = finalDuration
        self.reductionPercentage = reductionPercentage
        self.segmentsKept = segmentsKept
        self.segmentsRemoved = segmentsRemoved
        self.qualityScore = qualityScore
        self.processingTime = processingTime
        self.memoryUsage = memoryUsage
        self.analysisStats = analysisStats
    }
    
    /// Ratio de compression (0.0 à 1.0)
    public var compressionRatio: Float {
        guard originalDuration > 0 else { return 0 }
        return Float(finalDuration / originalDuration)
    }
    
    /// Temps économisé en secondes
    public var timeSaved: TimeInterval {
        originalDuration - finalDuration
    }
    
    /// Efficacité du traitement (durée finale / temps de traitement)
    public var processingEfficiency: Float {
        guard processingTime > 0 else { return 0 }
        return Float(finalDuration / processingTime)
    }
}

// MARK: - Timeline Segment

/// Segment dans la timeline finale
public struct TimelineSegment: Identifiable {
    public let id: UUID
    public let originalStartTime: CMTime
    public let originalEndTime: CMTime
    public let timelineStartTime: CMTime
    public let duration: TimeInterval
    public let qualityScore: Float
    public let classification: AudioClassification
    public let transitions: SegmentTransitions
    public let metadata: SegmentMetadata
    
    public init(
        id: UUID = UUID(),
        originalStartTime: CMTime,
        originalEndTime: CMTime,
        timelineStartTime: CMTime,
        qualityScore: Float,
        classification: AudioClassification,
        transitions: SegmentTransitions = SegmentTransitions(),
        metadata: SegmentMetadata = SegmentMetadata()
    ) {
        self.id = id
        self.originalStartTime = originalStartTime
        self.originalEndTime = originalEndTime
        self.timelineStartTime = timelineStartTime
        self.duration = originalEndTime.seconds - originalStartTime.seconds
        self.qualityScore = qualityScore
        self.classification = classification
        self.transitions = transitions
        self.metadata = metadata
    }
    
    /// Temps de fin dans la timeline
    public var timelineEndTime: CMTime {
        CMTimeAdd(timelineStartTime, CMTime(seconds: duration, preferredTimescale: 600))
    }
    
    /// Range temporel original
    public var originalTimeRange: CMTimeRange {
        CMTimeRangeMake(start: originalStartTime, duration: CMTime(seconds: duration, preferredTimescale: 600))
    }
    
    /// Range temporel dans la timeline
    public var timelineTimeRange: CMTimeRange {
        CMTimeRangeMake(start: timelineStartTime, duration: CMTime(seconds: duration, preferredTimescale: 600))
    }
}

// MARK: - Segment Transitions

/// Transitions appliquées à un segment
public struct SegmentTransitions {
    public let fadeIn: TransitionInfo?
    public let fadeOut: TransitionInfo?
    public let crossfadeIn: CrossfadeInfo?
    public let crossfadeOut: CrossfadeInfo?
    public let voiceDucking: VoiceDuckingInfo?
    
    public init(
        fadeIn: TransitionInfo? = nil,
        fadeOut: TransitionInfo? = nil,
        crossfadeIn: CrossfadeInfo? = nil,
        crossfadeOut: CrossfadeInfo? = nil,
        voiceDucking: VoiceDuckingInfo? = nil
    ) {
        self.fadeIn = fadeIn
        self.fadeOut = fadeOut
        self.crossfadeIn = crossfadeIn
        self.crossfadeOut = crossfadeOut
        self.voiceDucking = voiceDucking
    }
}

/// Information sur une transition
public struct TransitionInfo {
    public let duration: TimeInterval
    public let curve: TransitionCurve
    public let startLevel: Float
    public let endLevel: Float
    
    public init(duration: TimeInterval, curve: TransitionCurve, startLevel: Float, endLevel: Float) {
        self.duration = duration
        self.curve = curve
        self.startLevel = startLevel
        self.endLevel = endLevel
    }
}

/// Information sur un fondu enchaîné
public struct CrossfadeInfo {
    public let duration: TimeInterval
    public let overlappingSegmentId: UUID
    public let crossfadeType: CrossfadeType
    
    public init(duration: TimeInterval, overlappingSegmentId: UUID, crossfadeType: CrossfadeType) {
        self.duration = duration
        self.overlappingSegmentId = overlappingSegmentId
        self.crossfadeType = crossfadeType
    }
}

/// Information sur le ducking vocal
public struct VoiceDuckingInfo {
    public let duckingAmount: Float // en dB
    public let attackTime: TimeInterval
    public let releaseTime: TimeInterval
    public let speechSegments: [CMTimeRange]
    
    public init(duckingAmount: Float, attackTime: TimeInterval, releaseTime: TimeInterval, speechSegments: [CMTimeRange]) {
        self.duckingAmount = duckingAmount
        self.attackTime = attackTime
        self.releaseTime = releaseTime
        self.speechSegments = speechSegments
    }
}

// MARK: - Enums

/// Types de courbes de transition
public enum TransitionCurve: String, CaseIterable {
    case linear = "Linéaire"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In-Out"
    case exponential = "Exponentielle"
}

/// Types de fondu enchaîné
public enum CrossfadeType: String, CaseIterable {
    case equalPower = "Equal Power"
    case linear = "Linéaire"
    case constantGain = "Gain Constant"
}

// MARK: - Metadata

/// Métadonnées du segment
public struct SegmentMetadata {
    public let tags: [String]
    public let confidence: Float
    public let processingNotes: [String]
    public let beatAlignment: BeatAlignment?
    public let videoQuality: VideoQualityScore?
    
    public init(
        tags: [String] = [],
        confidence: Float = 1.0,
        processingNotes: [String] = [],
        beatAlignment: BeatAlignment? = nil,
        videoQuality: VideoQualityScore? = nil
    ) {
        self.tags = tags
        self.confidence = confidence
        self.processingNotes = processingNotes
        self.beatAlignment = beatAlignment
        self.videoQuality = videoQuality
    }
}

/// Métadonnées de l'édition
public struct EditMetadata {
    public let processingDate: Date
    public let engineVersion: String
    public let configuration: ProcessingConfiguration?
    public let sourceInfo: SourceInfo?
    
    public init(
        processingDate: Date = Date(),
        engineVersion: String = "1.0.0",
        configuration: ProcessingConfiguration? = nil,
        sourceInfo: SourceInfo? = nil
    ) {
        self.processingDate = processingDate
        self.engineVersion = engineVersion
        self.configuration = configuration
        self.sourceInfo = sourceInfo
    }
}

/// Information sur la source
public struct SourceInfo {
    public let originalURL: URL
    public let fileSize: Int64
    public let duration: TimeInterval
    public let videoCodec: String?
    public let audioCodec: String?
    public let resolution: CGSize?
    public let frameRate: Float?
    
    public init(
        originalURL: URL,
        fileSize: Int64,
        duration: TimeInterval,
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        resolution: CGSize? = nil,
        frameRate: Float? = nil
    ) {
        self.originalURL = originalURL
        self.fileSize = fileSize
        self.duration = duration
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.resolution = resolution
        self.frameRate = frameRate
    }
}

// MARK: - Memory and Performance Stats

/// Statistiques d'utilisation mémoire
public struct MemoryUsageStats {
    public let peakMemoryUsage: Int64 // en bytes
    public let averageMemoryUsage: Int64
    public let memoryEfficiency: Float // ratio utilisation/limite
    public let bufferPoolHitRate: Float // efficacité du pool de buffers
    
    public init(
        peakMemoryUsage: Int64 = 0,
        averageMemoryUsage: Int64 = 0,
        memoryEfficiency: Float = 0.0,
        bufferPoolHitRate: Float = 0.0
    ) {
        self.peakMemoryUsage = peakMemoryUsage
        self.averageMemoryUsage = averageMemoryUsage
        self.memoryEfficiency = memoryEfficiency
        self.bufferPoolHitRate = bufferPoolHitRate
    }
    
    /// Utilisation mémoire en MB
    public var peakMemoryMB: Float {
        Float(peakMemoryUsage) / (1024 * 1024)
    }
    
    /// Utilisation mémoire moyenne en MB
    public var averageMemoryMB: Float {
        Float(averageMemoryUsage) / (1024 * 1024)
    }
}

/// Statistiques d'analyse
public struct AnalysisStatistics {
    public let audioAnalysisTime: TimeInterval
    public let videoAnalysisTime: TimeInterval
    public let decisionTime: TimeInterval
    public let compositionTime: TimeInterval
    public let totalSegmentsAnalyzed: Int
    public let speechSegmentsDetected: Int
    public let musicSegmentsDetected: Int
    public let noiseSegmentsDetected: Int
    public let beatsDetected: Int
    public let averageConfidence: Float
    
    public init(
        audioAnalysisTime: TimeInterval = 0,
        videoAnalysisTime: TimeInterval = 0,
        decisionTime: TimeInterval = 0,
        compositionTime: TimeInterval = 0,
        totalSegmentsAnalyzed: Int = 0,
        speechSegmentsDetected: Int = 0,
        musicSegmentsDetected: Int = 0,
        noiseSegmentsDetected: Int = 0,
        beatsDetected: Int = 0,
        averageConfidence: Float = 0.0
    ) {
        self.audioAnalysisTime = audioAnalysisTime
        self.videoAnalysisTime = videoAnalysisTime
        self.decisionTime = decisionTime
        self.compositionTime = compositionTime
        self.totalSegmentsAnalyzed = totalSegmentsAnalyzed
        self.speechSegmentsDetected = speechSegmentsDetected
        self.musicSegmentsDetected = musicSegmentsDetected
        self.noiseSegmentsDetected = noiseSegmentsDetected
        self.beatsDetected = beatsDetected
        self.averageConfidence = averageConfidence
    }
    
    /// Temps total d'analyse
    public var totalAnalysisTime: TimeInterval {
        audioAnalysisTime + videoAnalysisTime + decisionTime + compositionTime
    }
    
    /// Distribution des types de contenu
    public var contentDistribution: (speech: Float, music: Float, noise: Float) {
        let total = Float(totalSegmentsAnalyzed)
        guard total > 0 else { return (0, 0, 0) }
        
        return (
            speech: Float(speechSegmentsDetected) / total,
            music: Float(musicSegmentsDetected) / total,
            noise: Float(noiseSegmentsDetected) / total
        )
    }
}

// MARK: - Composition Result

/// Résultat de construction de composition
public struct CompositionResult {
    public let composition: AVMutableComposition
    public let audioMix: AVMutableAudioMix
    public let timeline: [TimelineSegment]
    public let appliedTransitions: [TransitionApplication]
    
    public init(
        composition: AVMutableComposition,
        audioMix: AVMutableAudioMix,
        timeline: [TimelineSegment],
        appliedTransitions: [TransitionApplication] = []
    ) {
        self.composition = composition
        self.audioMix = audioMix
        self.timeline = timeline
        self.appliedTransitions = appliedTransitions
    }
}

/// Application d'une transition
public struct TransitionApplication {
    public let segmentId: UUID
    public let transitionType: String
    public let startTime: CMTime
    public let duration: TimeInterval
    public let parameters: [String: Any]
    
    public init(segmentId: UUID, transitionType: String, startTime: CMTime, duration: TimeInterval, parameters: [String: Any] = [:]) {
        self.segmentId = segmentId
        self.transitionType = transitionType
        self.startTime = startTime
        self.duration = duration
        self.parameters = parameters
    }
}

// MARK: - Export Options

/// Options d'export pour différents formats
public struct ExportOptions {
    public let format: ExportFormat
    public let quality: ExportQuality
    public let includeMetadata: Bool
    public let preserveOriginalAudio: Bool
    public let customSettings: [String: Any]
    
    public init(
        format: ExportFormat = .mp4,
        quality: ExportQuality = .high,
        includeMetadata: Bool = true,
        preserveOriginalAudio: Bool = false,
        customSettings: [String: Any] = [:]
    ) {
        self.format = format
        self.quality = quality
        self.includeMetadata = includeMetadata
        self.preserveOriginalAudio = preserveOriginalAudio
        self.customSettings = customSettings
    }
}

/// Formats d'export supportés
public enum ExportFormat: String, CaseIterable {
    case mp4 = "MP4"
    case mov = "MOV"
    case fcpxml = "FCPXML"
    case aaf = "AAF"
    case edl = "EDL"
    
    public var fileExtension: String {
        switch self {
        case .mp4: return "mp4"
        case .mov: return "mov"
        case .fcpxml: return "fcpxml"
        case .aaf: return "aaf"
        case .edl: return "edl"
        }
    }
}

/// Qualités d'export
public enum ExportQuality: String, CaseIterable {
    case low = "Faible"
    case medium = "Moyenne"
    case high = "Élevée"
    case lossless = "Sans perte"
    
    public var bitrate: Int {
        switch self {
        case .low: return 2_000_000      // 2 Mbps
        case .medium: return 8_000_000   // 8 Mbps
        case .high: return 20_000_000    // 20 Mbps
        case .lossless: return 0         // Variable/Lossless
        }
    }
}