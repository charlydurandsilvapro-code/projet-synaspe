import Foundation
import AVFoundation
import CoreMedia

// MARK: - Imports pour les composants Neural Auto-Cut

/// Moteur de décision intelligent pour l'évaluation des segments
actor DecisionEngine {
    
    // MARK: - Properties
    private let logger = NeuralLogger.decisionEngine
    private let configuration: ProcessingConfiguration
    
    // MARK: - Decision State
    private var segmentHistory: [AnalyzedSegment] = []
    private var decisionStatistics: DecisionStatistics
    
    // MARK: - Initialization
    
    init(configuration: ProcessingConfiguration) {
        self.configuration = configuration
        self.decisionStatistics = DecisionStatistics()
        
        logger.info("DecisionEngine initialisé", metadata: [
            "quality_threshold": configuration.qualityThreshold,
            "speech_sensitivity": configuration.speechSensitivity.rawValue,
            "rhythm_mode": configuration.rhythmMode.rawValue
        ])
    }
    
    // MARK: - Public Interface
    
    /// Évalue un segment analysé et prend une décision de conservation/suppression
    func evaluateSegment(_ segment: AnalyzedSegment) async throws -> SegmentDecision {
        logger.debug("Évaluation segment", metadata: [
            "timestamp": segment.segment.startTime.seconds,
            "duration": segment.segment.duration,
            "content_type": segment.contentAnalysis.contentType.rawValue,
            "quality_score": segment.segment.qualityScore
        ])
        
        // Calcul du score de qualité global
        let qualityScore = await calculateQualityScore(segment)
        
        // Application de la logique de décision hiérarchique
        let decision = await applyDecisionLogic(segment, qualityScore: qualityScore)
        
        // Mise à jour des statistiques
        updateStatistics(decision)
        
        // Ajout à l'historique
        segmentHistory.append(segment)
        if segmentHistory.count > 100 {
            segmentHistory.removeFirst(segmentHistory.count - 100)
        }
        
        logger.debug("Décision prise", metadata: [
            "should_keep": decision.shouldKeep,
            "quality_score": decision.qualityScore,
            "reasoning": decision.reasoning.rawValue
        ])
        
        return decision
    }
    
    /// Évalue plusieurs segments en lot
    func evaluateSegments(_ segments: [AnalyzedSegment]) async throws -> [SegmentDecision] {
        var decisions: [SegmentDecision] = []
        
        for segment in segments {
            let decision = try await evaluateSegment(segment)
            decisions.append(decision)
        }
        
        // Post-traitement pour optimiser les décisions globales
        let optimizedDecisions = await optimizeDecisions(decisions, segments: segments)
        
        return optimizedDecisions
    }
    
    /// Obtient les statistiques de décision actuelles
    var currentStatistics: DecisionStatistics {
        get async {
            return decisionStatistics
        }
    }
    
    // MARK: - Private Implementation
    
    private func calculateQualityScore(_ segment: AnalyzedSegment) async -> Float {
        var score: Float = 0.5 // Score de base
        
        // Facteur de niveau audio (30% du score)
        let audioLevelFactor = calculateAudioLevelFactor(segment.segment.rmsLevel)
        score += audioLevelFactor * 0.3
        
        // Facteur de classification (40% du score)
        let classificationFactor = calculateClassificationFactor(segment.contentAnalysis)
        score += classificationFactor * 0.4
        
        // Facteur de silence (20% du score)
        let silenceFactor = calculateSilenceFactor(segment.segment.silenceAnalysis)
        score += silenceFactor * 0.2
        
        // Facteur rythmique (10% du score, si activé)
        if configuration.rhythmMode != .disabled {
            let rhythmFactor = calculateRhythmFactor(segment.rhythmAnalysis)
            score += rhythmFactor * 0.1
        }
        
        // Facteur vidéo (bonus si disponible)
        if let videoQuality = segment.videoQuality {
            let videoFactor = videoQuality.overallQuality
            score = score * 0.9 + videoFactor * 0.1 // 10% de bonus vidéo
        }
        
        return max(0.0, min(1.0, score))
    }
    
    private func calculateAudioLevelFactor(_ rmsLevel: Float) -> Float {
        let dbLevel = 20 * log10(max(rmsLevel, 1e-10))
        
        // Plage optimale : -40dB à -12dB
        switch dbLevel {
        case -40...(-12):
            return 1.0 // Niveau optimal
        case -60...(-40):
            return 0.5 + (dbLevel + 60) / 40 // Montée progressive
        case (-12)...(-6):
            return 1.0 - (dbLevel + 12) / 6 * 0.3 // Légère pénalité
        case (-6)...:
            return 0.2 // Fort écrêtage probable
        default:
            return 0.0 // Trop faible
        }
    }
    
    private func calculateClassificationFactor(_ contentAnalysis: ContentAnalysis) -> Float {
        // Logique hiérarchique : Parole > Musique > Bruit
        switch contentAnalysis.contentType {
        case .speech:
            return contentAnalysis.confidence * 1.0 // Priorité maximale
        case .music:
            return contentAnalysis.confidence * 0.7 // Priorité modérée
        case .noise:
            return (1.0 - contentAnalysis.confidence) * 0.3 // Inversé pour le bruit
        }
    }
    
    private func calculateSilenceFactor(_ silenceAnalysis: SilenceAnalysis) -> Float {
        if silenceAnalysis.isSilence {
            // Pénalité pour les segments silencieux
            return -0.5 * silenceAnalysis.silenceConfidence
        } else {
            // Bonus pour les segments non-silencieux
            return 0.2
        }
    }
    
    private func calculateRhythmFactor(_ rhythmAnalysis: RhythmAnalysis) -> Float {
        if rhythmAnalysis.isRhythmic {
            return rhythmAnalysis.rhythmStrength * 0.3 // Bonus rythmique
        } else {
            return 0.0 // Neutre si pas rythmique
        }
    }
    
    private func applyDecisionLogic(_ segment: AnalyzedSegment, qualityScore: Float) async -> SegmentDecision {
        // Règles de décision hiérarchiques
        
        // 1. Préservation absolue de la parole (sauf si qualité très faible)
        if segment.contentAnalysis.contentType == .speech {
            let shouldKeep = qualityScore > 0.2 || segment.contentAnalysis.confidence > 0.7
            return SegmentDecision(
                shouldKeep: shouldKeep,
                qualityScore: qualityScore,
                reasoning: shouldKeep ? .speechPreservation : .poorQualitySpeech,
                suggestedCutPoints: shouldKeep ? nil : (segment.segment.startTime, segment.segment.endTime)
            )
        }
        
        // 2. Suppression automatique du bruit de faible qualité
        if segment.contentAnalysis.contentType == .noise && qualityScore < 0.3 {
            return SegmentDecision(
                shouldKeep: false,
                qualityScore: qualityScore,
                reasoning: .noiseRemoval,
                suggestedCutPoints: (segment.segment.startTime, segment.segment.endTime)
            )
        }
        
        // 3. Préservation de la musique de qualité
        if segment.contentAnalysis.contentType == .music && qualityScore > 0.6 {
            return SegmentDecision(
                shouldKeep: true,
                qualityScore: qualityScore,
                reasoning: .musicPreservation,
                suggestedCutPoints: nil
            )
        }
        
        // 4. Suppression des silences longs
        if segment.segment.silenceAnalysis.isSilence && 
           segment.segment.silenceAnalysis.duration > configuration.minimumSilenceDuration {
            return SegmentDecision(
                shouldKeep: false,
                qualityScore: qualityScore,
                reasoning: .silenceRemoval,
                suggestedCutPoints: (segment.segment.startTime, segment.segment.endTime)
            )
        }
        
        // 5. Décision basée sur le seuil de qualité global
        let shouldKeep = qualityScore >= configuration.qualityThreshold
        return SegmentDecision(
            shouldKeep: shouldKeep,
            qualityScore: qualityScore,
            reasoning: shouldKeep ? .qualityThreshold : .belowQualityThreshold,
            suggestedCutPoints: shouldKeep ? nil : (segment.segment.startTime, segment.segment.endTime)
        )
    }
    
    private func optimizeDecisions(_ decisions: [SegmentDecision], segments: [AnalyzedSegment]) async -> [SegmentDecision] {
        guard decisions.count == segments.count else { return decisions }
        
        var optimizedDecisions = decisions
        
        // Optimisation 1 : Éviter les coupes trop courtes
        for i in 1..<(decisions.count - 1) {
            if !decisions[i].shouldKeep && 
               decisions[i-1].shouldKeep && 
               decisions[i+1].shouldKeep &&
               segments[i].segment.duration < 1.0 { // Segment court entre deux segments gardés
                
                optimizedDecisions[i] = SegmentDecision(
                    shouldKeep: true,
                    qualityScore: decisions[i].qualityScore,
                    reasoning: .shortSegmentPreservation,
                    suggestedCutPoints: nil
                )
            }
        }
        
        // Optimisation 2 : Fusion des segments adjacents similaires
        // (Implémentation simplifiée pour cette version)
        
        return optimizedDecisions
    }
    
    private func updateStatistics(_ decision: SegmentDecision) {
        decisionStatistics.totalSegments += 1
        
        if decision.shouldKeep {
            decisionStatistics.segmentsKept += 1
        } else {
            decisionStatistics.segmentsRemoved += 1
        }
        
        decisionStatistics.averageQualityScore = 
            (decisionStatistics.averageQualityScore * Float(decisionStatistics.totalSegments - 1) + decision.qualityScore) / 
            Float(decisionStatistics.totalSegments)
        
        // Mise à jour des statistiques par raison
        decisionStatistics.reasonCounts[decision.reasoning, default: 0] += 1
    }
}

