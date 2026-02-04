import Foundation
import AVFoundation
import CoreMedia

@available(macOS 14.0, *)
class SmartCutEngine: ObservableObject {
    
    // MARK: - Configuration
    private let audioAnalysisEngine = AudioAnalysisEngine()
    
    // MARK: - Cut Parameters
    private let minSegmentDuration: TimeInterval = 0.5  // Durée minimale d'un segment
    private let maxSegmentDuration: TimeInterval = 8.0  // Durée maximale d'un segment
    private let beatSyncTolerance: TimeInterval = 0.1   // Tolérance pour la synchronisation aux beats
    
    // MARK: - Energy-based Cut Rules
    private let energyTransitionThreshold: Float = 0.3  // Seuil pour détecter les transitions énergétiques
    private let silenceThreshold: Float = 0.05         // Seuil de silence
    private let voiceActivityThreshold: Float = 0.15   // Seuil d'activité vocale
    
    @Published var isProcessing: Bool = false
    @Published var progress: Float = 0.0
    
    // MARK: - Main Auto-Cut Method
    func generateSmartCuts(
        for videoSegments: [VideoSegment],
        with audioAnalysis: DetailedAudioAnalysis,
        targetDuration: TimeInterval? = nil,
        platform: SocialPlatform = .instagram
    ) async throws -> [VideoSegment] {
        
        isProcessing = true
        progress = 0.0
        defer { 
            isProcessing = false 
            progress = 1.0
        }
        
        // 1. Analyse des segments vidéo existants
        let analyzedSegments = await analyzeVideoSegments(videoSegments)
        progress = 0.2
        
        // 2. Détection des zones d'intérêt audio
        let audioInterestPoints = detectAudioInterestPoints(audioAnalysis)
        progress = 0.4
        
        // 3. Génération des points de coupe intelligents
        let cutPoints = generateIntelligentCutPoints(
            audioAnalysis: audioAnalysis,
            interestPoints: audioInterestPoints,
            targetDuration: targetDuration ?? platform.idealDuration
        )
        progress = 0.6
        
        // 4. Application des coupes aux segments vidéo
        let cutSegments = try await applyCutsToSegments(
            segments: analyzedSegments,
            cutPoints: cutPoints,
            audioAnalysis: audioAnalysis
        )
        progress = 0.8
        
        // 5. Optimisation finale et tri par qualité
        let optimizedSegments = optimizeSegmentSelection(
            segments: cutSegments,
            targetDuration: targetDuration ?? platform.idealDuration,
            platform: platform
        )
        progress = 1.0
        
        return optimizedSegments
    }
    
    // MARK: - Video Segment Analysis
    private func analyzeVideoSegments(_ segments: [VideoSegment]) async -> [AnalyzedVideoSegment] {
        return await withTaskGroup(of: AnalyzedVideoSegment?.self) { group in
            var analyzedSegments: [AnalyzedVideoSegment] = []
            
            for segment in segments {
                group.addTask {
                    return await self.analyzeIndividualSegment(segment)
                }
            }
            
            for await result in group {
                if let analyzed = result {
                    analyzedSegments.append(analyzed)
                }
            }
            
            return analyzedSegments.sorted { $0.overallScore > $1.overallScore }
        }
    }
    
    private func analyzeIndividualSegment(_ segment: VideoSegment) async -> AnalyzedVideoSegment? {
        // Simulation d'analyse vidéo avancée
        // Dans une vraie implémentation, on utiliserait Vision Framework
        
        let motionScore = Float.random(in: 0.3...0.9)
        let compositionScore = calculateCompositionScore(segment)
        let stabilityScore = Float.random(in: 0.5...1.0)
        let faceDetectionScore = segment.tags.contains("visage") ? Float.random(in: 0.7...1.0) : Float.random(in: 0.0...0.3)
        
        let overallScore = (
            segment.qualityScore * 0.3 +
            motionScore * 0.2 +
            compositionScore * 0.2 +
            stabilityScore * 0.15 +
            faceDetectionScore * 0.15
        )
        
        return AnalyzedVideoSegment(
            originalSegment: segment,
            motionScore: motionScore,
            compositionScore: compositionScore,
            stabilityScore: stabilityScore,
            faceDetectionScore: faceDetectionScore,
            overallScore: overallScore,
            hasVoiceActivity: detectVoiceActivity(in: segment),
            emotionalTone: classifyEmotionalTone(segment)
        )
    }
    
