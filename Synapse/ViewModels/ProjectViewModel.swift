import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@available(macOS 14.0, *)
@MainActor
class ProjectViewModel: ObservableObject {
    @Published var project: ProjectState
    @Published var isProcessing: Bool = false
    @Published var processingStatus: String = ""
    @Published var videoURLs: [URL] = []
    @Published var audioURL: URL?
    @Published var previewSegments: [VideoSegment] = []
    @Published var thumbnails: [UUID: CGImage] = [:]
    @Published var enableSmartFeatures: Bool = true
    @Published var selectedPlatform: SocialPlatform = .instagram
    @Published var timelineResult: TimelineResult?
    
    // Nouveau moteur de timeline magnétique
    let timelineEngine = TimelineEngine()
    
    // Nouveaux services d'IA simplifiés
    private let audioAnalysisEngine = SimplifiedAudioAnalysisEngine()
    private let smartCutEngine = SimplifiedSmartCutEngine()
    private let autoRushEngine = SimplifiedAutoRushEngine()
    
    // Services simulés pour la compatibilité
    private let neuralIngestor = MockNeuralIngestor()
    private let audioBrain = MockAudioBrain()
    private let montageDirector = MockMontageDirector()
    
    // Résultats d'analyse détaillés
    @Published var detailedAudioAnalysis: DetailedAudioAnalysis?
    @Published var autoRushResult: AutoRushResult?
    @Published var rushPreferences = RushPreferences()
    
    init() {
        self.project = ProjectState()
    }
    
    func addVideos(_ urls: [URL]) async {
        videoURLs.append(contentsOf: urls)
        await analyzeVideos(urls)
    }
    
    func addAudio(_ url: URL) async {
        audioURL = url
        await analyzeAudio(url)
    }
    
    private func analyzeVideos(_ urls: [URL]) async {
        isProcessing = true
        processingStatus = "Analyse des vidéos en cours..."
        
        var allSegments: [VideoSegment] = []
        
        for url in urls {
            do {
                processingStatus = "Analyse de \(url.lastPathComponent)..."
                let segments = try await neuralIngestor.analyzeVideo(url: url)
                allSegments.append(contentsOf: segments)
                
                // Simulation d'un délai pour montrer le processus
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
            } catch {
                print("Failed to analyze video: \(error)")
            }
        }
        
        previewSegments = allSegments
        isProcessing = false
        processingStatus = ""
    }
    
    private func analyzeAudio(_ url: URL) async {
        isProcessing = true
        processingStatus = "Analyse audio avancée en cours..."
        
        do {
            // Utilisation du nouveau moteur d'analyse audio
            if enableSmartFeatures {
                detailedAudioAnalysis = try await audioAnalysisEngine.analyzeAudio(from: url)
                
                // Conversion vers l'ancien format pour compatibilité
                if let detailed = detailedAudioAnalysis {
                    project.musicTrack = AudioTrack(
                        url: detailed.url,
                        bpm: detailed.bpm,
                        beatGrid: detailed.beatGrid,
                        energyProfile: detailed.energyProfile
                    )
                }
            } else {
                // Fallback vers l'ancienne méthode
                let audioTrack = try await audioBrain.analyzeAudio(url: url)
                project.musicTrack = audioTrack
            }
            
            // Simulation d'un délai
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 secondes
        } catch {
            print("Failed to analyze audio: \(error)")
            processingStatus = "Erreur d'analyse audio: \(error.localizedDescription)"
        }
        
        isProcessing = false
        if processingStatus.contains("Erreur") == false {
            processingStatus = ""
        }
    }
    
