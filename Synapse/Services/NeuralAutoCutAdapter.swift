import Foundation
import AVFoundation
import CoreMedia

/// Adaptateur entre NeuralAutoCutEngine (architecture avancée) et ProjectViewModel (interface utilisateur)
/// Implémente la philosophie "Le Son dicte l'Image" avec pipeline de traitement structuré
@available(macOS 14.0, *)
@MainActor
class NeuralAutoCutAdapter: ObservableObject {
    
    // MARK: - Pipeline Neural (Architecture Réelle)
    private let neuralEngine: NeuralAutoCutEngine
    private let audioAnalysisPipeline: AudioAnalysisPipeline
    
    // MARK: - État Observable
    @Published var progress: Float = 0.0
    @Published var currentTask: String = ""
    
    init() {
        self.neuralEngine = NeuralAutoCutEngine()
        self.audioAnalysisPipeline = AudioAnalysisPipeline()
    }
    
    // MARK: - Phase 1+2: Extraction & Analyse Audio (Le Son dicte l'Image)
    
    /// Analyse complète d'un fichier audio avec le vrai pipeline FFT
    func analyzeAudio(url: URL) async throws -> DetailedAudioAnalysis {
        currentTask = "Phase 1: Extraction PCM..."
        let asset = AVAsset(url: url)
        
        // Utilisation du vrai AudioAnalysisPipeline (FFT + RMS + Beat Detection)
        currentTask = "Phase 2: Analyse spectrale (FFT)..."
        let analyzedSegments = try await audioAnalysisPipeline.analyzeAudio(asset)
        
        // Phase 3: Extraction des features musicales
        currentTask = "Phase 3: Extraction BPM et beats..."
        let bpm = extractBPM(from: analyzedSegments)
        let beatGrid = extractBeatGrid(from: analyzedSegments)
        let energyProfile = extractEnergyProfile(from: analyzedSegments)
        
        let duration = try await asset.load(.duration).seconds
        
        currentTask = "Analyse audio terminée"
        
        return DetailedAudioAnalysis(
            url: url,
            bpm: bpm,
            beatGrid: beatGrid,
            energyProfile: energyProfile,
            duration: duration,
            confidence: calculateConfidence(from: analyzedSegments)
        )
    }
    
    // MARK: - Phase 3: Classification (Le Cerveau)
    
    /// Extraction du BPM depuis l'analyse rythmique
    private func extractBPM(from segments: [AnalyzedSegment]) -> Float {
        // Extraction du tempo depuis RhythmAnalysis
        let tempos = segments.compactMap { segment -> Float? in
            guard segment.rhythmAnalysis.isRhythmic else { return nil }
            return segment.rhythmAnalysis.estimatedTempo
        }
        
        guard !tempos.isEmpty else { return 120.0 }
        
        // Moyenne pondérée par la force rythmique
        let weightedSum = segments.reduce((sum: Float(0), weight: Float(0))) { result, segment in
            let tempo = segment.rhythmAnalysis.estimatedTempo
            let weight = segment.rhythmAnalysis.rhythmStrength
            return (result.sum + tempo * weight, result.weight + weight)
        }
        
        return weightedSum.weight > 0 ? weightedSum.sum / weightedSum.weight : 120.0
    }
    
    /// Extraction de la grille de beats (Beat Grid)
    private func extractBeatGrid(from segments: [AnalyzedSegment]) -> [BeatMarker] {
        // Collecte tous les beats détectés avec confiance > 0.6
        var allBeats: [BeatPoint] = []
        
        for segment in segments {
            let strongBeats = segment.rhythmAnalysis.detectedBeats.filter { $0.confidence > 0.6 }
            allBeats.append(contentsOf: strongBeats)
        }
        
        // Tri chronologique et conversion en BeatMarker
        return allBeats
            .sorted { $0.timestamp.seconds < $1.timestamp.seconds }
            .map { beatPoint in
                BeatMarker(
                    timestamp: beatPoint.timestamp.seconds,
                    confidence: beatPoint.confidence,
                    isDownbeat: beatPoint.type == .kick  // Kick = downbeat
                )
            }
    }
    
    /// Extraction du profil énergétique (courbe d'énergie)
    private func extractEnergyProfile(from segments: [AnalyzedSegment]) -> [EnergySegment] {
        return segments.map { segment in
            // RMS Level -> Niveau d'énergie normalisé
            let normalizedEnergy = normalizeRMS(segment.segment.rmsLevel)
            let energyLevel: EnergyLevel = categorizeEnergy(normalizedEnergy)
            
            return EnergySegment(
                startTime: segment.segment.startTime.seconds,
                duration: segment.segment.duration,
                level: energyLevel,
                rmsAmplitude: segment.segment.rmsLevel
            )
        }
    }
    
