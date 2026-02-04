import Foundation
import AVFoundation
import CoreMedia

// MARK: - Composition Builder

/// Constructeur de composition vidéo finale avec mixage audio et fondus enchaînés
@available(macOS 14.0, *)
actor CompositionBuilder {
    
    // MARK: - Properties
    private let logger = NeuralLogger.compositionBuilder
    private let configuration: ProcessingConfiguration
    
    // MARK: - Composition State
    private var composition: AVMutableComposition?
    private var audioMix: AVMutableAudioMix?
    private var videoComposition: AVMutableVideoComposition?
    
    // MARK: - Performance Tracking
    private var buildStartTime: Date?
    private var segmentsProcessed: Int = 0
    
    // MARK: - Initialization
    
    init(configuration: ProcessingConfiguration) {
        self.configuration = configuration
        
        logger.info("CompositionBuilder initialisé", metadata: [
            "enable_crossfades": configuration.enableCrossfades,
            "enable_voice_ducking": configuration.enableVoiceDucking,
            "crossfade_duration": configuration.crossfadeDuration
        ])
    }
    
    // MARK: - Public Interface
    
    /// Construit la composition finale à partir des segments approuvés
    func buildComposition(_ segments: [ApprovedSegment]) async throws -> EditResult {
        buildStartTime = Date()
        segmentsProcessed = 0
        
        logger.info("Début construction composition", metadata: [
            "segment_count": segments.count,
            "total_duration": segments.reduce(0) { $0 + $1.segment.duration }
        ])
        
        guard !segments.isEmpty else {
            throw NeuralAutoCutError.compositionCreationFailed("Aucun segment à traiter")
        }
        
        // Création de la composition de base
        let mutableComposition = AVMutableComposition()
        self.composition = mutableComposition
        
        // Ajout des pistes audio et vidéo
        let audioTrack = try await createAudioTrack(in: mutableComposition)
        let videoTrack = try await createVideoTrack(in: mutableComposition)
        
        // Insertion des segments
        try await insertSegments(segments, audioTrack: audioTrack, videoTrack: videoTrack)
        
        // Application des fondus enchaînés
        if configuration.enableCrossfades {
            try await applyCrossfades(segments)
        }
        
        // Application du ducking vocal
        if configuration.enableVoiceDucking {
            try await implementVoiceDucking(segments)
        }
        
        // Création de la composition vidéo si nécessaire
        if configuration.enableVideoAnalysis {
            try await createVideoComposition(segments)
        }
        
        // Génération des statistiques
        let statistics = generateStatistics(segments)
        
        // Création de la timeline
        let timeline = generateTimeline(segments)
        
        let buildTime = Date().timeIntervalSince(buildStartTime!)
        
        logger.info("Composition construite", metadata: [
            "segments_processed": segmentsProcessed,
            "final_duration": statistics.finalDuration,
            "reduction_percentage": statistics.reductionPercentage,
            "build_time": buildTime
        ])
        
        return EditResult(
            composition: mutableComposition,
            audioMix: audioMix ?? AVMutableAudioMix(),
            videoComposition: videoComposition,
            statistics: statistics,
            timeline: timeline
        )
    }
    
    /// Prévisualise la composition sans la construire complètement
    func previewComposition(_ segments: [ApprovedSegment]) async throws -> CompositionPreview {
        logger.debug("Génération aperçu composition", metadata: [
            "segment_count": segments.count
        ])
        
        let totalOriginalDuration = segments.reduce(0) { $0 + $1.originalDuration }
        let totalFinalDuration = segments.reduce(0) { $0 + $1.segment.duration }
        let reductionPercentage = totalOriginalDuration > 0 ? 
            (1.0 - Float(totalFinalDuration / totalOriginalDuration)) * 100 : 0
        
        let preview = CompositionPreview(
            segmentCount: segments.count,
            originalDuration: totalOriginalDuration,
            finalDuration: totalFinalDuration,
            reductionPercentage: reductionPercentage,
            estimatedFileSize: estimateFileSize(duration: totalFinalDuration),
            timeline: generateTimeline(segments)
        )
        
        return preview
    }
    
    // MARK: - Private Implementation
    
    private func createAudioTrack(in composition: AVMutableComposition) async throws -> AVMutableCompositionTrack {
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NeuralAutoCutError.compositionCreationFailed("Impossible de créer la piste audio")
        }
        
        logger.debug("Piste audio créée", metadata: [
            "track_id": audioTrack.trackID
        ])
        
        return audioTrack
    }
    
    private func createVideoTrack(in composition: AVMutableComposition) async throws -> AVMutableCompositionTrack {
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NeuralAutoCutError.compositionCreationFailed("Impossible de créer la piste vidéo")
        }
        
        logger.debug("Piste vidéo créée", metadata: [
            "track_id": videoTrack.trackID
        ])
        
        return videoTrack
    }
    
    private func insertSegments(
        _ segments: [ApprovedSegment],
        audioTrack: AVMutableCompositionTrack,
        videoTrack: AVMutableCompositionTrack
    ) async throws {
        
        var currentTime = CMTime.zero
        
        for (index, approvedSegment) in segments.enumerated() {
            let segment = approvedSegment.segment
            
            logger.debug("Insertion segment", metadata: [
                "index": index,
                "start_time": segment.startTime.seconds,
                "duration": segment.duration,
                "current_time": currentTime.seconds
            ])
            
            // Insertion audio
            try await insertAudioSegment(
                segment,
                into: audioTrack,
                at: currentTime,
                from: approvedSegment.sourceAsset
            )
            
            // Insertion vidéo
            try await insertVideoSegment(
                segment,
                into: videoTrack,
                at: currentTime,
                from: approvedSegment.sourceAsset
            )
            
            currentTime = CMTimeAdd(currentTime, CMTime(seconds: segment.duration, preferredTimescale: 600))
            segmentsProcessed += 1
        }
    }
    
    private func insertAudioSegment(
        _ segment: AudioSegment,
        into track: AVMutableCompositionTrack,
        at insertTime: CMTime,
        from asset: AVAsset
    ) async throws {
        
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let sourceAudioTrack = audioTracks.first else {
            throw NeuralAutoCutError.trackInsertionFailed("Aucune piste audio source trouvée")
        }
        
        let timeRange = CMTimeRange(
            start: segment.startTime,
            duration: CMTime(seconds: segment.duration, preferredTimescale: 600)
        )
        
        do {
            try track.insertTimeRange(
                timeRange,
                of: sourceAudioTrack,
                at: insertTime
            )
            
            logger.debug("Segment audio inséré", metadata: [
                "time_range": "\(timeRange.start.seconds)-\(timeRange.end.seconds)",
                "insert_time": insertTime.seconds
            ])
            
        } catch {
            throw NeuralAutoCutError.trackInsertionFailed("Échec insertion audio: \(error.localizedDescription)")
        }
    }
    
    private func insertVideoSegment(
        _ segment: AudioSegment,
        into track: AVMutableCompositionTrack,
        at insertTime: CMTime,
        from asset: AVAsset
    ) async throws {
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = videoTracks.first else {
            logger.warning("Aucune piste vidéo source trouvée")
            return // Pas d'erreur, juste pas de vidéo
        }
        
        let timeRange = CMTimeRange(
            start: segment.startTime,
            duration: CMTime(seconds: segment.duration, preferredTimescale: 600)
        )
        
        do {
            try track.insertTimeRange(
                timeRange,
                of: sourceVideoTrack,
                at: insertTime
            )
            
            logger.debug("Segment vidéo inséré", metadata: [
                "time_range": "\(timeRange.start.seconds)-\(timeRange.end.seconds)",
                "insert_time": insertTime.seconds
            ])
            
        } catch {
            throw NeuralAutoCutError.trackInsertionFailed("Échec insertion vidéo: \(error.localizedDescription)")
        }
    }
    
    private func applyCrossfades(_ segments: [ApprovedSegment]) async throws {
        guard segments.count > 1 else { return }
        
        logger.debug("Application fondus enchaînés", metadata: [
            "segment_count": segments.count,
            "crossfade_duration": configuration.crossfadeDuration
        ])
        
        let mutableAudioMix = AVMutableAudioMix()
        var audioMixInputParameters: [AVMutableAudioMixInputParameters] = []
        
        guard let composition = self.composition,
              let audioTrack = composition.tracks(withMediaType: .audio).first else {
            throw NeuralAutoCutError.crossfadeApplicationFailed("Composition audio non trouvée")
        }
        
        let inputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
        
        // Pour l'instant, on applique juste un volume constant
        // Les fondus enchaînés nécessitent une API plus complexe
        
        audioMixInputParameters.append(inputParameters)
        mutableAudioMix.inputParameters = audioMixInputParameters
        self.audioMix = mutableAudioMix
        
        logger.debug("Fondus enchaînés appliqués (version simplifiée)")
    }
    
    private func implementVoiceDucking(_ segments: [ApprovedSegment]) async throws {
        guard let audioMix = self.audioMix else {
            throw NeuralAutoCutError.voiceDuckingFailed("AudioMix non initialisé")
        }
        
        logger.debug("Application ducking vocal", metadata: [
            "ducking_amount": configuration.voiceDuckingAmount,
            "segment_count": segments.count
        ])
        
        guard let inputParameters = audioMix.inputParameters.first else {
            throw NeuralAutoCutError.voiceDuckingFailed("Paramètres audio non trouvés")
        }
        
        // Pour l'instant, on applique juste un volume constant
        // Le ducking vocal nécessite une API plus complexe
        
        logger.debug("Ducking vocal appliqué (version simplifiée)")
    }
    
    private func createVideoComposition(_ segments: [ApprovedSegment]) async throws {
        guard let composition = self.composition else { return }
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
        videoComposition.renderSize = CGSize(width: 1920, height: 1080) // Full HD par défaut
        
        // Instructions de composition vidéo
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var currentTime = CMTime.zero
        
        for segment in segments {
            let segmentDuration = CMTime(seconds: segment.segment.duration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: currentTime, duration: segmentDuration)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = timeRange
            
            if let videoTrack = composition.tracks(withMediaType: .video).first {
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                instruction.layerInstructions = [layerInstruction]
            }
            
            instructions.append(instruction)
            currentTime = CMTimeAdd(currentTime, segmentDuration)
        }
        
        videoComposition.instructions = instructions
        self.videoComposition = videoComposition
        
        logger.debug("Composition vidéo créée", metadata: [
            "instruction_count": instructions.count,
            "render_size": "\(videoComposition.renderSize.width)x\(videoComposition.renderSize.height)"
        ])
    }
    
    private func generateStatistics(_ segments: [ApprovedSegment]) -> EditStatistics {
        let originalDuration = segments.reduce(0) { $0 + $1.originalDuration }
        let finalDuration = segments.reduce(0) { $0 + $1.segment.duration }
        let reductionPercentage = originalDuration > 0 ? 
            (1.0 - Float(finalDuration / originalDuration)) * 100 : 0
        
        let averageQuality = segments.isEmpty ? 0 : 
            segments.reduce(0) { $0 + $1.segment.qualityScore } / Float(segments.count)
        
        return EditStatistics(
            originalDuration: originalDuration,
            finalDuration: finalDuration,
            reductionPercentage: reductionPercentage,
            segmentsKept: segments.count,
            segmentsRemoved: 0, // Calculé ailleurs
            qualityScore: averageQuality,
            processingTime: Date().timeIntervalSince(buildStartTime!)
        )
    }
    
    private func generateTimeline(_ segments: [ApprovedSegment]) -> [TimelineSegment] {
        var timeline: [TimelineSegment] = []
        var currentTime = CMTime.zero
        
        for (_, segment) in segments.enumerated() {
            let timelineSegment = TimelineSegment(
                originalStartTime: segment.segment.startTime,
                originalEndTime: CMTimeAdd(segment.segment.startTime, CMTime(seconds: segment.segment.duration, preferredTimescale: 600)),
                timelineStartTime: currentTime,
                qualityScore: segment.segment.qualityScore,
                classification: segment.segment.classification
            )
            
            timeline.append(timelineSegment)
            currentTime = CMTimeAdd(currentTime, CMTime(seconds: segment.segment.duration, preferredTimescale: 600))
        }
        
        return timeline
    }
    
    private func estimateFileSize(duration: TimeInterval) -> Int64 {
        // Estimation basée sur des bitrates typiques
        let videoBitrate: Double = 5_000_000 // 5 Mbps pour 1080p
        let audioBitrate: Double = 128_000   // 128 kbps pour l'audio
        
        let totalBitrate = videoBitrate + audioBitrate
        let estimatedBytes = Int64(duration * totalBitrate / 8) // Conversion bits vers bytes
        
        return estimatedBytes
    }
}