    func generateTimeline() async {
        guard let musicTrack = project.musicTrack else {
            print("No music track available")
            return
        }
        
        guard !previewSegments.isEmpty else {
            print("No video segments available")
            return
        }
        
        isProcessing = true
        processingStatus = "Génération de la timeline intelligente..."
        
        do {
            if enableSmartFeatures, let detailedAnalysis = detailedAudioAnalysis {
                // Utilisation du nouveau système d'auto-cut intelligent
                let smartCuts = try await smartCutEngine.generateSmartCuts(
                    for: previewSegments,
                    with: detailedAnalysis,
                    targetDuration: selectedPlatform.idealDuration,
                    platform: selectedPlatform
                )
                
                project.timeline = smartCuts
            } else {
                // Fallback vers l'ancienne méthode
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
                
                let timeline = try await montageDirector.generateTimeline(
                    videoSegments: previewSegments,
                    audioTrack: musicTrack
                )
                
                project.timeline = timeline
            }
            
            // Synchroniser avec le moteur de timeline magnétique
            syncToTimelineEngine()
            
            project.modifiedAt = Date()
            
            processingStatus = "Génération des vignettes..."
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
            
            // Génération des thumbnails
            await generateThumbnails()
            
        } catch {
            print("Failed to generate timeline: \(error)")
            processingStatus = "Erreur de génération: \(error.localizedDescription)"
        }
        
        isProcessing = false
        if processingStatus.contains("Erreur") == false {
            processingStatus = ""
        }
    }
    