// MARK: - Supporting Types

/// Décision pour un segment
public struct SegmentDecision {
    public let shouldKeep: Bool
    public let qualityScore: Float
    public let reasoning: DecisionReason
    public let suggestedCutPoints: (CMTime, CMTime)?
    
    public init(shouldKeep: Bool, qualityScore: Float, reasoning: DecisionReason, suggestedCutPoints: (CMTime, CMTime)?) {
        self.shouldKeep = shouldKeep
        self.qualityScore = qualityScore
        self.reasoning = reasoning
        self.suggestedCutPoints = suggestedCutPoints
    }
}

/// Raisons de décision
public enum DecisionReason: String, CaseIterable {
    case speechPreservation = "Préservation parole"
    case musicPreservation = "Préservation musique"
    case noiseRemoval = "Suppression bruit"
    case silenceRemoval = "Suppression silence"
    case qualityThreshold = "Seuil qualité atteint"
    case belowQualityThreshold = "Sous seuil qualité"
    case poorQualitySpeech = "Parole qualité insuffisante"
    case shortSegmentPreservation = "Préservation segment court"
    case rhythmAlignment = "Alignement rythmique"
}

/// Statistiques de décision
public struct DecisionStatistics {
    public var totalSegments: Int = 0
    public var segmentsKept: Int = 0
    public var segmentsRemoved: Int = 0
    public var averageQualityScore: Float = 0.0
    public var reasonCounts: [DecisionReason: Int] = [:]
    
