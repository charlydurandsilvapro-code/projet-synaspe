import Foundation
import AVFoundation
import CoreMedia

// MARK: - Audio Buffer Models

/// Buffer audio sécurisé pour le traitement en streaming
public struct AudioBuffer {
    public let data: UnsafeBufferPointer<Float>
    public let frameCount: Int
    public let timestamp: CMTime
    public let sampleRate: Double
    public let channelCount: Int
    
    public init(
        data: UnsafeBufferPointer<Float>,
        frameCount: Int,
        timestamp: CMTime,
        sampleRate: Double,
        channelCount: Int = 1
    ) {
        self.data = data
        self.frameCount = frameCount
        self.timestamp = timestamp
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
    
    /// Durée du buffer en secondes
    public var duration: TimeInterval {
        Double(frameCount) / sampleRate
    }
    
    /// Taille en bytes
    public var sizeInBytes: Int {
        frameCount * MemoryLayout<Float>.size * channelCount
    }
}

/// Métadonnées audio associées
public struct AudioMetadata {
    public let timestamp: CMTime
    public let sampleRate: Double
    public let channelCount: Int
    public let frameCount: Int
    
    public init(timestamp: CMTime, sampleRate: Double, channelCount: Int, frameCount: Int) {
        self.timestamp = timestamp
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
    }
}

// MARK: - Audio Segment Models

/// Segment audio avec métadonnées d'analyse
public struct AudioSegment {
    public let startTime: CMTime
    public let endTime: CMTime
    public let rmsLevel: Float
    public let classification: AudioClassification
    public let beatAlignment: BeatAlignment?
    public let qualityScore: Float
    public let silenceAnalysis: SilenceAnalysis
    
    public init(
        startTime: CMTime,
        endTime: CMTime,
        rmsLevel: Float,
        classification: AudioClassification,
        beatAlignment: BeatAlignment? = nil,
        qualityScore: Float,
        silenceAnalysis: SilenceAnalysis
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.rmsLevel = rmsLevel
        self.classification = classification
        self.beatAlignment = beatAlignment
        self.qualityScore = qualityScore
        self.silenceAnalysis = silenceAnalysis
    }
    
    /// Durée du segment
    public var duration: TimeInterval {
        endTime.seconds - startTime.seconds
    }
    
    /// Niveau en dB
    public var dbLevel: Float {
        20 * log10(max(rmsLevel, 1e-10))
    }
}

/// Segment analysé avec toutes les métadonnées
public struct AnalyzedSegment {
    public let segment: AudioSegment
    public let contentAnalysis: ContentAnalysis
    public let rhythmAnalysis: RhythmAnalysis
    public let videoQuality: VideoQualityScore?
    
    public init(
        segment: AudioSegment,
        contentAnalysis: ContentAnalysis,
        rhythmAnalysis: RhythmAnalysis,
        videoQuality: VideoQualityScore? = nil
    ) {
        self.segment = segment
        self.contentAnalysis = contentAnalysis
        self.rhythmAnalysis = rhythmAnalysis
        self.videoQuality = videoQuality
    }
}

// MARK: - Audio Classification

/// Classification audio par SoundAnalysis
public struct AudioClassification {
    public let speech: Float
    public let music: Float
    public let noise: Float
    public let dominantType: AudioType
    public let confidence: Float
    public let timestamp: CMTime
    
    public init(
        speech: Float,
        music: Float,
        noise: Float,
        timestamp: CMTime
    ) {
        self.speech = speech
        self.music = music
        self.noise = noise
        self.timestamp = timestamp
        
        // Détermination du type dominant
        if speech >= music && speech >= noise {
            self.dominantType = .speech
            self.confidence = speech
        } else if music >= noise {
            self.dominantType = .music
            self.confidence = music
        } else {
            self.dominantType = .noise
            self.confidence = noise
        }
    }
}

/// Types audio supportés
public enum AudioType: String, CaseIterable {
    case speech = "Parole"
    case music = "Musique"
    case noise = "Bruit"
    
    public var priority: Int {
        switch self {
        case .speech: return 3
        case .music: return 2
        case .noise: return 1
        }
    }
}

// MARK: - Beat Detection Models

/// Point de rythme détecté
public struct BeatPoint {
    public let timestamp: CMTime
    public let strength: Float
    public let type: BeatType
    public let confidence: Float
    
    public init(timestamp: CMTime, strength: Float, type: BeatType, confidence: Float) {
        self.timestamp = timestamp
        self.strength = strength
        self.type = type
        self.confidence = confidence
    }
}

/// Types de rythmes détectés
public enum BeatType: String, CaseIterable {
    case kick = "Kick"
    case snare = "Caisse claire"
    case hihat = "Charleston"
    case cymbal = "Cymbale"
    case other = "Autre"
}

/// Alignement sur les rythmes
public struct BeatAlignment {
    public let nearestBeat: BeatPoint
    public let alignmentOffset: TimeInterval
    public let isAligned: Bool
    