    // MARK: - Nouvelle méthode d'auto-rush intelligente
    func performIntelligentAutoRush() async {
        guard !videoURLs.isEmpty, let audioURL = audioURL else {
            processingStatus = "Vidéos et audio requis pour l'auto-rush"
            return
        }
        
        isProcessing = true
        processingStatus = "Démarrage de l'auto-rush intelligent..."
        
        do {
            autoRushResult = try await autoRushEngine.performAutoRush(
                videoURLs: videoURLs,
                audioURL: audioURL,
                targetDuration: selectedPlatform.idealDuration,
                platform: selectedPlatform,
                preferences: rushPreferences
            )
            
            if let result = autoRushResult {
                // Mise à jour du projet avec les résultats
                project.timeline = result.timeline
                detailedAudioAnalysis = result.audioAnalysis
                project.musicTrack = AudioTrack(
                    url: result.audioAnalysis.url,
                    bpm: result.audioAnalysis.bpm,
                    beatGrid: result.audioAnalysis.beatGrid,
                    energyProfile: result.audioAnalysis.energyProfile
                )
                project.modifiedAt = Date()
                
                // Génération des thumbnails
                await generateThumbnails()
                
                processingStatus = "Auto-rush terminé avec succès!"
                
                // Affichage des suggestions d'amélioration
                if !result.suggestions.isEmpty {
                    print("Suggestions d'amélioration:")
                    for suggestion in result.suggestions {
                        print("- \(suggestion)")
                    }
                }
            }
            
        } catch {
            print("Failed to perform auto-rush: \(error)")
            processingStatus = "Erreur d'auto-rush: \(error.localizedDescription)"
        }
        
        // Nettoyage après 3 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if !self.processingStatus.contains("Erreur") {
                self.isProcessing = false
                self.processingStatus = ""
            }
        }
    }
    
    // MARK: - Méthodes d'analyse audio avancées
    func analyzeAudioInRealTime() async {
        guard let audioURL = audioURL else { return }
        
        do {
            detailedAudioAnalysis = try await audioAnalysisEngine.analyzeAudio(from: audioURL)
        } catch {
            print("Real-time audio analysis failed: \(error)")
        }
    }
    
    func generateSmartCutsOnly() async {
        guard let detailedAnalysis = detailedAudioAnalysis, !previewSegments.isEmpty else {
            processingStatus = "Analyse audio et segments vidéo requis"
            return
        }
        
        isProcessing = true
        processingStatus = "Génération des coupes intelligentes..."
        
        do {
            let smartCuts = try await smartCutEngine.generateSmartCuts(
                for: previewSegments,
                with: detailedAnalysis,
                targetDuration: selectedPlatform.idealDuration,
                platform: selectedPlatform
            )
            
            // Synchroniser avec le moteur de timeline magnétique
            syncToTimelineEngine()
            
            await generateThumbnails()
            
        } catch {
            print("Smart cuts generation failed: \(error)")
            processingStatus = "Erreur de génération des coupes: \(error.localizedDescription)"
        }
        
        isProcessing = false
        if processingStatus.contains("Erreur") == false {
            processingStatus = ""
        }
    }
    
    // MARK: - Timeline Engine Synchronization
    
    /// Synchronise les segments du projet avec le moteur de timeline magnétique
    func syncToTimelineEngine() {
        timelineEngine.segments = project.timeline
    }
    
    /// Synchronise les segments du moteur vers le projet
    func syncFromTimelineEngine() {
        project.timeline = timelineEngine.segments
        project.modifiedAt = Date()sProcessing = false
        if processingStatus.contains("Erreur") == false {
            processingStatus = ""
        }
    }
    
    // MARK: - Mode Démonstration
    func runDemoMode() async {
        isProcessing = true
        processingStatus = "Initialisation du mode démo..."
        
        // Simulation de fichiers vidéo et audio
        let demoVideoURL = URL(fileURLWithPath: "/demo/video1.mp4")
        let demoAudioURL = URL(fileURLWithPath: "/demo/music.mp3")
        
        videoURLs = [demoVideoURL]
        audioURL = demoAudioURL
        
        do {
            processingStatus = "Génération de données de démonstration..."
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
            
            // Génération de segments de démonstration
            var demoSegments: [VideoSegment] = []
            
            for i in 0..<6 {
                let startTime = Double(i) * 3.0
                let segment = VideoSegment(
                    sourceURL: demoVideoURL,
                    timeRange: CMTimeRangeMake(
                        start: CMTime(seconds: startTime, preferredTimescale: 600),
                        duration: CMTime(seconds: 3.0, preferredTimescale: 600)
                    ),
                    qualityScore: Float.random(in: 0.6...0.95),
                    tags: ["demo", "qualité_\(Int.random(in: 70...95))", "auto_généré"],
                    saliencyCenter: CGPoint(
                        x: Double.random(in: 0.3...0.7),
                        y: Double.random(in: 0.3...0.7)
                    )
                )
                demoSegments.append(segment)
            }
            
            previewSegments = demoSegments
            
            processingStatus = "Analyse audio de démonstration..."
            try await Task.sleep(nanoseconds: 800_000_000) // 0.8 secondes
            
            // Génération d'analyse audio de démo
            detailedAudioAnalysis = try await audioAnalysisEngine.analyzeAudio(from: demoAudioURL)
            
            if let analysis = detailedAudioAnalysis {
                project.musicTrack = AudioTrack(
                    url: analysis.url,
                    bpm: analysis.bpm,
                    beatGrid: analysis.beatGrid,
                    energyProfile: analysis.energyProfile
                )
            }
            
            processingStatus = "Auto-rush intelligent en cours..."
            try await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 secondes
            
            // Exécution de l'auto-rush
            if let analysis = detailedAudioAnalysis {
                let smartCuts = try await smartCutEngine.generateSmartCuts(
                    for: previewSegments,
                    with: analysis,
                    targetDuration: selectedPlatform.idealDuration,
                    platform: selectedPlatform
                )
                
                project.timeline = smartCuts
                project.modifiedAt = Date()
                
                // Génération des thumbnails
                await generateThumbnails()
                
                processingStatus = "Démo terminée avec succès!"
                
                // Simulation d'un résultat d'auto-rush
                autoRushResult = AutoRushResult(
                    timeline: smartCuts,
                    audioAnalysis: analysis,
                    metadata: RushMetadata(
                        totalOriginalDuration: Double(demoSegments.count) * 3.0,
                        finalTimelineDuration: smartCuts.reduce(0) { $0 + $1.timeRange.duration.seconds },
                        compressionRatio: Float(smartCuts.count) / Float(demoSegments.count),
                        averageQuality: smartCuts.map { $0.qualityScore }.reduce(0, +) / Float(max(smartCuts.count, 1)),
                        bpmSync: analysis.bpm,
                        energyProfile: analysis.energyProfile.map { $0.level },
                        processingTime: Date(),
                        preferences: rushPreferences
                    ),
                    confidence: 0.87,
                    suggestions: [
                        "Excellente synchronisation avec la musique",
                        "Qualité vidéo optimale détectée",
                        "Timeline équilibrée générée"
                    ]
                )
            }
            
        } catch {
            processingStatus = "Erreur de démonstration: \(error.localizedDescription)"
        }
        
        // Nettoyage après 3 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if !self.processingStatus.contains("Erreur") {
                self.isProcessing = false
                self.processingStatus = ""
            }
        }
    }
    func updateRushPreferences(
        highlightThreshold: Float? = nil,
        preferFaces: Bool? = nil,
        motionPreference: MotionPreference? = nil,
        qualityPriority: Float? = nil,
        diversityPriority: Float? = nil
    ) {
        rushPreferences = RushPreferences(
            highlightThreshold: highlightThreshold ?? rushPreferences.highlightThreshold,
            preferFaces: preferFaces ?? rushPreferences.preferFaces,
            motionPreference: motionPreference ?? rushPreferences.motionPreference,
            qualityPriority: qualityPriority ?? rushPreferences.qualityPriority,
            diversityPriority: diversityPriority ?? rushPreferences.diversityPriority
        )
    }
    
    private func generateThumbnails() async {
        var newThumbnails: [UUID: CGImage] = [:]
        
        for segment in project.timeline {
            // Simulation de génération de thumbnail
            if let thumbnail = await generateMockThumbnail(for: segment) {
                newThumbnails[segment.id] = thumbnail
            }
        }
        
        thumbnails = newThumbnails
    }
    
    private func generateMockThumbnail(for segment: VideoSegment) async -> CGImage? {
        // Génération d'une image de test colorée
        let size = CGSize(width: 160, height: 90)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let ctx = context else { return nil }
        
        // Couleur basée sur le score de qualité
        let hue = CGFloat(segment.qualityScore)
        let color = NSColor(hue: hue, saturation: 0.7, brightness: 0.8, alpha: 1.0)
        
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        
        // Ajout du score de qualité comme texte
        let text = String(format: "%.1f", segment.qualityScore)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.white
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        
        let line = CTLineCreateWithAttributedString(attributedString)
        ctx.textPosition = CGPoint(x: textRect.minX, y: size.height - textRect.maxY)
        CTLineDraw(line, ctx)
        
        ctx.restoreGState()
        
        return ctx.makeImage()
    }
    
    func removeSegment(_ segment: VideoSegment) {
        project.timeline.removeAll { $0.id == segment.id }
        previewSegments.removeAll { $0.id == segment.id }
        project.modifiedAt = Date()
    }
    
    func favoriteSegment(_ segment: VideoSegment) {
        if let index = previewSegments.firstIndex(where: { $0.id == segment.id }) {
            var updatedSegment = previewSegments[index]
            updatedSegment = VideoSegment(
                id: updatedSegment.id,
                sourceURL: updatedSegment.sourceURL,
                timeRange: updatedSegment.timeRange,
                qualityScore: min(updatedSegment.qualityScore + 0.2, 1.0),
                tags: updatedSegment.tags,
                saliencyCenter: updatedSegment.saliencyCenter
            )
            previewSegments[index] = updatedSegment
        }
    }
    
    func exportProject(to url: URL) async {
        isProcessing = true
        processingStatus = "Export en cours..."
        
        // Simulation de l'export
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 secondes
        
        processingStatus = "Export terminé!"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isProcessing = false
            self.processingStatus = ""
        }
    }
    
    func changeColorProfile(_ profile: ColorProfile) {
        project.globalColorProfile = profile
        project.modifiedAt = Date()
    }
    
    func changeAspectRatio(width: CGFloat, height: CGFloat) {
        project.aspectRatio = CGSize(width: width, height: height)
        project.modifiedAt = Date()
    }
    
    func generatePreviewVideo(outputURL: URL) async {
        isProcessing = true
        processingStatus = "Génération de l'aperçu..."
        
        // Simulation
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
        
        processingStatus = "Aperçu prêt!"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isProcessing = false
            self.processingStatus = ""
        }
    }
    
    func autoFillTimeline() async {
        isProcessing = true
        processingStatus = "Remplissage automatique..."
        
        // Simulation
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 secondes
        
        isProcessing = false
        processingStatus = ""
    }
    
    func optimizeForPlatform() async {
        isProcessing = true
        processingStatus = "Optimisation pour \(selectedPlatform.rawValue)..."
        
        // Simulation
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
        
        isProcessing = false
        processingStatus = ""
    }
    
    func refreshThumbnails() async {
        await generateThumbnails()
    }
}