    public var keepPercentage: Float {
        return totalSegments > 0 ? Float(segmentsKept) / Float(totalSegments) * 100 : 0
    }
    
    public var removePercentage: Float {
        return totalSegments > 0 ? Float(segmentsRemoved) / Float(totalSegments) * 100 : 0
    }
    
    public var mostCommonReason: DecisionReason? {
        return reasonCounts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Audio Analysis Pipeline

/// Pipeline d'analyse audio intégré coordonnant tous les composants d'analyse
@available(macOS 14.0, *)
actor AudioAnalysisPipeline {
    
    // MARK: - Properties
    private let logger = NeuralLogger.forCategory("AudioAnalysisPipeline")
    
    // MARK: - Analysis Components
    private var pcmExtractor: PCMStreamExtractor?
    private var rmsAnalyzer: SpectralRMSAnalyzer?
    private var soundClassifier: SoundAnalysisClassifier?
    private var beatDetector: BeatDetectionEngine?
    private var decisionEngine: DecisionEngine?
    
    // MARK: - Pipeline State
    private var isAnalyzing: Bool = false
    private var currentConfiguration: ProcessingConfiguration?
    private var analysisTask: Task<Void, Never>?
    
    // MARK: - Performance Tracking
    private var pipelineStartTime: Date?
    private var segmentCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init() {
        logger.info("AudioAnalysisPipeline initialisé")
    }
    
    deinit {
        // Le cleanup sera fait automatiquement par l'actor lors de la déallocation
    }
    
    // MARK: - Public Interface
    
    /// Analyse complète d'un asset audio avec tous les composants
    func analyzeAudio(_ asset: AVAsset) async throws -> [AnalyzedSegment] {
        guard !isAnalyzing else {
            throw NeuralAutoCutError.processingInProgress
        }
        
        // Configuration par défaut si non fournie
        let config = currentConfiguration ?? ProcessingConfiguration()
        return try await analyzeAudio(asset, configuration: config)
    }
    
    /// Analyse audio avec configuration spécifique
    func analyzeAudio(_ asset: AVAsset, configuration: ProcessingConfiguration) async throws -> [AnalyzedSegment] {
        guard !isAnalyzing else {
            throw NeuralAutoCutError.processingInProgress
        }
        
        isAnalyzing = true
        currentConfiguration = configuration
        pipelineStartTime = Date()
        segmentCount = 0
        
        defer {
            isAnalyzing = false
            if let startTime = pipelineStartTime {
                totalProcessingTime += Date().timeIntervalSince(startTime)
            }
        }
        
        logger.info("Démarrage analyse audio pipeline", metadata: [
            "asset": asset.description,
            "configuration": [
                "silence_threshold": configuration.silenceThreshold,
                "speech_sensitivity": configuration.speechSensitivity.rawValue,
                "rhythm_mode": configuration.rhythmMode.rawValue,
                "enable_video_analysis": configuration.enableVideoAnalysis
            ]
        ])
        
        do {
            // Initialisation des composants
            try await setupAnalysisComponents(configuration: configuration)
            
            // Exécution du pipeline d'analyse
            let analyzedSegments = try await performPipelineAnalysis(asset: asset)
            
            logger.info("Analyse audio pipeline terminée", metadata: [
                "segments_analyzed": analyzedSegments.count,
                "total_duration": analyzedSegments.reduce(0) { $0 + $1.segment.duration },
                "processing_time": Date().timeIntervalSince(pipelineStartTime!)
            ])
            
            return analyzedSegments
            
        } catch {
            logger.error("Erreur analyse audio pipeline", metadata: [
                "error": error.localizedDescription
            ])
            throw error
        }
    }
    
    /// Annule l'analyse en cours
    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        
        Task {
            await pcmExtractor?.cancelExtraction()
        }
        
        isAnalyzing = false
        logger.info("Analyse audio pipeline annulée")
    }
    
    // MARK: - Private Implementation
    
    private func setupAnalysisComponents(configuration: ProcessingConfiguration) async throws {
        logger.debug("Configuration des composants d'analyse")
        
        // Validation de la configuration
        try configuration.validate()
        
        // Initialisation des composants
        pcmExtractor = PCMStreamExtractor(configuration: configuration)
        rmsAnalyzer = SpectralRMSAnalyzer(configuration: configuration)
        soundClassifier = SoundAnalysisClassifier(configuration: configuration)
        
        // Composants optionnels selon la configuration
        if configuration.rhythmMode != .disabled {
            beatDetector = BeatDetectionEngine(configuration: configuration)
        }
        
        decisionEngine = DecisionEngine(configuration: configuration)
        
        logger.debug("Composants d'analyse configurés", metadata: [
            "pcm_extractor": pcmExtractor != nil,
            "rms_analyzer": rmsAnalyzer != nil,
            "sound_classifier": soundClassifier != nil,
            "beat_detector": beatDetector != nil,
            "decision_engine": decisionEngine != nil
        ])
    }
    
    private func performPipelineAnalysis(asset: AVAsset) async throws -> [AnalyzedSegment] {
        guard let extractor = pcmExtractor,
              let rmsAnalyzer = rmsAnalyzer,
              let soundClassifier = soundClassifier,
              let decisionEngine = decisionEngine else {
            throw NeuralAutoCutError.processingFailed("Composants d'analyse non initialisés")
        }
        
        var analyzedSegments: [AnalyzedSegment] = []
        
        // Extraction du flux audio
        let audioStream = await extractor.extractAudioStream(from: asset)
        
        // Traitement parallèle des buffers audio
        try await withThrowingTaskGroup(of: AnalyzedSegment?.self) { group in
            var bufferIndex = 0
            
            for try await audioBuffer in audioStream {
                // Vérification d'annulation
                if Task.isCancelled {
                    throw NeuralAutoCutError.processingCancelled
                }
                
                let currentBufferIndex = bufferIndex
                bufferIndex += 1
                
                // Traitement parallèle de chaque buffer
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    return await self.processAudioBuffer(
                        audioBuffer,
                        bufferIndex: currentBufferIndex,
                        rmsAnalyzer: rmsAnalyzer,
                        soundClassifier: soundClassifier,
                        beatDetector: self.beatDetector,
                        decisionEngine: decisionEngine
                    )
                }
            }
            
            // Collecte des résultats restants
            for try await segment in group {
                if let validSegment = segment {
                    analyzedSegments.append(validSegment)
                }
            }
        }
        
        // Tri des segments par timestamp
        analyzedSegments.sort { $0.segment.startTime.seconds < $1.segment.startTime.seconds }
        
        // Post-traitement et optimisation
        let optimizedSegments = try await postProcessSegments(analyzedSegments)
        
        return optimizedSegments
    }
    
