import Foundation
import AVFoundation
import CoreMedia

@available(macOS 14.0, *)
class AutoRushEngine: ObservableObject {
    
    // MARK: - Dependencies
    private let audioAnalysisEngine = AudioAnalysisEngine()
    private let smartCutEngine = SmartCutEngine()
    
    // MARK: - Configuration
    private let qualityThreshold: Float = 0.6
    private let minHighlightDuration: TimeInterval = 2.0
    private let maxHighlightDuration: TimeInterval = 10.0
    private let diversityWeight: Float = 0.3
    
    @Published var isProcessing: Bool = false
    @Published var progress: Float = 0.0
    @Published var currentTask: String = ""
    
    // MARK: - Main Auto-Rush Method
    func performAutoRush(
        videoURLs: [URL],
        audioURL: URL,
        targetDuration: TimeInterval,
        platform: SocialPlatform,
        preferences: RushPreferences = RushPreferences()
    ) async throws -> AutoRushResult {
        
        isProcessing = true
        progress = 0.0
        defer { 
            isProcessing = false 
            progress = 1.0
        }
        
        // 1. Analyse audio complète
        currentTask = "Analyse de la bande sonore..."
        let audioAnalysis = try await audioAnalysisEngine.analyzeAudio(from: audioURL)
        progress = 0.15
        
        // 2. Analyse et segmentation des vidéos
        currentTask = "Analyse des vidéos..."
        let videoSegments = try await analyzeAndSegmentVideos(videoURLs)
        progress = 0.35
        
        // 3. Détection des moments forts
        currentTask = "Détection des moments forts..."
        let highlights = await detectHighlights(
            videoSegments: videoSegments,
            audioAnalysis: audioAnalysis,
            preferences: preferences
        )
        progress = 0.55
        
        // 4. Génération des coupes intelligentes
        currentTask = "Génération des coupes intelligentes..."
        let smartCuts = try await smartCutEngine.generateSmartCuts(
            for: highlights.map { $0.toVideoSegment() },
            with: audioAnalysis,
            targetDuration: targetDuration,
            platform: platform
        )
        progress = 0.75
        
        // 5. Optimisation finale et création de la timeline
        currentTask = "Optimisation de la timeline..."
        let optimizedTimeline = optimizeTimeline(
            segments: smartCuts,
            audioAnalysis: audioAnalysis,
            targetDuration: targetDuration,
            platform: platform,
            preferences: preferences
        )
        progress = 0.95
        
        // 6. Génération des métadonnées
        currentTask = "Finalisation..."
        let metadata = generateRushMetadata(
            timeline: optimizedTimeline,
            audioAnalysis: audioAnalysis,
            originalSegments: videoSegments,
            preferences: preferences
        )
        
        return AutoRushResult(
            timeline: optimizedTimeline,
            audioAnalysis: audioAnalysis,
            metadata: metadata,
            confidence: calculateOverallConfidence(optimizedTimeline),
            suggestions: generateImprovementSuggestions(optimizedTimeline, preferences: preferences)
        )
    }
    
    // MARK: - Video Analysis and Segmentation
    private func analyzeAndSegmentVideos(_ urls: [URL]) async throws -> [EnhancedVideoSegment] {
        return try await withThrowingTaskGroup(of: [EnhancedVideoSegment].self) { group in
            var allSegments: [EnhancedVideoSegment] = []
            
            for url in urls {
                group.addTask {
                    return try await self.analyzeIndividualVideo(url)
                }
            }
            
            for try await segments in group {
                allSegments.append(contentsOf: segments)
            }
            
            return allSegments.sorted { $0.overallScore > $1.overallScore }
        }
    }
    
    private func analyzeIndividualVideo(_ url: URL) async throws -> [EnhancedVideoSegment] {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = duration.seconds
        
        // Segmentation en chunks de 3-5 secondes
        let segmentDuration: TimeInterval = 4.0
        let segmentCount = Int(ceil(durationSeconds / segmentDuration))
        
        var segments: [EnhancedVideoSegment] = []
        
        for i in 0..<segmentCount {
            let startTime = Double(i) * segmentDuration
            let actualDuration = min(segmentDuration, durationSeconds - startTime)
            
            if actualDuration >= 1.0 { // Segments minimum 1 seconde
                let segment = await analyzeVideoSegment(
                    url: url,
                    startTime: startTime,
                    duration: actualDuration,
                    segmentIndex: i
                )
                segments.append(segment)
            }
        }
        
        return segments
    }
    
