import Foundation
import Vision
import AVFoundation
import CoreMedia
import CoreVideo
import CoreImage

// MARK: - Vision Analysis Engine

/// Moteur d'analyse vidéo utilisant le framework Vision pour l'évaluation de la qualité visuelle
@available(macOS 14.0, *)
actor VisionAnalysisEngine {
    
    // MARK: - Properties
    private let logger = NeuralLogger.visionAnalyzer
    private let configuration: ProcessingConfiguration
    
    // MARK: - Vision Components
    private var imageRequestHandler: VNImageRequestHandler?
    private var qualityRequests: [VNRequest] = []
    
    // MARK: - Analysis State
    private var isAnalyzing: Bool = false
    private var frameCount: Int = 0
    private var totalProcessingTime: TimeInterval = 0
    
    // MARK: - Initialization
    
    init(configuration: ProcessingConfiguration) {
        self.configuration = configuration
        
        // L'initialisation sera faite de manière asynchrone
        
        logger.info("VisionAnalysisEngine initialisé", metadata: [
            "enable_video_analysis": configuration.enableVideoAnalysis
        ])
    }
    
    // MARK: - Public Interface
    
    /// Initialise l'analyseur de manière asynchrone
    func initialize() async {
        await setupVisionRequests()
    }
    
    /// Analyse la qualité vidéo d'un asset complet
    func analyzeVideoQuality(_ asset: AVAsset) -> AsyncThrowingStream<VideoQualityScore, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard configuration.enableVideoAnalysis else {
                        continuation.finish()
                        return
                    }
                    
                    isAnalyzing = true
                    defer { isAnalyzing = false }
                    
                    let _ = try await getVideoTrack(from: asset)
                    let frameGenerator = AVAssetImageGenerator(asset: asset)
                    frameGenerator.appliesPreferredTrackTransform = true
                    frameGenerator.requestedTimeToleranceBefore = .zero
                    frameGenerator.requestedTimeToleranceAfter = .zero
                    
                    let duration = try await asset.load(.duration)
                    let frameInterval: TimeInterval = 1.0 // Une frame par seconde
                    let totalFrames = Int(duration.seconds / frameInterval)
                    
                    logger.info("Début analyse vidéo", metadata: [
                        "duration": duration.seconds,
                        "total_frames": totalFrames,
                        "frame_interval": frameInterval
                    ])
                    
                    for frameIndex in 0..<totalFrames {
                        let timestamp = CMTime(seconds: Double(frameIndex) * frameInterval, preferredTimescale: 600)
                        
                        do {
                            let cgImage = try frameGenerator.copyCGImage(at: timestamp, actualTime: nil)
                            let qualityScore = try await analyzeFrameQuality(cgImage, timestamp: timestamp)
                            continuation.yield(qualityScore)
                            
                            frameCount += 1
                            
                        } catch {
                            logger.warning("Échec analyse frame", metadata: [
                                "frame_index": frameIndex,
                                "timestamp": timestamp.seconds,
                                "error": error.localizedDescription
                            ])
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    logger.error("Erreur analyse vidéo", metadata: [
                        "error": error.localizedDescription
                    ])
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Analyse la qualité d'une frame spécifique
    func assessFrameQuality(_ frame: CVPixelBuffer) async throws -> FrameQualityScore {
        let cgImage = try createCGImage(from: frame)
        let timestamp = CMTime.zero // Pas de timestamp pour une frame isolée
        let videoQuality = try await analyzeFrameQuality(cgImage, timestamp: timestamp)
        
        return FrameQualityScore(
            sharpness: videoQuality.sharpness,
            brightness: videoQuality.exposure,
            contrast: videoQuality.colorBalance,
            saturation: videoQuality.colorBalance,
            noiseLevel: 1.0 - videoQuality.overallQuality
        )
    }
    
    /// Obtient les statistiques d'analyse actuelles
    var analysisStatistics: VisionAnalysisStatistics {
        get async {
            return VisionAnalysisStatistics(
                isAnalyzing: isAnalyzing,
                framesAnalyzed: frameCount,
                totalProcessingTime: totalProcessingTime,
                averageProcessingTime: frameCount > 0 ? totalProcessingTime / Double(frameCount) : 0
            )
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupVisionRequests() {
        // Configuration des requêtes Vision pour l'analyse de qualité
        qualityRequests = [
            createSharpnessRequest(),
            createExposureRequest(),
            createColorBalanceRequest()
        ]
    }
    
    private func createSharpnessRequest() -> VNRequest {
        // Utilisation de la détection de contours pour évaluer la netteté
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = true
        return request
    }
    
    private func createExposureRequest() -> VNRequest {
        // Utilisation de l'analyse d'histogramme pour l'exposition
        let request = VNGenerateImageFeaturePrintRequest()
        return request
    }
    
    private func createColorBalanceRequest() -> VNRequest {
        // Utilisation de la classification de scène pour l'équilibre colorimétrique
        let request = VNClassifyImageRequest()
        return request
    }
    
    private func getVideoTrack(from asset: AVAsset) async throws -> AVAssetTrack {
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NeuralAutoCutError.noVideoTrack
        }
        return videoTrack
    }
    
    private func analyzeFrameQuality(_ cgImage: CGImage, timestamp: CMTime) async throws -> VideoQualityScore {
        let startTime = Date()
        
        // Création du handler pour cette image
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Analyse de netteté
        let sharpness = try await analyzeSharpness(requestHandler)
        
        // Analyse d'exposition
        let exposure = try await analyzeExposure(requestHandler, cgImage: cgImage)
        
        // Analyse d'équilibre colorimétrique
        let colorBalance = try await analyzeColorBalance(requestHandler)
        
        // Analyse de flou de mouvement (estimation basée sur la netteté)
        let motionBlur = estimateMotionBlur(sharpness: sharpness)
        
        let processingTime = Date().timeIntervalSince(startTime)
        totalProcessingTime += processingTime
        
        let qualityScore = VideoQualityScore(
            timestamp: timestamp,
            sharpness: sharpness,
            exposure: exposure,
            colorBalance: colorBalance,
            motionBlur: motionBlur
        )
        
        logger.debug("Frame analysée", metadata: [
            "timestamp": timestamp.seconds,
            "sharpness": sharpness,
            "exposure": exposure,
            "color_balance": colorBalance,
            "motion_blur": motionBlur,
            "overall_quality": qualityScore.overallQuality,
            "processing_time_ms": Int(processingTime * 1000)
        ])
        
        return qualityScore
    }
    
    private func analyzeSharpness(_ requestHandler: VNImageRequestHandler) async throws -> Float {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectContoursRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNContoursObservation] else {
                    continuation.resume(returning: 0.5) // Valeur par défaut
                    return
                }
                
                // Calcul de la netteté basé sur le nombre et la qualité des contours
                let totalContours = results.reduce(0) { $0 + $1.contourCount }
                let sharpnessScore = min(1.0, Float(totalContours) / 1000.0) // Normalisation
                
                continuation.resume(returning: sharpnessScore)
            }
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func analyzeExposure(_ requestHandler: VNImageRequestHandler, cgImage: CGImage) async throws -> Float {
        // Analyse simple de l'exposition basée sur la luminosité moyenne
        let width = cgImage.width
        let height = cgImage.height
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0.5 // Valeur par défaut
        }
        
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        var totalBrightness: Int = 0
        var pixelCount: Int = 0
        
        // Échantillonnage de pixels pour calculer la luminosité moyenne
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                
                if pixelIndex + 2 < CFDataGetLength(data) {
                    let r = Int(bytes[pixelIndex])
                    let g = Int(bytes[pixelIndex + 1])
                    let b = Int(bytes[pixelIndex + 2])
                    
                    // Calcul de la luminosité (formule standard)
                    let brightness = Int(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
                    totalBrightness += brightness
                    pixelCount += 1
                }
            }
        }
        
        guard pixelCount > 0 else { return 0.5 }
        
        let averageBrightness = Float(totalBrightness) / Float(pixelCount)
        let normalizedBrightness = averageBrightness / 255.0
        
        // Score d'exposition optimal autour de 0.5 (128/255)
        let exposureScore = 1.0 - abs(normalizedBrightness - 0.5) * 2
        
        return max(0.0, min(1.0, exposureScore))
    }
    
    private func analyzeColorBalance(_ requestHandler: VNImageRequestHandler) async throws -> Float {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNFeaturePrintObservation],
                      let featurePrint = results.first else {
                    continuation.resume(returning: 0.5) // Valeur par défaut
                    return
                }
                
                // Estimation de l'équilibre colorimétrique basée sur la diversité des features
                // Plus il y a de features variées, meilleur est l'équilibre colorimétrique
                let featureCount = featurePrint.data.count
                let colorBalanceScore = min(1.0, Float(featureCount) / 1000.0)
                
                continuation.resume(returning: colorBalanceScore)
            }
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func estimateMotionBlur(sharpness: Float) -> Float {
        // Estimation simple : plus c'est net, moins il y a de flou de mouvement
        return max(0.0, 1.0 - sharpness)
    }
    
    private func createCGImage(from pixelBuffer: CVPixelBuffer) throws -> CGImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw NeuralAutoCutError.frameExtractionFailed("Impossible de créer CGImage depuis CVPixelBuffer")
        }
        
        return cgImage
    }
}