    private func processAudioBuffer(
        _ buffer: AudioBuffer,
        bufferIndex: Int,
        rmsAnalyzer: SpectralRMSAnalyzer,
        soundClassifier: SoundAnalysisClassifier,
        beatDetector: BeatDetectionEngine?,
        decisionEngine: DecisionEngine
    ) async -> AnalyzedSegment? {
        
        do {
            logger.debug("Traitement buffer audio", metadata: [
                "buffer_index": bufferIndex,
                "frame_count": buffer.frameCount,
                "timestamp": buffer.timestamp.seconds
            ])
            
            // Analyse RMS et détection de silence
            let rmsResult = try await rmsAnalyzer.analyzeRMS(buffer)
            
            // Classification audio
            let audioClassification = try await soundClassifier.classifyAudio(buffer)
            
            // Détection de rythme (optionnelle)
            var beatAlignment: BeatAlignment?
            if let detector = beatDetector {
                let beatPoints = try await detector.detectBeats(buffer)
                if let nearestBeat = beatPoints.first {
                    let offset = nearestBeat.timestamp.seconds - buffer.timestamp.seconds
                    beatAlignment = BeatAlignment(nearestBeat: nearestBeat, alignmentOffset: offset)
                }
            }
            
            // Création du segment audio
            let audioSegment = AudioSegment(
                startTime: buffer.timestamp,
                endTime: CMTimeAdd(buffer.timestamp, CMTime(seconds: buffer.duration, preferredTimescale: 600)),
                rmsLevel: rmsResult.averageRMS,
                classification: audioClassification,
                beatAlignment: beatAlignment,
                qualityScore: calculateQualityScore(rmsResult: rmsResult, classification: audioClassification),
                silenceAnalysis: SilenceAnalysis(
                    isSilence: !rmsResult.silenceSegments.isEmpty,
                    silenceConfidence: rmsResult.silenceSegments.first?.confidence ?? 0.0,
                    averageLevel: 20 * log10(max(rmsResult.averageRMS, 1e-10)),
                    duration: buffer.duration
                )
            )
            
            // Analyse de contenu
            let contentAnalysis = ContentAnalysis(
                contentType: audioClassification.dominantType,
                confidence: audioClassification.confidence,
                speechProbability: audioClassification.speech,
                musicProbability: audioClassification.music,
                noiseProbability: audioClassification.noise
            )
            
            // Analyse rythmique
            let rhythmAnalysis = RhythmAnalysis(
                detectedBeats: beatDetector != nil ? (try? await beatDetector!.detectBeats(buffer)) ?? [] : [],
                estimatedTempo: beatAlignment?.nearestBeat.strength ?? 0.0,
                rhythmStrength: beatAlignment?.isAligned == true ? 1.0 : 0.0
            )
            
            // Création du segment analysé
            let analyzedSegment = AnalyzedSegment(
                segment: audioSegment,
                contentAnalysis: contentAnalysis,
                rhythmAnalysis: rhythmAnalysis,
                videoQuality: nil // Sera ajouté par le VisionAnalysisEngine si activé
            )
            
            segmentCount += 1
            
            return analyzedSegment
            
        } catch {
            logger.error("Erreur traitement buffer audio", metadata: [
                "buffer_index": bufferIndex,
                "error": error.localizedDescription
            ])
            return nil
        }
    }
    