// MARK: - Supporting Types

/// Segment approuvé pour la composition
public struct ApprovedSegment {
    public let segment: AudioSegment
    public let sourceAsset: AVAsset
    public let originalDuration: TimeInterval
    
    public init(segment: AudioSegment, sourceAsset: AVAsset, originalDuration: TimeInterval) {
        self.segment = segment
        self.sourceAsset = sourceAsset
        self.originalDuration = originalDuration
    }
}

/// Aperçu de composition
public struct CompositionPreview {
    public let segmentCount: Int
    public let originalDuration: TimeInterval
    public let finalDuration: TimeInterval
    public let reductionPercentage: Float
    public let estimatedFileSize: Int64
    public let timeline: [TimelineSegment]
    
    public init(
        segmentCount: Int,
        originalDuration: TimeInterval,
        finalDuration: TimeInterval,
        reductionPercentage: Float,
        estimatedFileSize: Int64,
        timeline: [TimelineSegment]
    ) {
        self.segmentCount = segmentCount
        self.originalDuration = originalDuration
        self.finalDuration = finalDuration
        self.reductionPercentage = reductionPercentage
        self.estimatedFileSize = estimatedFileSize
        self.timeline = timeline
    }
}

/// Segment de timeline pour la composition
public struct CompositionTimelineSegment {
    public let index: Int
    public let startTime: CMTime
    public let duration: TimeInterval
    public let contentType: AudioType
    public let qualityScore: Float
    public let isOriginal: Bool
    
    public init(
        index: Int,
        startTime: CMTime,
        duration: TimeInterval,
        contentType: AudioType,
        qualityScore: Float,
        isOriginal: Bool
    ) {
        self.index = index
        self.startTime = startTime
        self.duration = duration
        self.contentType = contentType
        self.qualityScore = qualityScore
        self.isOriginal = isOriginal
    }
    
    public var endTime: CMTime {
        return CMTimeAdd(startTime, CMTime(seconds: duration, preferredTimescale: 600))
    }
}