// MARK: - Supporting Types

/// Statistiques d'analyse Vision
public struct VisionAnalysisStatistics {
    public let isAnalyzing: Bool
    public let framesAnalyzed: Int
    public let totalProcessingTime: TimeInterval
    public let averageProcessingTime: TimeInterval
    
    public var framesPerSecond: Float {
        return totalProcessingTime > 0 ? Float(framesAnalyzed) / Float(totalProcessingTime) : 0
    }
    
    public var status: String {
        return isAnalyzing ? "Analyse en cours" : "Inactif"
    }
    
    public var efficiency: String {
        let fps = framesPerSecond
        switch fps {
        case 10...: return "Très rapide"
        case 5..<10: return "Rapide"
        case 1..<5: return "Modéré"
        default: return "Lent"
        }
    }
}

// MARK: - Extensions

extension VisionAnalysisEngine {
    
    /// Analyse rapide de qualité pour un échantillon de frames
    func quickQualityAssessment(_ asset: AVAsset, sampleCount: Int = 10) -> AsyncThrowingStream<VideoQualityScore, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard configuration.enableVideoAnalysis else {
                        continuation.finish()
                        return
                    }
                    
                    let duration = try await asset.load(.duration)
                    let frameGenerator = AVAssetImageGenerator(asset: asset)
                    frameGenerator.appliesPreferredTrackTransform = true
                    
                    let interval = duration.seconds / Double(sampleCount)
                    
                    for i in 0..<sampleCount {
                        let timestamp = CMTime(seconds: Double(i) * interval, preferredTimescale: 600)
                        
                        do {
                            let cgImage = try frameGenerator.copyCGImage(at: timestamp, actualTime: nil)
                            let qualityScore = try await analyzeFrameQuality(cgImage, timestamp: timestamp)
                            continuation.yield(qualityScore)
                        } catch {
                            logger.warning("Échec analyse frame échantillon", metadata: [
                                "sample_index": i,
                                "timestamp": timestamp.seconds,
                                "error": error.localizedDescription
                            ])
                        }
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}