    public init(nearestBeat: BeatPoint, alignmentOffset: TimeInterval) {
        self.nearestBeat = nearestBeat
        self.alignmentOffset = alignmentOffset
        self.isAligned = abs(alignmentOffset) <= 0.05 // 50ms de tolérance
    }
}

// MARK: - Analysis Results

/// Résultat d'analyse RMS
public struct RMSAnalysisResult {
    public let rmsValues: [Float]
    public let timestamps: [CMTime]
    public let averageRMS: Float
    public let peakRMS: Float
    public let silenceSegments: [SilenceSegment]
    
    public init(
        rmsValues: [Float],
        timestamps: [CMTime],
        silenceSegments: [SilenceSegment]
    ) {
        self.rmsValues = rmsValues
        self.timestamps = timestamps
        self.silenceSegments = silenceSegments
        self.averageRMS = rmsValues.isEmpty ? 0 : rmsValues.reduce(0, +) / Float(rmsValues.count)
        self.peakRMS = rmsValues.max() ?? 0
    }
}

/// Segment de silence détecté
public struct SilenceSegment {
    public let startTime: CMTime
    public let endTime: CMTime
    public let averageLevel: Float
    public let confidence: Float
    
    public init(startTime: CMTime, endTime: CMTime, averageLevel: Float, confidence: Float) {
        self.startTime = startTime
        self.endTime = endTime
        self.averageLevel = averageLevel
        self.confidence = confidence
    }
    
    public var duration: TimeInterval {
        endTime.seconds - startTime.seconds
    }
}

/// Analyse de silence
public struct SilenceAnalysis {
    public let isSilence: Bool
    public let silenceConfidence: Float
    public let averageLevel: Float
    public let duration: TimeInterval
    
    public init(isSilence: Bool, silenceConfidence: Float, averageLevel: Float, duration: TimeInterval) {
        self.isSilence = isSilence
        self.silenceConfidence = silenceConfidence
        self.averageLevel = averageLevel
        self.duration = duration
    }
}

/// Analyse de contenu
public struct ContentAnalysis {
    public let contentType: AudioType
    public let confidence: Float
    public let speechProbability: Float
    public let musicProbability: Float
    public let noiseProbability: Float
    public let shouldPreserve: Bool
    
    public init(
        contentType: AudioType,
        confidence: Float,
        speechProbability: Float,
        musicProbability: Float,
        noiseProbability: Float
    ) {
        self.contentType = contentType
        self.confidence = confidence
        self.speechProbability = speechProbability
        self.musicProbability = musicProbability
        self.noiseProbability = noiseProbability
        
        // Logique de préservation hiérarchique
        self.shouldPreserve = contentType == .speech || 
                             (contentType == .music && confidence > 0.6) ||
                             (contentType == .noise && confidence < 0.3)
    }
}

/// Analyse rythmique
public struct RhythmAnalysis {
    public let detectedBeats: [BeatPoint]
    public let estimatedTempo: Float
    public let rhythmStrength: Float
    public let isRhythmic: Bool
    
    public init(detectedBeats: [BeatPoint], estimatedTempo: Float, rhythmStrength: Float) {
        self.detectedBeats = detectedBeats
        self.estimatedTempo = estimatedTempo
        self.rhythmStrength = rhythmStrength
        self.isRhythmic = rhythmStrength > 0.5 && estimatedTempo > 60 && estimatedTempo < 200
    }
}

// MARK: - Video Quality Models

/// Score de qualité vidéo
public struct VideoQualityScore {
    public let timestamp: CMTime
    public let sharpness: Float
    public let exposure: Float
    public let colorBalance: Float
    public let motionBlur: Float
    public let overallQuality: Float
    
    public init(
        timestamp: CMTime,
        sharpness: Float,
        exposure: Float,
        colorBalance: Float,
        motionBlur: Float
    ) {
        self.timestamp = timestamp
        self.sharpness = sharpness
        self.exposure = exposure
        self.colorBalance = colorBalance
        self.motionBlur = motionBlur
        
        // Calcul de la qualité globale (moyenne pondérée)
        self.overallQuality = (sharpness * 0.4 + exposure * 0.3 + colorBalance * 0.2 + (1.0 - motionBlur) * 0.1)
    }
}

/// Score de qualité d'une frame
public struct FrameQualityScore {
    public let sharpness: Float
    public let brightness: Float
    public let contrast: Float
    public let saturation: Float
    public let noiseLevel: Float
    
    public init(sharpness: Float, brightness: Float, contrast: Float, saturation: Float, noiseLevel: Float) {
        self.sharpness = sharpness
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.noiseLevel = noiseLevel
    }
    
    public var overallScore: Float {
        let normalizedBrightness = 1.0 - abs(brightness - 0.5) * 2 // Optimal autour de 0.5
        let normalizedNoise = 1.0 - noiseLevel
        
        return (sharpness * 0.3 + normalizedBrightness * 0.2 + contrast * 0.2 + 
                saturation * 0.15 + normalizedNoise * 0.15)
    }
}