    private func calculateQualityScore(rmsResult: RMSAnalysisResult, classification: AudioClassification) -> Float {
        // Score de qualité basé sur plusieurs facteurs
        var qualityScore: Float = 0.5 // Score de base
        
        // Facteur RMS (niveau audio)
        let dbLevel = 20 * log10(max(rmsResult.averageRMS, 1e-10))
        if dbLevel > -60 && dbLevel < -6 { // Plage optimale
            qualityScore += 0.2
        } else if dbLevel <= -60 { // Trop faible
            qualityScore -= 0.3
        } else if dbLevel >= -6 { // Trop fort (écrêtage possible)
            qualityScore -= 0.2
        }
        
        // Facteur de classification
        switch classification.dominantType {
        case .speech:
            qualityScore += classification.confidence * 0.3
        case .music:
            qualityScore += classification.confidence * 0.2
        case .noise:
            qualityScore -= classification.confidence * 0.2
        }
        
        // Facteur de silence
        if !rmsResult.silenceSegments.isEmpty {
            qualityScore -= 0.4 // Pénalité pour les segments avec silence
        }
        
        return max(0.0, min(1.0, qualityScore))
    }
    
    private func postProcessSegments(_ segments: [AnalyzedSegment]) async throws -> [AnalyzedSegment] {
        logger.debug("Post-traitement des segments", metadata: [
            "segment_count": segments.count
        ])
        
        // Fusion des segments adjacents similaires
        let mergedSegments = try await mergeAdjacentSegments(segments)
        
        // Filtrage des segments de qualité insuffisante
        let filteredSegments = try await filterLowQualitySegments(mergedSegments)
        
        // Lissage temporel des classifications
        let smoothedSegments = try await applyTemporalSmoothing(filteredSegments)
        
        logger.debug("Post-traitement terminé", metadata: [
            "original_count": segments.count,
            "merged_count": mergedSegments.count,
            "filtered_count": filteredSegments.count,
            "final_count": smoothedSegments.count
        ])
        
        return smoothedSegments
    }
    