    /// Catégorisation de l'énergie en low/mid/high
    private func categorizeEnergy(_ normalized: Float) -> EnergyLevel {
        if normalized < 0.3 {
            return .low
        } else if normalized < 0.7 {
            return .mid
        } else {
            return .high
        }
    }
    
    /// Normalisation du RMS en niveau d'énergie (0.0 à 1.0)
    private func normalizeRMS(_ rms: Float) -> Float {
        // Conversion RMS -> dB -> Normalized (0-1)
        let db = 20.0 * log10(max(rms, 1e-10))
        let minDB: Float = -60.0  // Seuil de silence
        let maxDB: Float = 0.0    // Volume max
        
        return max(0.0, min(1.0, (db - minDB) / (maxDB - minDB)))
    }
    
    /// Calcul de la confiance globale de l'analyse
    private func calculateConfidence(from segments: [AnalyzedSegment]) -> Float {
        guard !segments.isEmpty else { return 0.0 }
        
        let avgConfidence = segments.reduce(Float(0)) { sum, segment in
            sum + segment.contentAnalysis.confidence
        } / Float(segments.count)
        
        return avgConfidence
    }
    
    // MARK: - Phase 4+5: Décision, Padding & Reconstruction (Le Montage)
    
    /// Traitement vidéo complet avec le Neural Engine (Dérush intelligent)
    func processVideo(
        url: URL,
        silenceThreshold: Float = -45.0,
        minSilenceDuration: TimeInterval = 0.5,
        paddingBefore: TimeInterval = 0.15,
        paddingAfter: TimeInterval = 0.2,
        enableBeatSync: Bool = true,
        enableSceneDetection: Bool = true
    ) async throws -> [VideoSegment] {
        
        currentTask = "Phase 1: Chargement de l'asset..."
        let asset = AVAsset(url: url)
        
        // Configuration du pipeline Neural avec vrais paramètres
        currentTask = "Configuration du pipeline..."
        let config = ProcessingConfiguration(
            silenceThreshold: silenceThreshold,
            minimumSilenceDuration: minSilenceDuration,
            silenceDetectionSensitivity: .medium,
            speechSensitivity: .medium,
            speechPreservationMode: .aggressive,
            minimumSpeechDuration: 0.2,
            rhythmMode: enableBeatSync ? .aggressive : .disabled,
            beatAlignmentTolerance: 0.05,  // ±50ms
            enableVideoAnalysis: enableSceneDetection,
            enableCrossfades: true,
            crossfadeDuration: 0.02,  // 20ms
            qualityThreshold: 0.4,
            minimumSegmentDuration: 0.5
        )
        
        // Phase 2-3-4: Analyse complète avec Neural Engine
        currentTask = "Phase 2-4: Analyse Neural (FFT + VAD + Décision)..."
        let result = try await neuralEngine.processVideo(asset: asset, configuration: config)
        
        // Phase 5: Conversion TimelineSegment -> VideoSegment
        currentTask = "Phase 5: Reconstruction timeline..."
        let videoSegments = convertToVideoSegments(
            neuralTimeline: result.timeline,
            sourceURL: url,
            paddingBefore: paddingBefore,
            paddingAfter: paddingAfter
        )
        
        currentTask = "Traitement terminé (\(videoSegments.count) segments conservés)"
        progress = 1.0
        
        return videoSegments
    }
    
    /// Conversion TimelineSegment (Neural) -> VideoSegment (App)
    private func convertToVideoSegments(
        neuralTimeline: [TimelineSegment],
        sourceURL: URL,
        paddingBefore: TimeInterval,
        paddingAfter: TimeInterval
    ) -> [VideoSegment] {
        
        return neuralTimeline.map { neuralSeg in
            // Application du padding (Phase 4)
            let paddedStart = CMTimeSubtract(
                neuralSeg.originalStartTime,
                CMTime(seconds: paddingBefore, preferredTimescale: 600)
            )
            let paddedEnd = CMTimeAdd(
                neuralSeg.originalEndTime,
                CMTime(seconds: paddingAfter, preferredTimescale: 600)
            )
            
            // Clamp aux limites du fichier
            let finalStart = max(paddedStart, .zero)
            let finalDuration = CMTimeSubtract(paddedEnd, finalStart)
            
            // Conversion de la classification Neural en tags lisibles
            let tags = convertClassificationToTags(neuralSeg.classification)
            
            return VideoSegment(
                id: neuralSeg.id,
                sourceURL: sourceURL,
                timeRange: CMTimeRange(start: finalStart, duration: finalDuration),
                qualityScore: neuralSeg.qualityScore,
                tags: tags,
                saliencyCenter: extractSaliencyCenter(from: neuralSeg.metadata)
            )
        }
    }
    
