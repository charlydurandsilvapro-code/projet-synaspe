import Foundation
import CoreMedia

// MARK: - Processing Configuration

/// Configuration principale pour le traitement Neural Auto-Cut
public struct ProcessingConfiguration {
    
    // MARK: - Paramètres de Silence
    public let silenceThreshold: Float // -60dB à -30dB
    public let minimumSilenceDuration: TimeInterval // 100ms à 2s
    public let silenceDetectionSensitivity: SilenceDetectionSensitivity
    
    // MARK: - Paramètres de Parole
    public let speechSensitivity: SpeechSensitivity
    public let speechPreservationMode: SpeechPreservationMode
    public let minimumSpeechDuration: TimeInterval
    
    // MARK: - Paramètres Rythmiques
    public let rhythmMode: RhythmMode
    public let beatAlignmentTolerance: TimeInterval // ±10ms par défaut
    public let tempoRange: ClosedRange<Float> // 60-200 BPM
    
    // MARK: - Fonctionnalités Avancées
    public let enableVoiceDucking: Bool
    public let voiceDuckingAmount: Float // -15dB par défaut
    public let enableVideoAnalysis: Bool
    public let enableCrossfades: Bool
    public let crossfadeDuration: TimeInterval // 20ms par défaut
    
    // MARK: - Seuils de Qualité
    public let qualityThreshold: Float // 0.4 par défaut (40%)
    public let minimumSegmentDuration: TimeInterval // 0.5s par défaut
    public let maximumGapDuration: TimeInterval // 2.0s par défaut
    
    // MARK: - Performance
    public let bufferSize: Int // 1024 frames par défaut
    public let enableAppleSiliconOptimizations: Bool
    public let maxMemoryUsage: Int // 2GB par défaut
    
    public init(
        silenceThreshold: Float = -50.0,
        minimumSilenceDuration: TimeInterval = 0.5,
        silenceDetectionSensitivity: SilenceDetectionSensitivity = .medium,
        speechSensitivity: SpeechSensitivity = .medium,
        speechPreservationMode: SpeechPreservationMode = .aggressive,
        minimumSpeechDuration: TimeInterval = 0.2,
        rhythmMode: RhythmMode = .moderate,
        beatAlignmentTolerance: TimeInterval = 0.01,
        tempoRange: ClosedRange<Float> = 60...200,
        enableVoiceDucking: Bool = true,
        voiceDuckingAmount: Float = -15.0,
        enableVideoAnalysis: Bool = true,
        enableCrossfades: Bool = true,
        crossfadeDuration: TimeInterval = 0.02,
        qualityThreshold: Float = 0.4,
        minimumSegmentDuration: TimeInterval = 0.5,
        maximumGapDuration: TimeInterval = 2.0,
        bufferSize: Int = 1024,
        enableAppleSiliconOptimizations: Bool = true,
        maxMemoryUsage: Int = 2_000_000_000
    ) {
        self.silenceThreshold = silenceThreshold
        self.minimumSilenceDuration = minimumSilenceDuration
        self.silenceDetectionSensitivity = silenceDetectionSensitivity
        self.speechSensitivity = speechSensitivity
        self.speechPreservationMode = speechPreservationMode
        self.minimumSpeechDuration = minimumSpeechDuration
        self.rhythmMode = rhythmMode
        self.beatAlignmentTolerance = beatAlignmentTolerance
        self.tempoRange = tempoRange
        self.enableVoiceDucking = enableVoiceDucking
        self.voiceDuckingAmount = voiceDuckingAmount
        self.enableVideoAnalysis = enableVideoAnalysis
        self.enableCrossfades = enableCrossfades
        self.crossfadeDuration = crossfadeDuration
        self.qualityThreshold = qualityThreshold
        self.minimumSegmentDuration = minimumSegmentDuration
        self.maximumGapDuration = maximumGapDuration
        self.bufferSize = bufferSize
        self.enableAppleSiliconOptimizations = enableAppleSiliconOptimizations
        self.maxMemoryUsage = maxMemoryUsage
    }
    
    /// Validation de la configuration
    public func validate() throws {
        guard silenceThreshold >= -60.0 && silenceThreshold <= -30.0 else {
            throw ConfigurationError.invalidSilenceThreshold(silenceThreshold)
        }
        
        guard minimumSilenceDuration >= 0.1 && minimumSilenceDuration <= 5.0 else {
            throw ConfigurationError.invalidSilenceDuration(minimumSilenceDuration)
        }
        
        guard qualityThreshold >= 0.0 && qualityThreshold <= 1.0 else {
            throw ConfigurationError.invalidQualityThreshold(qualityThreshold)
        }
        
        guard bufferSize > 0 && bufferSize <= 8192 else {
            throw ConfigurationError.invalidBufferSize(bufferSize)
        }
        
        guard maxMemoryUsage > 100_000_000 else { // Minimum 100MB
            throw ConfigurationError.insufficientMemoryLimit(maxMemoryUsage)
        }
    }
}