    private func mergeAdjacentSegments(_ segments: [AnalyzedSegment]) async throws -> [AnalyzedSegment] {
        guard segments.count > 1 else { return segments }
        
        var mergedSegments: [AnalyzedSegment] = []
        var currentSegment = segments[0]
        
        for i in 1..<segments.count {
            let nextSegment = segments[i]
            
            // Vérification si les segments peuvent être fusionnés
            if canMergeSegments(currentSegment, nextSegment) {
                currentSegment = try await mergeSegments(currentSegment, nextSegment)
            } else {
                mergedSegments.append(currentSegment)
                currentSegment = nextSegment
            }
        }
        
        mergedSegments.append(currentSegment)
        return mergedSegments
    }
    
    private func canMergeSegments(_ segment1: AnalyzedSegment, _ segment2: AnalyzedSegment) -> Bool {
        // Critères de fusion
        let timeDifference = segment2.segment.startTime.seconds - segment1.segment.endTime.seconds
        let sameContentType = segment1.contentAnalysis.contentType == segment2.contentAnalysis.contentType
        let similarQuality = abs(segment1.segment.qualityScore - segment2.segment.qualityScore) < 0.2
        
        return timeDifference < 0.5 && sameContentType && similarQuality
    }
    
    private func mergeSegments(_ segment1: AnalyzedSegment, _ segment2: AnalyzedSegment) async throws -> AnalyzedSegment {
        // Fusion des propriétés des segments
        let mergedDuration = segment1.segment.duration + segment2.segment.duration
        let weightedQuality = (segment1.segment.qualityScore * Float(segment1.segment.duration) + 
                              segment2.segment.qualityScore * Float(segment2.segment.duration)) / Float(mergedDuration)
        
        let mergedAudioSegment = AudioSegment(
            startTime: segment1.segment.startTime,
            endTime: segment2.segment.endTime,
            rmsLevel: (segment1.segment.rmsLevel + segment2.segment.rmsLevel) / 2.0,
            classification: segment1.segment.classification, // Garde la première classification
            beatAlignment: segment1.segment.beatAlignment ?? segment2.segment.beatAlignment,
            qualityScore: weightedQuality,
            silenceAnalysis: segment1.segment.silenceAnalysis
        )
        
        return AnalyzedSegment(
            segment: mergedAudioSegment,
            contentAnalysis: segment1.contentAnalysis,
            rhythmAnalysis: segment1.rhythmAnalysis,
            videoQuality: segment1.videoQuality
        )
    }
    