// MARK: - Mock Services (pour la démo)

struct MockNeuralIngestor {
    func analyzeVideo(url: URL) async throws -> [VideoSegment] {
        // Simulation d'analyse vidéo
        let duration = 10.0 // Durée simulée
        let segmentCount = Int.random(in: 3...8)
        var segments: [VideoSegment] = []
        
        for i in 0..<segmentCount {
            let startTime = Double(i) * (duration / Double(segmentCount))
            let segmentDuration = duration / Double(segmentCount)
            
            let segment = VideoSegment(
                sourceURL: url,
                timeRange: CMTimeRangeMake(
                    start: CMTime(seconds: startTime, preferredTimescale: 600),
                    duration: CMTime(seconds: segmentDuration, preferredTimescale: 600)
                ),
                qualityScore: Float.random(in: 0.3...0.9),
                tags: generateRandomTags(),
                saliencyCenter: CGPoint(
                    x: Double.random(in: 0.3...0.7),
                    y: Double.random(in: 0.3...0.7)
                )
            )
            
            segments.append(segment)
        }
        
        return segments
    }
    
    private func generateRandomTags() -> [String] {
        let allTags = ["visage", "sourire", "action", "intérieur", "extérieur", "faible_éclairage", "haute_qualité"]
        let count = Int.random(in: 1...3)
        return Array(allTags.shuffled().prefix(count))
    }
}