    // MARK: - Audio Interest Point Detection
    private func detectAudioInterestPoints(_ audioAnalysis: DetailedAudioAnalysis) -> [AudioInterestPoint] {
        var interestPoints: [AudioInterestPoint] = []
        
        // 1. Points de beat forts (downbeats)
        for beat in audioAnalysis.beatGrid where beat.isDownbeat && beat.confidence > 0.7 {
            interestPoints.append(AudioInterestPoint(
                timestamp: beat.timestamp,
                type: .strongBeat,
                confidence: beat.confidence,
                priority: .high
            ))
        }
        
        // 2. Transitions énergétiques
        for i in 1..<audioAnalysis.energyProfile.count {
            let current = audioAnalysis.energyProfile[i]
            let previous = audioAnalysis.energyProfile[i-1]
            
            let energyDifference = abs(current.rmsAmplitude - previous.rmsAmplitude)
            
            if energyDifference > energyTransitionThreshold {
                let transitionType: AudioInterestPoint.InterestType = 
                    current.rmsAmplitude > previous.rmsAmplitude ? .energyIncrease : .energyDecrease
                
                interestPoints.append(AudioInterestPoint(
                    timestamp: current.startTime,
                    type: transitionType,
                    confidence: min(energyDifference / 0.5, 1.0),
                    priority: energyDifference > 0.5 ? .high : .medium
                ))
            }
        }
        
        // 3. Zones de silence (bonnes pour les coupes)
        for segment in audioAnalysis.energyProfile where segment.rmsAmplitude < silenceThreshold {
            interestPoints.append(AudioInterestPoint(
                timestamp: segment.startTime,
                type: .silence,
                confidence: 1.0 - segment.rmsAmplitude / silenceThreshold,
                priority: .medium
            ))
        }
        
        // 4. Changements de niveau énergétique
        let energyLevels = audioAnalysis.energyProfile.map { $0.level }
        for i in 1..<energyLevels.count where energyLevels[i] != energyLevels[i-1] {
            interestPoints.append(AudioInterestPoint(
                timestamp: audioAnalysis.energyProfile[i].startTime,
                type: .levelChange,
                confidence: 0.8,
                priority: .medium
            ))
        }
        
        return interestPoints.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Intelligent Cut Point Generation
    private func generateIntelligentCutPoints(
        audioAnalysis: DetailedAudioAnalysis,
        interestPoints: [AudioInterestPoint],
        targetDuration: TimeInterval
    ) -> [CutPoint] {
        
        var cutPoints: [CutPoint] = []
        let beatInterval = 60.0 / Double(audioAnalysis.bpm)
        
        // Calcul du nombre de segments nécessaires
        let estimatedSegmentCount = Int(ceil(audioAnalysis.duration / (targetDuration / 8.0)))
        let idealSegmentDuration = audioAnalysis.duration / Double(estimatedSegmentCount)
        
        var currentTime: TimeInterval = 0
        var segmentIndex = 0
        
        while currentTime < audioAnalysis.duration && segmentIndex < estimatedSegmentCount {
            let targetEndTime = currentTime + idealSegmentDuration
            
            // Recherche du meilleur point de coupe près du temps cible
            let bestCutPoint = findOptimalCutPoint(
                around: targetEndTime,
                interestPoints: interestPoints,
                beatGrid: audioAnalysis.beatGrid,
                searchWindow: idealSegmentDuration * 0.3
            )
            
            if let cutPoint = bestCutPoint {
                cutPoints.append(CutPoint(
                    timestamp: cutPoint.timestamp,
                    confidence: cutPoint.confidence,
                    reason: cutPoint.type.description,
                    isMusicallyAligned: isAlignedToBeat(cutPoint.timestamp, beatGrid: audioAnalysis.beatGrid),
                    segmentIndex: segmentIndex
                ))
                
                currentTime = cutPoint.timestamp
            } else {
                // Fallback : coupe sur le beat le plus proche
                if let nearestBeat = findNearestBeat(to: targetEndTime, in: audioAnalysis.beatGrid) {
                    cutPoints.append(CutPoint(
                        timestamp: nearestBeat.timestamp,
                        confidence: nearestBeat.confidence,
                        reason: "Beat synchronization",
                        isMusicallyAligned: true,
                        segmentIndex: segmentIndex
                    ))
                    currentTime = nearestBeat.timestamp
                } else {
                    currentTime = targetEndTime
                }
            }
            
            segmentIndex += 1
        }
        
        return cutPoints
    }
    
    // MARK: - Cut Application
    private func applyCutsToSegments(
        segments: [AnalyzedVideoSegment],
        cutPoints: [CutPoint],
        audioAnalysis: DetailedAudioAnalysis
    ) async throws -> [VideoSegment] {
        
        var cutSegments: [VideoSegment] = []
        
        for (index, cutPoint) in cutPoints.enumerated() {
            let startTime = index == 0 ? 0 : cutPoints[index - 1].timestamp
            let endTime = cutPoint.timestamp
            let duration = endTime - startTime
            
            // Vérification de la durée minimale
            guard duration >= minSegmentDuration else { continue }
            
            // Sélection du meilleur segment vidéo pour cette période
            if let bestSegment = selectBestSegmentForTimeRange(
                startTime: startTime,
                endTime: endTime,
                from: segments,
                audioAnalysis: audioAnalysis
            ) {
                
                // Création du nouveau segment coupé
                let newTimeRange = CMTimeRangeMake(
                    start: CMTime(seconds: startTime, preferredTimescale: 600),
                    duration: CMTime(seconds: min(duration, maxSegmentDuration), preferredTimescale: 600)
                )
                
                let cutSegment = VideoSegment(
                    id: UUID(),
                    sourceURL: bestSegment.originalSegment.sourceURL,
                    timeRange: newTimeRange,
                    qualityScore: bestSegment.overallScore,
                    tags: bestSegment.originalSegment.tags + generateCutTags(cutPoint: cutPoint),
                    saliencyCenter: bestSegment.originalSegment.saliencyCenter
                )
                
                cutSegments.append(cutSegment)
            }
        }
        
        return cutSegments
    }
    
    // MARK: - Optimization
    private func optimizeSegmentSelection(
        segments: [VideoSegment],
        targetDuration: TimeInterval,
        platform: SocialPlatform
    ) -> [VideoSegment] {
        
        // Tri par score de qualité
        let sortedSegments = segments.sorted { $0.qualityScore > $1.qualityScore }
        
        // Sélection optimale pour la durée cible
        var selectedSegments: [VideoSegment] = []
        var totalDuration: TimeInterval = 0
        
        for segment in sortedSegments {
            let segmentDuration = segment.timeRange.duration.seconds
            
            if totalDuration + segmentDuration <= targetDuration * 1.1 { // 10% de tolérance
                selectedSegments.append(segment)
                totalDuration += segmentDuration
                
                if totalDuration >= targetDuration * 0.9 { // 90% de la durée cible atteinte
                    break
                }
            }
        }
        
        // Si pas assez de contenu, on prend les meilleurs segments disponibles
        if selectedSegments.isEmpty && !segments.isEmpty {
            selectedSegments = Array(sortedSegments.prefix(min(8, sortedSegments.count)))
        }
        
        return selectedSegments
    }
    
    // MARK: - Helper Methods
    private func calculateCompositionScore(_ segment: VideoSegment) -> Float {
        // Score basé sur la position de saillance (règle des tiers)
        let center = segment.saliencyCenter
        let thirdX = abs(center.x - 0.33) < 0.1 || abs(center.x - 0.67) < 0.1
        let thirdY = abs(center.y - 0.33) < 0.1 || abs(center.y - 0.67) < 0.1
        
        if thirdX && thirdY {
            return 0.9
        } else if thirdX || thirdY {
            return 0.7
        } else {
            return 0.5
        }
    }
    
    private func detectVoiceActivity(in segment: VideoSegment) -> Bool {
        // Simulation de détection d'activité vocale
        // Dans une vraie implémentation, on utiliserait Speech Framework
        return segment.tags.contains("voix") || Float.random(in: 0...1) > 0.7
    }
    
    private func classifyEmotionalTone(_ segment: VideoSegment) -> EmotionalTone {
        if segment.tags.contains("sourire") || segment.tags.contains("joie") {
            return .positive
        } else if segment.tags.contains("action") || segment.tags.contains("mouvement") {
            return .energetic
        } else {
            return .neutral
        }
    }
    
    private func findOptimalCutPoint(
        around targetTime: TimeInterval,
        interestPoints: [AudioInterestPoint],
        beatGrid: [BeatMarker],
        searchWindow: TimeInterval
    ) -> AudioInterestPoint? {
        
        let windowStart = targetTime - searchWindow / 2
        let windowEnd = targetTime + searchWindow / 2
        
        let candidatePoints = interestPoints.filter { point in
            point.timestamp >= windowStart && point.timestamp <= windowEnd
        }
        
        // Scoring des points candidats
        return candidatePoints.max { point1, point2 in
            let score1 = calculateCutPointScore(point1, targetTime: targetTime, beatGrid: beatGrid)
            let score2 = calculateCutPointScore(point2, targetTime: targetTime, beatGrid: beatGrid)
            return score1 < score2
        }
    }
    
    private func calculateCutPointScore(
        _ point: AudioInterestPoint,
        targetTime: TimeInterval,
        beatGrid: [BeatMarker]
    ) -> Float {
        
        var score = point.confidence
        
        // Bonus pour la proximité au temps cible
        let timeDistance = abs(point.timestamp - targetTime)
        score *= Float(1.0 - min(timeDistance / 2.0, 0.5))
        
        // Bonus pour l'alignement musical
        if isAlignedToBeat(point.timestamp, beatGrid: beatGrid) {
            score *= 1.3
        }
        
        // Bonus selon le type de point d'intérêt
        switch point.type {
        case .strongBeat:
            score *= 1.5
        case .silence:
            score *= 1.4
        case .energyDecrease:
            score *= 1.2
        case .levelChange:
            score *= 1.1
        case .energyIncrease:
            score *= 0.9
        }
        
        // Bonus selon la priorité
        switch point.priority {
        case .high:
            score *= 1.2
        case .medium:
            score *= 1.0
        case .low:
            score *= 0.8
        }
        
        return score
    }
    
    private func isAlignedToBeat(_ timestamp: TimeInterval, beatGrid: [BeatMarker]) -> Bool {
        return beatGrid.contains { abs($0.timestamp - timestamp) < beatSyncTolerance }
    }
    
    private func findNearestBeat(to timestamp: TimeInterval, in beatGrid: [BeatMarker]) -> BeatMarker? {
        return beatGrid.min { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }
    }
    
    private func selectBestSegmentForTimeRange(
        startTime: TimeInterval,
        endTime: TimeInterval,
        from segments: [AnalyzedVideoSegment],
        audioAnalysis: DetailedAudioAnalysis
    ) -> AnalyzedVideoSegment? {
        
        // Analyse de l'énergie audio dans cette période
        let periodEnergy = audioAnalysis.energyProfile.filter { segment in
            segment.startTime >= startTime && segment.startTime <= endTime
        }
        
        let averageEnergy = periodEnergy.isEmpty ? 0.5 : 
            periodEnergy.map { $0.rmsAmplitude }.reduce(0, +) / Float(periodEnergy.count)
        
        // Sélection du segment vidéo le mieux adapté à l'énergie audio
        return segments.max { segment1, segment2 in
            let score1 = calculateSegmentMatchScore(segment1, audioEnergy: averageEnergy)
            let score2 = calculateSegmentMatchScore(segment2, audioEnergy: averageEnergy)
            return score1 < score2
        }
    }
    
    private func calculateSegmentMatchScore(_ segment: AnalyzedVideoSegment, audioEnergy: Float) -> Float {
        var score = segment.overallScore
        
        // Bonus pour l'adéquation énergie audio/vidéo
        if audioEnergy > 0.7 && segment.motionScore > 0.7 {
            score *= 1.3 // Énergie élevée = mouvement élevé
        } else if audioEnergy < 0.3 && segment.stabilityScore > 0.8 {
            score *= 1.2 // Énergie faible = stabilité élevée
        }
        
        // Bonus pour les visages dans les moments calmes
        if audioEnergy < 0.5 && segment.faceDetectionScore > 0.7 {
            score *= 1.2
        }
        
        return score
    }
    
    private func generateCutTags(cutPoint: CutPoint) -> [String] {
        var tags: [String] = ["auto_cut"]
        
        if cutPoint.isMusicallyAligned {
            tags.append("beat_sync")
        }
        
        tags.append("confidence_\(Int(cutPoint.confidence * 100))")
        
        return tags
    }
}

// MARK: - Supporting Types
struct AnalyzedVideoSegment {
    let originalSegment: VideoSegment
    let motionScore: Float
    let compositionScore: Float
    let stabilityScore: Float
    let faceDetectionScore: Float
    let overallScore: Float
    let hasVoiceActivity: Bool
    let emotionalTone: EmotionalTone
}

struct AudioInterestPoint {
    let timestamp: TimeInterval
    let type: InterestType
    let confidence: Float
    let priority: Priority
    
    enum InterestType {
        case strongBeat
        case silence
        case energyIncrease
        case energyDecrease
        case levelChange
        
        var description: String {
            switch self {
            case .strongBeat: return "Beat fort"
            case .silence: return "Zone silencieuse"
            case .energyIncrease: return "Montée énergétique"
            case .energyDecrease: return "Baisse énergétique"
            case .levelChange: return "Changement de niveau"
            }
        }
    }
    
    enum Priority {
        case high, medium, low
    }
}

struct CutPoint {
    let timestamp: TimeInterval
    let confidence: Float
    let reason: String
    let isMusicallyAligned: Bool
    let segmentIndex: Int
}

enum EmotionalTone {
    case positive, negative, neutral, energetic
}