    private func filterLowQualitySegments(_ segments: [AnalyzedSegment]) async throws -> [AnalyzedSegment] {
        guard let config = currentConfiguration else { return segments }
        
        return segments.filter { segment in
            segment.segment.qualityScore >= config.qualityThreshold &&
            segment.segment.duration >= config.minimumSegmentDuration
        }
    }
    
    private func applyTemporalSmoothing(_ segments: [AnalyzedSegment]) async throws -> [AnalyzedSegment] {
        // Lissage temporel des classifications pour réduire les fluctuations
        guard segments.count > 2 else { return segments }
        
        var smoothedSegments = segments
        
        for i in 1..<(segments.count - 1) {
            let prevSegment = segments[i - 1]
            let currentSegment = segments[i]
            let nextSegment = segments[i + 1]
            
            // Lissage de la classification si entourée de segments similaires
            if prevSegment.contentAnalysis.contentType == nextSegment.contentAnalysis.contentType &&
               currentSegment.contentAnalysis.contentType != prevSegment.contentAnalysis.contentType &&
               currentSegment.segment.duration < 2.0 { // Segment court
                
                // Remplace la classification par celle des segments adjacents
                let smoothedContentAnalysis = ContentAnalysis(
                    contentType: prevSegment.contentAnalysis.contentType,
                    confidence: (prevSegment.contentAnalysis.confidence + nextSegment.contentAnalysis.confidence) / 2.0,
                    speechProbability: (prevSegment.contentAnalysis.speechProbability + nextSegment.contentAnalysis.speechProbability) / 2.0,
                    musicProbability: (prevSegment.contentAnalysis.musicProbability + nextSegment.contentAnalysis.musicProbability) / 2.0,
                    noiseProbability: (prevSegment.contentAnalysis.noiseProbability + nextSegment.contentAnalysis.noiseProbability) / 2.0
                )
                
                smoothedSegments[i] = AnalyzedSegment(
                    segment: currentSegment.segment,
                    contentAnalysis: smoothedContentAnalysis,
                    rhythmAnalysis: currentSegment.rhythmAnalysis,
                    videoQuality: currentSegment.videoQuality
                )
            }
        }
        
        return smoothedSegments
    }
    
    private func cleanup() {
        analysisTask?.cancel()
        analysisTask = nil
        
        pcmExtractor = nil
        rmsAnalyzer = nil
        soundClassifier = nil
        beatDetector = nil
        decisionEngine = nil
        
        logger.debug("AudioAnalysisPipeline nettoyé")
    }
}

// MARK: - Extensions

extension AudioAnalysisPipeline {
    
    /// Statistiques de performance du pipeline
    var performanceStatistics: PipelineStatistics {
        get async {
            return PipelineStatistics(
                isAnalyzing: isAnalyzing,
                segmentCount: segmentCount,
                totalProcessingTime: totalProcessingTime,
                averageProcessingTime: segmentCount > 0 ? totalProcessingTime / Double(segmentCount) : 0,
                currentConfiguration: currentConfiguration
            )
        }
    }
}

struct PipelineStatistics {
    let isAnalyzing: Bool
    let segmentCount: Int
    let totalProcessingTime: TimeInterval
    let averageProcessingTime: TimeInterval
    let currentConfiguration: ProcessingConfiguration?
    
    var segmentsPerSecond: Float {
        return totalProcessingTime > 0 ? Float(segmentCount) / Float(totalProcessingTime) : 0
    }
    
    var status: String {
        return isAnalyzing ? "En cours d'analyse" : "Inactif"
    }
    
    var efficiency: String {
        let sps = segmentsPerSecond
        switch sps {
        case 10...: return "Très efficace"
        case 5..<10: return "Efficace"
        case 1..<5: return "Modéré"
        default: return "Lent"
        }
    }
}