// MARK: - Configuration Enums

/// Sensibilité de détection de silence
public enum SilenceDetectionSensitivity: String, CaseIterable {
    case low = "Faible"
    case medium = "Moyen"
    case high = "Élevé"
    
    public var thresholdAdjustment: Float {
        switch self {
        case .low: return 5.0    // Moins sensible (+5dB)
        case .medium: return 0.0 // Seuil par défaut
        case .high: return -5.0  // Plus sensible (-5dB)
        }
    }
    
    public var description: String {
        switch self {
        case .low: return "Détection moins sensible, garde plus de contenu"
        case .medium: return "Équilibre entre précision et préservation"
        case .high: return "Détection très sensible, supprime plus de silences"
        }
    }
}

/// Sensibilité de détection de parole
public enum SpeechSensitivity: String, CaseIterable {
    case low = "Faible"
    case medium = "Moyen"
    case high = "Élevé"
    
    public var confidenceThreshold: Float {
        switch self {
        case .low: return 0.3
        case .medium: return 0.5
        case .high: return 0.7
        }
    }
    
    public var description: String {
        switch self {
        case .low: return "Détecte la parole même avec faible confiance"
        case .medium: return "Équilibre entre précision et rappel"
        case .high: return "Ne détecte que la parole très claire"
        }
    }
}

/// Mode de préservation de la parole
public enum SpeechPreservationMode: String, CaseIterable {
    case conservative = "Conservateur"
    case balanced = "Équilibré"
    case aggressive = "Agressif"
    
    public var preservationFactor: Float {
        switch self {
        case .conservative: return 1.5 // Garde 50% plus de contexte
        case .balanced: return 1.2     // Garde 20% plus de contexte
        case .aggressive: return 1.0   // Garde uniquement la parole détectée
        }
    }
    
    public var description: String {
        switch self {
        case .conservative: return "Préserve beaucoup de contexte autour de la parole"
        case .balanced: return "Préserve un contexte modéré"
        case .aggressive: return "Préserve uniquement la parole pure"
        }
    }
}

/// Mode de synchronisation rythmique
public enum RhythmMode: String, CaseIterable {
    case disabled = "Désactivé"
    case moderate = "Modéré"
    case aggressive = "Agressif"
    
    public var alignmentStrength: Float {
        switch self {
        case .disabled: return 0.0
        case .moderate: return 0.5
        case .aggressive: return 1.0
        }
    }
    
    public var description: String {
        switch self {
        case .disabled: return "Pas d'alignement rythmique"
        case .moderate: return "Alignement rythmique modéré"
        case .aggressive: return "Alignement rythmique fort sur tous les beats"
        }
    }
}

// MARK: - Configuration Builder

/// Constructeur de configuration avec méthodes fluides
public struct ProcessingConfigurationBuilder {
    private var config: ProcessingConfiguration
    
    private init(config: ProcessingConfiguration) {
        self.config = config
    }
    
    // MARK: - Presets
    
    /// Configuration par défaut équilibrée
    public static func defaultConfiguration() -> ProcessingConfigurationBuilder {
        return ProcessingConfigurationBuilder(config: ProcessingConfiguration())
    }
    
    /// Configuration optimisée pour les podcasts
    public static func podcastConfiguration() -> ProcessingConfigurationBuilder {
        let config = ProcessingConfiguration(
            silenceThreshold: -45.0,
            minimumSilenceDuration: 0.8,
            silenceDetectionSensitivity: .medium,
            speechSensitivity: .high,
            speechPreservationMode: .conservative,
            rhythmMode: .disabled,
            enableVoiceDucking: true,
            enableVideoAnalysis: false,
            qualityThreshold: 0.3
        )
        return ProcessingConfigurationBuilder(config: config)
    }
    
    /// Configuration optimisée pour les vidéos musicales
    public static func musicVideoConfiguration() -> ProcessingConfigurationBuilder {
        let config = ProcessingConfiguration(
            silenceThreshold: -55.0,
            minimumSilenceDuration: 0.3,
            silenceDetectionSensitivity: .high,
            speechSensitivity: .medium,
            speechPreservationMode: .balanced,
            rhythmMode: .aggressive,
            enableVoiceDucking: false,
            enableVideoAnalysis: true,
            qualityThreshold: 0.6
        )
        return ProcessingConfigurationBuilder(config: config)
    }
    