    private func analyzeVideoSegment(
        url: URL,
        startTime: TimeInterval,
        duration: TimeInterval,
        segmentIndex: Int
    ) async -> EnhancedVideoSegment {
        
        // Analyse technique de base
        let technicalAnalysis = await performTechnicalAnalysis(
            url: url,
            startTime: startTime,
            duration: duration
        )
        
        // Analyse du contenu visuel
        let contentAnalysis = await performContentAnalysis(
            url: url,
            startTime: startTime,
            duration: duration
        )
        
        // Analyse du mouvement
        let motionAnalysis = await performMotionAnalysis(
            url: url,
            startTime: startTime,
            duration: duration
        )
        
        // Score global
        let overallScore = calculateOverallScore(
            technical: technicalAnalysis,
            content: contentAnalysis,
            motion: motionAnalysis
        )
        
        let timeRange = CMTimeRangeMake(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        
        return EnhancedVideoSegment(
            id: UUID(),
            sourceURL: url,
            timeRange: timeRange,
            segmentIndex: segmentIndex,
            technicalAnalysis: technicalAnalysis,
            contentAnalysis: contentAnalysis,
            motionAnalysis: motionAnalysis,
            overallScore: overallScore,
            tags: generateSegmentTags(
                technical: technicalAnalysis,
                content: contentAnalysis,
                motion: motionAnalysis
            )
        )
    }
    
    // MARK: - Highlight Detection
    private func detectHighlights(
        videoSegments: [EnhancedVideoSegment],
        audioAnalysis: DetailedAudioAnalysis,
        preferences: RushPreferences
    ) async -> [EnhancedVideoSegment] {
        
        var highlights: [EnhancedVideoSegment] = []
        
        // 1. Filtrage par qualité minimale
        let qualityFiltered = videoSegments.filter { $0.overallScore >= qualityThreshold }
        
        // 2. Détection des pics d'énergie audio
        let energyPeaks = detectEnergyPeaks(audioAnalysis)
        
        // 3. Synchronisation vidéo-audio
        for segment in qualityFiltered {
            let segmentStartTime = segment.timeRange.start.seconds
            let segmentEndTime = segmentStartTime + segment.timeRange.duration.seconds
            
            // Vérification de la correspondance avec les pics d'énergie
            let hasEnergyPeak = energyPeaks.contains { peak in
                peak >= segmentStartTime && peak <= segmentEndTime
            }
            
            // Score de highlight basé sur plusieurs critères
            var highlightScore = segment.overallScore
            
            if hasEnergyPeak {
                highlightScore *= 1.4
            }
            
            // Bonus pour les préférences utilisateur
            highlightScore *= calculatePreferenceBonus(segment, preferences: preferences)
            
            // Bonus pour la diversité (éviter les segments trop similaires)
            highlightScore *= calculateDiversityBonus(segment, existingHighlights: highlights)
            
            if highlightScore >= preferences.highlightThreshold {
                var enhancedSegment = segment
                enhancedSegment.highlightScore = highlightScore
                enhancedSegment.highlightReasons = generateHighlightReasons(
                    segment: segment,
                    hasEnergyPeak: hasEnergyPeak,
                    preferences: preferences
                )
                highlights.append(enhancedSegment)
            }
        }
        
        // 4. Tri et limitation
        highlights.sort { $0.highlightScore > $1.highlightScore }
        
        // Limitation du nombre de highlights pour éviter la surcharge
        let maxHighlights = min(Int(audioAnalysis.duration / 3.0), 20)
        return Array(highlights.prefix(maxHighlights))
    }
    
    // MARK: - Timeline Optimization
    private func optimizeTimeline(
        segments: [VideoSegment],
        audioAnalysis: DetailedAudioAnalysis,
        targetDuration: TimeInterval,
        platform: SocialPlatform,
        preferences: RushPreferences
    ) -> [VideoSegment] {
        
        // 1. Tri par qualité et pertinence
        let sortedSegments = segments.sorted { segment1, segment2 in
            let score1 = calculateTimelineScore(segment1, audioAnalysis: audioAnalysis, preferences: preferences)
            let score2 = calculateTimelineScore(segment2, audioAnalysis: audioAnalysis, preferences: preferences)
            return score1 > score2
        }
        
        // 2. Sélection optimale avec contraintes de durée
        var selectedSegments: [VideoSegment] = []
        var totalDuration: TimeInterval = 0
        var usedSources: Set<URL> = []
        
        for segment in sortedSegments {
            let segmentDuration = segment.timeRange.duration.seconds
            
            // Vérification des contraintes
            if totalDuration + segmentDuration <= targetDuration * 1.1 {
                
                // Éviter trop de segments de la même source (diversité)
                let sourceCount = selectedSegments.filter { $0.sourceURL == segment.sourceURL }.count
                if sourceCount < 3 || usedSources.count < 2 {
                    
                    selectedSegments.append(segment)
                    totalDuration += segmentDuration
                    usedSources.insert(segment.sourceURL)
                    
                    if totalDuration >= targetDuration * 0.95 {
                        break
                    }
                }
            }
        }
        
        // 3. Réorganisation pour un flow optimal
        return reorderForOptimalFlow(selectedSegments, audioAnalysis: audioAnalysis)
    }
    
    // MARK: - Analysis Methods
    private func performTechnicalAnalysis(
        url: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async -> TechnicalAnalysis {
        
        // Simulation d'analyse technique
        // Dans une vraie implémentation, on analyserait :
        // - Netteté (Laplacian variance)
        // - Exposition (histogramme)
        // - Stabilité (optical flow)
        // - Bruit (analyse fréquentielle)
        
        return TechnicalAnalysis(
            sharpness: Float.random(in: 0.4...0.95),
            exposure: Float.random(in: 0.3...0.9),
            stability: Float.random(in: 0.5...1.0),
            noise: Float.random(in: 0.1...0.4),
            colorBalance: Float.random(in: 0.6...0.95),
            contrast: Float.random(in: 0.5...0.9)
        )
    }
    
    private func performContentAnalysis(
        url: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async -> ContentAnalysis {
        
        // Simulation d'analyse de contenu
        // Dans une vraie implémentation, on utiliserait Vision Framework
        
        let hasFaces = Float.random(in: 0...1) > 0.6
        let faceCount = hasFaces ? Int.random(in: 1...3) : 0
        
        return ContentAnalysis(
            faceCount: faceCount,
            faceConfidence: hasFaces ? Float.random(in: 0.7...0.95) : 0,
            emotionScore: hasFaces ? Float.random(in: 0.5...0.9) : Float.random(in: 0.3...0.7),
            compositionScore: Float.random(in: 0.4...0.9),
            objectCount: Int.random(in: 2...8),
            sceneComplexity: Float.random(in: 0.3...0.8),
            aestheticScore: Float.random(in: 0.4...0.85)
        )
    }
    
    private func performMotionAnalysis(
        url: URL,
        startTime: TimeInterval,
        duration: TimeInterval
    ) async -> MotionAnalysis {
        
        // Simulation d'analyse de mouvement
        return MotionAnalysis(
            overallMotion: Float.random(in: 0.2...0.9),
            cameraMotion: Float.random(in: 0.1...0.6),
            subjectMotion: Float.random(in: 0.3...0.8),
            motionSmoothness: Float.random(in: 0.5...0.95),
            directionChanges: Int.random(in: 0...5),
            motionType: MotionType.allCases.randomElement() ?? .stillness
        )
    }
    
    // MARK: - Helper Methods
    private func calculateOverallScore(
        technical: TechnicalAnalysis,
        content: ContentAnalysis,
        motion: MotionAnalysis
    ) -> Float {
        
        let technicalScore = (
            technical.sharpness * 0.25 +
            technical.exposure * 0.2 +
            technical.stability * 0.2 +
            (1.0 - technical.noise) * 0.15 +
            technical.colorBalance * 0.1 +
            technical.contrast * 0.1
        )
        
        let contentScore = (
            (content.faceCount > 0 ? content.faceConfidence : 0.5) * 0.3 +
            content.emotionScore * 0.2 +
            content.compositionScore * 0.25 +
            content.aestheticScore * 0.25
        )
        
        let motionScore = (
            motion.overallMotion * 0.4 +
            (1.0 - motion.cameraMotion) * 0.2 + // Moins de mouvement de caméra = mieux
            motion.subjectMotion * 0.2 +
            motion.motionSmoothness * 0.2
        )
        
        return technicalScore * 0.4 + contentScore * 0.35 + motionScore * 0.25
    }
    
    private func detectEnergyPeaks(_ audioAnalysis: DetailedAudioAnalysis) -> [TimeInterval] {
        var peaks: [TimeInterval] = []
        let energyValues = audioAnalysis.energyProfile.map { $0.rmsAmplitude }
        
        guard energyValues.count > 2 else { return peaks }
        
        // Détection des pics locaux
        for i in 1..<(energyValues.count - 1) {
            let current = energyValues[i]
            let previous = energyValues[i - 1]
            let next = energyValues[i + 1]
            
            if current > previous && current > next && current > 0.6 {
                peaks.append(audioAnalysis.energyProfile[i].startTime)
            }
        }
        
        return peaks
    }
    
    private func calculatePreferenceBonus(_ segment: EnhancedVideoSegment, preferences: RushPreferences) -> Float {
        var bonus: Float = 1.0
        
        // Bonus pour les visages si préféré
        if preferences.preferFaces && segment.contentAnalysis.faceCount > 0 {
            bonus *= 1.3
        }
        
        // Bonus pour le mouvement selon les préférences
        switch preferences.motionPreference {
        case .high:
            bonus *= 1.0 + segment.motionAnalysis.overallMotion * 0.5
        case .low:
            bonus *= 1.0 + (1.0 - segment.motionAnalysis.overallMotion) * 0.3
        case .balanced:
            // Préférence pour un mouvement modéré
            let idealMotion: Float = 0.6
            let motionDiff = abs(segment.motionAnalysis.overallMotion - idealMotion)
            bonus *= 1.0 + (1.0 - motionDiff) * 0.2
        }
        
        return bonus
    }
    
    private func calculateDiversityBonus(_ segment: EnhancedVideoSegment, existingHighlights: [EnhancedVideoSegment]) -> Float {
        guard !existingHighlights.isEmpty else { return 1.0 }
        
        var diversityScore: Float = 1.0
        
        // Pénalité pour les segments trop similaires
        for existing in existingHighlights {
            let similarity = calculateSegmentSimilarity(segment, existing)
            if similarity > 0.8 {
                diversityScore *= 0.7
            } else if similarity > 0.6 {
                diversityScore *= 0.9
            }
        }
        
        return diversityScore
    }
    
    private func calculateSegmentSimilarity(_ segment1: EnhancedVideoSegment, _ segment2: EnhancedVideoSegment) -> Float {
        // Similarité basée sur plusieurs critères
        let technicalSim = calculateTechnicalSimilarity(segment1.technicalAnalysis, segment2.technicalAnalysis)
        let contentSim = calculateContentSimilarity(segment1.contentAnalysis, segment2.contentAnalysis)
        let motionSim = calculateMotionSimilarity(segment1.motionAnalysis, segment2.motionAnalysis)
        
        return (technicalSim + contentSim + motionSim) / 3.0
    }
    
    private func generateSegmentTags(
        technical: TechnicalAnalysis,
        content: ContentAnalysis,
        motion: MotionAnalysis
    ) -> [String] {
        
        var tags: [String] = []
        
        // Tags techniques
        if technical.sharpness > 0.8 { tags.append("haute_netteté") }
        if technical.stability > 0.9 { tags.append("très_stable") }
        if technical.exposure > 0.8 { tags.append("bien_exposé") }
        
        // Tags de contenu
        if content.faceCount > 0 { tags.append("visage") }
        if content.faceCount > 1 { tags.append("groupe") }
        if content.emotionScore > 0.7 { tags.append("émotionnel") }
        if content.aestheticScore > 0.8 { tags.append("esthétique") }
        
        // Tags de mouvement
        switch motion.motionType {
        case .stillness: tags.append("statique")
        case .smooth: tags.append("mouvement_fluide")
        case .dynamic: tags.append("dynamique")
        case .chaotic: tags.append("chaotique")
        }
        
        if motion.overallMotion > 0.7 { tags.append("action") }
        
        return tags
    }
    
    private func calculateTechnicalSimilarity(_ tech1: TechnicalAnalysis, _ tech2: TechnicalAnalysis) -> Float {
        let sharpnessDiff = abs(tech1.sharpness - tech2.sharpness)
        let exposureDiff = abs(tech1.exposure - tech2.exposure)
        let stabilityDiff = abs(tech1.stability - tech2.stability)
        
        return 1.0 - (sharpnessDiff + exposureDiff + stabilityDiff) / 3.0
    }
    
    private func calculateContentSimilarity(_ content1: ContentAnalysis, _ content2: ContentAnalysis) -> Float {
        let faceCountSim = 1.0 - abs(Float(content1.faceCount - content2.faceCount)) / 5.0
        let emotionSim = 1.0 - abs(content1.emotionScore - content2.emotionScore)
        let compositionSim = 1.0 - abs(content1.compositionScore - content2.compositionScore)
        
        return (faceCountSim + emotionSim + compositionSim) / 3.0
    }
    
    private func calculateMotionSimilarity(_ motion1: MotionAnalysis, _ motion2: MotionAnalysis) -> Float {
        let overallSim = 1.0 - abs(motion1.overallMotion - motion2.overallMotion)
        let typeSim: Float = motion1.motionType == motion2.motionType ? 1.0 : 0.5
        
        return (overallSim + typeSim) / 2.0
    }
    
    private func calculateTimelineScore(_ segment: VideoSegment, audioAnalysis: DetailedAudioAnalysis, preferences: RushPreferences) -> Float {
        // Score basé sur la qualité du segment et sa synchronisation avec l'audio
        var score = segment.qualityScore
        
        // Bonus pour la synchronisation avec les beats
        let segmentTime = segment.timeRange.start.seconds
        let nearestBeat = audioAnalysis.beatGrid.min { abs($0.timestamp - segmentTime) < abs($1.timestamp - segmentTime) }
        
        if let beat = nearestBeat, abs(beat.timestamp - segmentTime) < 0.2 {
            score *= 1.2
        }
        
        return score
    }
    
    private func reorderForOptimalFlow(_ segments: [VideoSegment], audioAnalysis: DetailedAudioAnalysis) -> [VideoSegment] {
        // Réorganisation basée sur l'énergie audio et la progression narrative
        return segments.sorted { segment1, segment2 in
            let time1 = segment1.timeRange.start.seconds
            let time2 = segment2.timeRange.start.seconds
            return time1 < time2
        }
    }
    
    private func calculateOverallConfidence(_ timeline: [VideoSegment]) -> Float {
        guard !timeline.isEmpty else { return 0 }
        
        let averageQuality = timeline.map { $0.qualityScore }.reduce(0, +) / Float(timeline.count)
        let diversityScore = calculateTimelineDiversity(timeline)
        
        return (averageQuality + diversityScore) / 2.0
    }
    
    private func calculateTimelineDiversity(_ timeline: [VideoSegment]) -> Float {
        // Calcul de la diversité basé sur les sources et les tags
        let uniqueSources = Set(timeline.map { $0.sourceURL }).count
        let totalSources = timeline.count
        
        return Float(uniqueSources) / Float(max(totalSources, 1))
    }
    
    private func generateImprovementSuggestions(_ timeline: [VideoSegment], preferences: RushPreferences) -> [String] {
        var suggestions: [String] = []
        
        if timeline.isEmpty {
            suggestions.append("Aucun segment sélectionné. Essayez de réduire les critères de qualité.")
            return suggestions
        }
        
        let averageQuality = timeline.map { $0.qualityScore }.reduce(0, +) / Float(timeline.count)
        
        if averageQuality < 0.7 {
            suggestions.append("La qualité moyenne est faible. Considérez l'amélioration de l'éclairage ou de la stabilité.")
        }
        
        let uniqueSources = Set(timeline.map { $0.sourceURL }).count
        if uniqueSources < 2 {
            suggestions.append("Ajoutez plus de sources vidéo pour une meilleure diversité.")
        }
        
        let totalDuration = timeline.reduce(0) { $0 + $1.timeRange.duration.seconds }
        if totalDuration < 10 {
            suggestions.append("La durée totale est courte. Ajoutez plus de contenu vidéo.")
        }
        
        return suggestions
    }
    
    private func generateRushMetadata(
        timeline: [VideoSegment],
        audioAnalysis: DetailedAudioAnalysis,
        originalSegments: [EnhancedVideoSegment],
        preferences: RushPreferences
    ) -> RushMetadata {
        
        return RushMetadata(
            totalOriginalDuration: originalSegments.reduce(0) { $0 + $1.timeRange.duration.seconds },
            finalTimelineDuration: timeline.reduce(0) { $0 + $1.timeRange.duration.seconds },
            compressionRatio: Float(timeline.count) / Float(originalSegments.count),
            averageQuality: timeline.map { $0.qualityScore }.reduce(0, +) / Float(max(timeline.count, 1)),
            bpmSync: audioAnalysis.bpm,
            energyProfile: audioAnalysis.energyProfile.map { $0.level },
            processingTime: Date(),
            preferences: preferences
        )
    }
    
    private func generateHighlightReasons(
        segment: EnhancedVideoSegment,
        hasEnergyPeak: Bool,
        preferences: RushPreferences
    ) -> [String] {
        
        var reasons: [String] = []
        
        if segment.overallScore > 0.8 {
            reasons.append("Excellente qualité technique")
        }
        
        if segment.contentAnalysis.faceCount > 0 {
            reasons.append("Présence de visages")
        }
        
        if hasEnergyPeak {
            reasons.append("Synchronisé avec un pic d'énergie audio")
        }
        
        if segment.motionAnalysis.overallMotion > 0.7 {
            reasons.append("Mouvement dynamique")
        }
        
        if segment.contentAnalysis.aestheticScore > 0.8 {
            reasons.append("Composition esthétique")
        }
        
        return reasons
    }
}

// MARK: - Supporting Types
struct EnhancedVideoSegment {
    let id: UUID
    let sourceURL: URL
    let timeRange: CMTimeRange
    let segmentIndex: Int
    let technicalAnalysis: TechnicalAnalysis
    let contentAnalysis: ContentAnalysis
    let motionAnalysis: MotionAnalysis
    let overallScore: Float
    let tags: [String]
    
    var highlightScore: Float = 0
    var highlightReasons: [String] = []
    
    func toVideoSegment() -> VideoSegment {
        return VideoSegment(
            id: id,
            sourceURL: sourceURL,
            timeRange: timeRange,
            qualityScore: overallScore,
            tags: tags,
            saliencyCenter: CGPoint(x: 0.5, y: 0.5) // Default center
        )
    }
}

struct TechnicalAnalysis {
    let sharpness: Float
    let exposure: Float
    let stability: Float
    let noise: Float
    let colorBalance: Float
    let contrast: Float
}

struct ContentAnalysis {
    let faceCount: Int
    let faceConfidence: Float
    let emotionScore: Float
    let compositionScore: Float
    let objectCount: Int
    let sceneComplexity: Float
    let aestheticScore: Float
}

struct MotionAnalysis {
    let overallMotion: Float
    let cameraMotion: Float
    let subjectMotion: Float
    let motionSmoothness: Float
    let directionChanges: Int
    let motionType: MotionType
}

enum MotionType: CaseIterable {
    case stillness, smooth, dynamic, chaotic
}

struct RushPreferences {
    let highlightThreshold: Float
    let preferFaces: Bool
    let motionPreference: MotionPreference
    let qualityPriority: Float
    let diversityPriority: Float
    
    init(
        highlightThreshold: Float = 0.7,
        preferFaces: Bool = true,
        motionPreference: MotionPreference = .balanced,
        qualityPriority: Float = 0.8,
        diversityPriority: Float = 0.6
    ) {
        self.highlightThreshold = highlightThreshold
        self.preferFaces = preferFaces
        self.motionPreference = motionPreference
        self.qualityPriority = qualityPriority
        self.diversityPriority = diversityPriority
    }
}

enum MotionPreference {
    case low, balanced, high
}

struct AutoRushResult {
    let timeline: [VideoSegment]
    let audioAnalysis: DetailedAudioAnalysis
    let metadata: RushMetadata
    let confidence: Float
    let suggestions: [String]
}

struct RushMetadata {
    let totalOriginalDuration: TimeInterval
    let finalTimelineDuration: TimeInterval
    let compressionRatio: Float
    let averageQuality: Float
    let bpmSync: Float
    let energyProfile: [EnergyLevel]
    let processingTime: Date
    let preferences: RushPreferences
}