    /// Conversion AudioClassification -> Tags compréhensibles
    private func convertClassificationToTags(_ classification: AudioClassification) -> [String] {
        var tags: [String] = []
        
        // Tag principal basé sur le type dominant
        switch classification.dominantType {
        case .speech:
            tags.append("parole")
            if classification.confidence > 0.8 {
                tags.append("haute-confiance")
            }
        case .music:
            tags.append("musique")
            if classification.music > 0.7 {
                tags.append("musical")
            }
        case .noise:
            tags.append("bruit")
            if classification.confidence < 0.5 {
                tags.append("incertain")
            }
        }
        
        // Tags secondaires
        if classification.speech > 0.3 {
            tags.append("contient-voix")
        }
        if classification.music > 0.4 {
            tags.append("contient-musique")
        }
        
        tags.append("neural-cut")
        tags.append("qualité-\(Int(classification.confidence * 100))")
        
        return tags
    }
    
    /// Extraction du centre de saillance depuis les métadonnées
    private func extractSaliencyCenter(from metadata: SegmentMetadata) -> CGPoint {
        // TODO: Parser metadata pour extraire la position du sujet principal
        // Pour l'instant, centre par défaut
        return CGPoint(x: 0.5, y: 0.5)
    }
    
    // MARK: - Export avec Composition (Phase 5 complète)
    
    /// Export d'un projet complet avec AVMutableComposition
    func exportDerush(
        segments: [VideoSegment],
        outputURL: URL
    ) async throws {
        
        currentTask = "Création de la composition AVFoundation..."
        
        // Création de la composition
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NeuralAutoCutError.exportFailed("Impossible de créer la piste vidéo")
        }
        
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NeuralAutoCutError.exportFailed("Impossible de créer la piste audio")
        }
        
        // Insertion des segments dans la timeline
        var currentTime = CMTime.zero
        
        for (index, segment) in segments.enumerated() {
            currentTask = "Insertion segment \(index + 1)/\(segments.count)..."
            progress = Float(index) / Float(segments.count)
            
            let asset = AVAsset(url: segment.sourceURL)
            
            // Tracks source
            guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
                  let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                continue
            }
            
            // Insertion synchronisée vidéo + audio
            try videoTrack.insertTimeRange(
                segment.timeRange,
                of: sourceVideoTrack,
                at: currentTime
            )
            
            try audioTrack.insertTimeRange(
                segment.timeRange,
                of: sourceAudioTrack,
                at: currentTime
            )
            
            currentTime = CMTimeAdd(currentTime, segment.timeRange.duration)
        }
        
        // Export final
        currentTask = "Export du fichier final..."
        progress = 0.9
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NeuralAutoCutError.exportFailed("Impossible de créer la session d'export")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        if let error = exportSession.error {
            throw NeuralAutoCutError.exportFailed(error.localizedDescription)
        }
        
        currentTask = "Export terminé avec succès!"
        progress = 1.0
    }
}

// MARK: - Configuration Simplifiée (Interface Utilisateur)

/// Configuration simplifiée pour l'interface utilisateur
struct SimplifiedDerushConfig {
    var silenceThreshold: Float = -45.0        // dB
    var minSilenceDuration: TimeInterval = 0.5 // secondes
    var paddingBefore: TimeInterval = 0.15      // secondes
    var paddingAfter: TimeInterval = 0.2        // secondes
    var enableBeatSync: Bool = true
    var enableSceneDetection: Bool = true
    var enableSmartPadding: Bool = true
    
    /// Preset "Agressif" - Coupe beaucoup
    static let aggressive = SimplifiedDerushConfig(
        silenceThreshold: -40.0,
        minSilenceDuration: 0.3,
        paddingBefore: 0.1,
        paddingAfter: 0.15
    )
    
    /// Preset "Conservateur" - Garde plus de contenu
    static let conservative = SimplifiedDerushConfig(
        silenceThreshold: -50.0,
        minSilenceDuration: 0.8,
        paddingBefore: 0.2,
        paddingAfter: 0.3
    )
    
    /// Preset "Équilibré" (par défaut)
    static let balanced = SimplifiedDerushConfig()
}