    /// Configuration optimisée pour les présentations
    public static func presentationConfiguration() -> ProcessingConfigurationBuilder {
        let config = ProcessingConfiguration(
            silenceThreshold: -40.0,
            minimumSilenceDuration: 1.0,
            silenceDetectionSensitivity: .low,
            speechSensitivity: .high,
            speechPreservationMode: .conservative,
            rhythmMode: .disabled,
            enableVoiceDucking: true,
            enableVideoAnalysis: true,
            qualityThreshold: 0.5
        )
        return ProcessingConfigurationBuilder(config: config)
    }
    
    /// Configuration pour contenu créatif/vlog
    public static func creativeContentConfiguration() -> ProcessingConfigurationBuilder {
        let config = ProcessingConfiguration(
            silenceThreshold: -48.0,
            minimumSilenceDuration: 0.6,
            silenceDetectionSensitivity: .medium,
            speechSensitivity: .medium,
            speechPreservationMode: .balanced,
            rhythmMode: .moderate,
            enableVoiceDucking: true,
            enableVideoAnalysis: true,
            qualityThreshold: 0.45
        )
        return ProcessingConfigurationBuilder(config: config)
    }
    
    // MARK: - Fluent Interface
    
    public func withSilenceThreshold(_ threshold: Float) -> ProcessingConfigurationBuilder {
        var newConfig = config
        newConfig = ProcessingConfiguration(
            silenceThreshold: threshold,
            minimumSilenceDuration: config.minimumSilenceDuration,
            silenceDetectionSensitivity: config.silenceDetectionSensitivity,
            speechSensitivity: config.speechSensitivity,
            speechPreservationMode: config.speechPreservationMode,
            minimumSpeechDuration: config.minimumSpeechDuration,
            rhythmMode: config.rhythmMode,
            beatAlignmentTolerance: config.beatAlignmentTolerance,
            tempoRange: config.tempoRange,
            enableVoiceDucking: config.enableVoiceDucking,
            voiceDuckingAmount: config.voiceDuckingAmount,
            enableVideoAnalysis: config.enableVideoAnalysis,
            enableCrossfades: config.enableCrossfades,
            crossfadeDuration: config.crossfadeDuration,
            qualityThreshold: config.qualityThreshold,
            minimumSegmentDuration: config.minimumSegmentDuration,
            maximumGapDuration: config.maximumGapDuration,
            bufferSize: config.bufferSize,
            enableAppleSiliconOptimizations: config.enableAppleSiliconOptimizations,
            maxMemoryUsage: config.maxMemoryUsage
        )
        return ProcessingConfigurationBuilder(config: newConfig)
    }
    
    public func withRhythmMode(_ mode: RhythmMode) -> ProcessingConfigurationBuilder {
        var newConfig = config
        newConfig = ProcessingConfiguration(
            silenceThreshold: config.silenceThreshold,
            minimumSilenceDuration: config.minimumSilenceDuration,
            silenceDetectionSensitivity: config.silenceDetectionSensitivity,
            speechSensitivity: config.speechSensitivity,
            speechPreservationMode: config.speechPreservationMode,
            minimumSpeechDuration: config.minimumSpeechDuration,
            rhythmMode: mode,
            beatAlignmentTolerance: config.beatAlignmentTolerance,
            tempoRange: config.tempoRange,
            enableVoiceDucking: config.enableVoiceDucking,
            voiceDuckingAmount: config.voiceDuckingAmount,
            enableVideoAnalysis: config.enableVideoAnalysis,
            enableCrossfades: config.enableCrossfades,
            crossfadeDuration: config.crossfadeDuration,
            qualityThreshold: config.qualityThreshold,
            minimumSegmentDuration: config.minimumSegmentDuration,
            maximumGapDuration: config.maximumGapDuration,
            bufferSize: config.bufferSize,
            enableAppleSiliconOptimizations: config.enableAppleSiliconOptimizations,
            maxMemoryUsage: config.maxMemoryUsage
        )
        return ProcessingConfigurationBuilder(config: newConfig)
    }
    