struct MockAudioBrain {
    func analyzeAudio(url: URL) async throws -> AudioTrack {
        // Simulation d'analyse audio
        let bpm = Float.random(in: 80...140)
        let duration = 60.0 // Durée simulée
        
        var beatGrid: [BeatMarker] = []
        let beatInterval = 60.0 / Double(bpm)
        
        for i in 0..<Int(duration / beatInterval) {
            let timestamp = Double(i) * beatInterval
            let beat = BeatMarker(
                timestamp: timestamp,
                confidence: Float.random(in: 0.7...1.0),
                isDownbeat: i % 4 == 0
            )
            beatGrid.append(beat)
        }
        
        let energyProfile = generateEnergyProfile(duration: duration)
        
        return AudioTrack(
            url: url,
            bpm: bpm,
            beatGrid: beatGrid,
            energyProfile: energyProfile
        )
    }
    
    private func generateEnergyProfile(duration: Double) -> [EnergySegment] {
        var segments: [EnergySegment] = []
        let segmentDuration = 4.0
        let segmentCount = Int(duration / segmentDuration)
        
        for i in 0..<segmentCount {
            let startTime = Double(i) * segmentDuration
            let levels: [EnergyLevel] = [.low, .mid, .high]
            let level = levels.randomElement() ?? .mid
            
            let segment = EnergySegment(
                startTime: startTime,
                duration: segmentDuration,
                level: level,
                rmsAmplitude: Float.random(in: 0.1...0.8)
            )
            
            segments.append(segment)
        }
        
        return segments
    }
}

struct MockMontageDirector {
    func generateTimeline(videoSegments: [VideoSegment], audioTrack: AudioTrack) async throws -> [VideoSegment] {
        // Simulation de génération de timeline
        let sortedSegments = videoSegments.sorted { $0.qualityScore > $1.qualityScore }
        let selectedCount = min(sortedSegments.count, 8) // Maximum 8 segments
        
        return Array(sortedSegments.prefix(selectedCount))
    }
}

// MARK: - Supporting Types

enum SocialPlatform: String, CaseIterable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case youtube = "YouTube"
    case facebook = "Facebook"
    
    var idealDuration: TimeInterval {
        switch self {
        case .instagram: return 30.0
        case .tiktok: return 15.0
        case .youtube: return 60.0
        case .facebook: return 45.0
        }
    }
    
    var maxDuration: TimeInterval {
        switch self {
        case .instagram: return 60.0
        case .tiktok: return 60.0
        case .youtube: return 180.0
        case .facebook: return 120.0
        }
    }
}

struct TimelineResult {
    let segments: [VideoSegment]
    let transitions: [TransitionPoint] = []
    let totalDuration: TimeInterval
    let voiceSegments: [VoiceSegment] = []
}

struct TransitionPoint {
    let time: TimeInterval
    let fromSegment: UUID
    let toSegment: UUID
    let transitionType: TransitionType
    let duration: TimeInterval
    let motionLevel: Float
    let colorSimilarity: Float
}

enum TransitionType: String {
    case hardCut
    case crossDissolve
    case fade
    case wipe
    case zoom
    case slide
}

struct VoiceSegment {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
    
    var duration: TimeInterval {
        endTime - startTime
    }
}