    public func withVoiceDucking(_ enabled: Bool) -> ProcessingConfigurationBuilder {
        var newConfig = config
        newConfig = ProcessingConfiguration(
            silenceThreshold: config.silenceThreshold,
            minimumSilenceDuration: config.minimumSilenceDuration,
            silenceDetectionSensitivity: config.silenceDetectionSensitivity,
            speechSensitivity: config.speechSensitivity,
            speechPreservationMode: config.speechPreservationMode,
            minimumSpeechDuration: config.minimumSpeechDuration,
            rhythmMode: config.rhythmMode,
            beatAlignmentTolerance: config.beatAlignmentTolerance,
            tempoRange: config.tempoRange,
            enableVoiceDucking: enabled,
            voiceDuckingAmount: config.voiceDuckingAmount,
            enableVideoAnalysis: config.enableVideoAnalysis,
            enableCrossfades: config.enableCrossfades,
            crossfadeDuration: config.crossfadeDuration,
            qualityThreshold: config.qualityThreshold,
            minimumSegmentDuration: config.minimumSegmentDuration,
            maximumGapDuration: config.maximumGapDuration,
            bufferSize: config.bufferSize,
            enableAppleSiliconOptimizations: config.enableAppleSiliconOptimizations,
            maxMemoryUsage: config.maxMemoryUsage
        )
        return ProcessingConfigurationBuilder(config: newConfig)
    }
    
    public func withVideoAnalysis(_ enabled: Bool) -> ProcessingConfigurationBuilder {
        var newConfig = config
        newConfig = ProcessingConfiguration(
            silenceThreshold: config.silenceThreshold,
            minimumSilenceDuration: config.minimumSilenceDuration,
            silenceDetectionSensitivity: config.silenceDetectionSensitivity,
            speechSensitivity: config.speechSensitivity,
            speechPreservationMode: config.speechPreservationMode,
            minimumSpeechDuration: config.minimumSpeechDuration,
            rhythmMode: config.rhythmMode,
            beatAlignmentTolerance: config.beatAlignmentTolerance,
            tempoRange: config.tempoRange,
            enableVoiceDucking: config.enableVoiceDucking,
            voiceDuckingAmount: config.voiceDuckingAmount,
            enableVideoAnalysis: enabled,
            enableCrossfades: config.enableCrossfades,
            crossfadeDuration: config.crossfadeDuration,
            qualityThreshold: config.qualityThreshold,
            minimumSegmentDuration: config.minimumSegmentDuration,
            maximumGapDuration: config.maximumGapDuration,
            bufferSize: config.bufferSize,
            enableAppleSiliconOptimizations: config.enableAppleSiliconOptimizations,
            maxMemoryUsage: config.maxMemoryUsage
        )
        return ProcessingConfigurationBuilder(config: newConfig)
    }
    
    public func withQualityThreshold(_ threshold: Float) -> ProcessingConfigurationBuilder {
        var newConfig = config
        newConfig = ProcessingConfiguration(
            silenceThreshold: config.silenceThreshold,
            minimumSilenceDuration: config.minimumSilenceDuration,
            silenceDetectionSensitivity: config.silenceDetectionSensitivity,
            speechSensitivity: config.speechSensitivity,
            speechPreservationMode: config.speechPreservationMode,
            minimumSpeechDuration: config.minimumSpeechDuration,
            rhythmMode: config.rhythmMode,
            beatAlignmentTolerance: config.beatAlignmentTolerance,
            tempoRange: config.tempoRange,
            enableVoiceDucking: config.enableVoiceDucking,
            voiceDuckingAmount: config.voiceDuckingAmount,
            enableVideoAnalysis: config.enableVideoAnalysis,
            enableCrossfades: config.enableCrossfades,
            crossfadeDuration: config.crossfadeDuration,
            qualityThreshold: threshold,
            minimumSegmentDuration: config.minimumSegmentDuration,
            maximumGapDuration: config.maximumGapDuration,
            bufferSize: config.bufferSize,
            enableAppleSiliconOptimizations: config.enableAppleSiliconOptimizations,
            maxMemoryUsage: config.maxMemoryUsage
        )
        return ProcessingConfigurationBuilder(config: newConfig)
    }
    
    /// Construit la configuration finale
    public func build() throws -> ProcessingConfiguration {
        try config.validate()
        return config
    }
}

// MARK: - Configuration Errors

public enum ConfigurationError: Error, LocalizedError {
    case invalidSilenceThreshold(Float)
    case invalidSilenceDuration(TimeInterval)
    case invalidQualityThreshold(Float)
    case invalidBufferSize(Int)
    case insufficientMemoryLimit(Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidSilenceThreshold(let threshold):
            return "Seuil de silence invalide: \(threshold)dB. Doit être entre -60dB et -30dB."
        case .invalidSilenceDuration(let duration):
            return "Durée de silence invalide: \(duration)s. Doit être entre 0.1s et 5.0s."
        case .invalidQualityThreshold(let threshold):
            return "Seuil de qualité invalide: \(threshold). Doit être entre 0.0 et 1.0."
        case .invalidBufferSize(let size):
            return "Taille de buffer invalide: \(size). Doit être entre 1 et 8192."
        case .insufficientMemoryLimit(let limit):
            return "Limite mémoire insuffisante: \(limit) bytes. Minimum 100MB requis."
        }
    }
}