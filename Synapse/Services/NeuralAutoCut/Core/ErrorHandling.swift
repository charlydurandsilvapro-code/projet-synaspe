import Foundation

// MARK: - Neural Auto-Cut Errors

/// Erreurs principales du moteur Neural Auto-Cut
public enum NeuralAutoCutError: Error, LocalizedError {
    
    // MARK: - Asset Errors
    case invalidAsset(String)
    case unsupportedFormat(String)
    case assetLoadingFailed(String)
    case noAudioTrack
    case noVideoTrack
    case corruptedAsset(String)
    
    // MARK: - Processing Errors
    case processingFailed(String)
    case processingInProgress
    case processingCancelled
    case analysisTimeout
    case insufficientMemory
    case bufferAllocationFailed
    
    // MARK: - Configuration Errors
    case configurationError(String)
    case invalidConfiguration(ConfigurationError)
    case unsupportedConfiguration(String)
    
    // MARK: - Audio Analysis Errors
    case audioExtractionFailed(String)
    case rmsAnalysisFailed(String)
    case soundClassificationFailed(String)
    case beatDetectionFailed(String)
    case silenceDetectionFailed(String)
    
    // MARK: - Video Analysis Errors
    case videoAnalysisFailed(String)
    case visionProcessingFailed(String)
    case frameExtractionFailed(String)
    
    // MARK: - Composition Errors
    case compositionCreationFailed(String)
    case audioMixCreationFailed(String)
    case trackInsertionFailed(String)
    case crossfadeApplicationFailed(String)
    case voiceDuckingFailed(String)
    
    // MARK: - Export Errors
    case exportFailed(String)
    case unsupportedExportFormat(String)
    case exportPermissionDenied
    case diskSpaceInsufficient
    
    // MARK: - System Errors
    case systemResourceUnavailable(String)
    case frameworkUnavailable(String)
    case hardwareUnsupported(String)
    
    public var errorDescription: String? {
        switch self {
        // Asset Errors
        case .invalidAsset(let message):
            return "Asset invalide : \(message)"
        case .unsupportedFormat(let format):
            return "Format non supporté : \(format)"
        case .assetLoadingFailed(let message):
            return "Échec du chargement de l'asset : \(message)"
        case .noAudioTrack:
            return "Aucune piste audio trouvée dans le fichier"
        case .noVideoTrack:
            return "Aucune piste vidéo trouvée dans le fichier"
        case .corruptedAsset(let message):
            return "Asset corrompu : \(message)"
            
        // Processing Errors
        case .processingFailed(let reason):
            return "Échec du traitement : \(reason)"
        case .processingInProgress:
            return "Un traitement est déjà en cours"
        case .processingCancelled:
            return "Le traitement a été annulé"
        case .analysisTimeout:
            return "Timeout de l'analyse - fichier trop volumineux ou complexe"
        case .insufficientMemory:
            return "Mémoire insuffisante pour traiter ce fichier"
        case .bufferAllocationFailed:
            return "Échec de l'allocation des buffers audio"
            
        // Configuration Errors
        case .configurationError(let message):
            return "Erreur de configuration : \(message)"
        case .invalidConfiguration(let configError):
            return "Configuration invalide : \(configError.localizedDescription)"
        case .unsupportedConfiguration(let message):
            return "Configuration non supportée : \(message)"
            
        // Audio Analysis Errors
        case .audioExtractionFailed(let message):
            return "Échec de l'extraction audio : \(message)"
        case .rmsAnalysisFailed(let message):
            return "Échec de l'analyse RMS : \(message)"
        case .soundClassificationFailed(let message):
            return "Échec de la classification audio : \(message)"
        case .beatDetectionFailed(let message):
            return "Échec de la détection de rythme : \(message)"
        case .silenceDetectionFailed(let message):
            return "Échec de la détection de silence : \(message)"
            
        // Video Analysis Errors
        case .videoAnalysisFailed(let message):
            return "Échec de l'analyse vidéo : \(message)"
        case .visionProcessingFailed(let message):
            return "Échec du traitement Vision : \(message)"
        case .frameExtractionFailed(let message):
            return "Échec de l'extraction des frames : \(message)"
            
        // Composition Errors
        case .compositionCreationFailed(let message):
            return "Échec de la création de composition : \(message)"
        case .audioMixCreationFailed(let message):
            return "Échec de la création du mix audio : \(message)"
        case .trackInsertionFailed(let message):
            return "Échec de l'insertion de piste : \(message)"
        case .crossfadeApplicationFailed(let message):
            return "Échec de l'application des fondus enchaînés : \(message)"
        case .voiceDuckingFailed(let message):
            return "Échec du ducking vocal : \(message)"
            
        // Export Errors
        case .exportFailed(let message):
            return "Échec de l'export : \(message)"
        case .unsupportedExportFormat(let format):
            return "Format d'export non supporté : \(format)"
        case .exportPermissionDenied:
            return "Permission d'écriture refusée pour l'export"
        case .diskSpaceInsufficient:
            return "Espace disque insuffisant pour l'export"
            
        // System Errors
        case .systemResourceUnavailable(let resource):
            return "Ressource système indisponible : \(resource)"
        case .frameworkUnavailable(let framework):
            return "Framework indisponible : \(framework)"
        case .hardwareUnsupported(let message):
            return "Matériel non supporté : \(message)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidAsset, .unsupportedFormat, .assetLoadingFailed, .noAudioTrack, .noVideoTrack, .corruptedAsset:
            return "Problème avec le fichier source"
        case .processingFailed, .processingInProgress, .processingCancelled, .analysisTimeout:
            return "Problème de traitement"
        case .insufficientMemory, .bufferAllocationFailed:
            return "Problème de mémoire"
        case .configurationError, .invalidConfiguration, .unsupportedConfiguration:
            return "Problème de configuration"
        case .audioExtractionFailed, .rmsAnalysisFailed, .soundClassificationFailed, .beatDetectionFailed, .silenceDetectionFailed:
            return "Problème d'analyse audio"
        case .videoAnalysisFailed, .visionProcessingFailed, .frameExtractionFailed:
            return "Problème d'analyse vidéo"
        case .compositionCreationFailed, .audioMixCreationFailed, .trackInsertionFailed, .crossfadeApplicationFailed, .voiceDuckingFailed:
            return "Problème de composition"
        case .exportFailed, .unsupportedExportFormat, .exportPermissionDenied, .diskSpaceInsufficient:
            return "Problème d'export"
        case .systemResourceUnavailable, .frameworkUnavailable, .hardwareUnsupported:
            return "Problème système"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidAsset, .unsupportedFormat, .corruptedAsset:
            return "Vérifiez que le fichier est valide et dans un format supporté (MP4, MOV, etc.)"
        case .noAudioTrack:
            return "Assurez-vous que le fichier contient une piste audio"
        case .noVideoTrack:
            return "Assurez-vous que le fichier contient une piste vidéo"
        case .assetLoadingFailed:
            return "Vérifiez que le fichier n'est pas corrompu et est accessible"
        case .processingFailed:
            return "Vérifiez les paramètres et réessayez avec un fichier plus simple"
        case .processingInProgress:
            return "Attendez la fin du traitement en cours ou annulez-le"
        case .processingCancelled:
            return "Relancez le traitement si nécessaire"
        case .analysisTimeout:
            return "Essayez avec un fichier plus petit ou augmentez le timeout"
        case .insufficientMemory, .bufferAllocationFailed:
            return "Fermez d'autres applications ou utilisez un fichier plus petit"
        case .configurationError, .invalidConfiguration:
            return "Vérifiez les paramètres de configuration"
        case .unsupportedConfiguration:
            return "Utilisez une configuration supportée ou les presets disponibles"
        case .audioExtractionFailed, .rmsAnalysisFailed, .soundClassificationFailed:
            return "Vérifiez la qualité de l'audio source"
        case .beatDetectionFailed:
            return "Le contenu musical pourrait être trop complexe ou absent"
        case .silenceDetectionFailed:
            return "Ajustez les paramètres de détection de silence"
        case .videoAnalysisFailed, .visionProcessingFailed, .frameExtractionFailed:
            return "Vérifiez la qualité de la vidéo source"
        case .compositionCreationFailed, .audioMixCreationFailed, .trackInsertionFailed:
            return "Vérifiez que les segments sont valides"
        case .crossfadeApplicationFailed, .voiceDuckingFailed:
            return "Désactivez les fonctionnalités avancées si le problème persiste"
        case .exportFailed:
            return "Vérifiez l'espace disque et les permissions"
        case .unsupportedExportFormat:
            return "Choisissez un format d'export supporté"
        case .exportPermissionDenied:
            return "Accordez les permissions d'écriture ou choisissez un autre dossier"
        case .diskSpaceInsufficient:
            return "Libérez de l'espace disque"
        case .systemResourceUnavailable:
            return "Redémarrez l'application ou le système"
        case .frameworkUnavailable:
            return "Mettez à jour macOS vers une version compatible"
        case .hardwareUnsupported:
            return "Utilisez un Mac compatible (Apple Silicon recommandé)"
        }
    }
}

// MARK: - Error Recovery Strategies

/// Stratégies de récupération d'erreurs
public struct ErrorRecoveryStrategy {
    public let canRetry: Bool
    public let shouldFallback: Bool
    public let fallbackAction: (() async throws -> Void)?
    public let userAction: String?
    
    public init(
        canRetry: Bool = false,
        shouldFallback: Bool = false,
        fallbackAction: (() async throws -> Void)? = nil,
        userAction: String? = nil
    ) {
        self.canRetry = canRetry
        self.shouldFallback = shouldFallback
        self.fallbackAction = fallbackAction
        self.userAction = userAction
    }
    
    /// Stratégie de récupération pour une erreur donnée
    public static func strategy(for error: NeuralAutoCutError) -> ErrorRecoveryStrategy {
        switch error {
        case .processingFailed, .analysisTimeout:
            return ErrorRecoveryStrategy(
                canRetry: true,
                shouldFallback: true,
                userAction: "Réessayer avec des paramètres moins agressifs"
            )
            
        case .insufficientMemory, .bufferAllocationFailed:
            return ErrorRecoveryStrategy(
                canRetry: true,
                shouldFallback: true,
                userAction: "Réduire la taille du buffer ou fermer d'autres applications"
            )
            
        case .soundClassificationFailed, .beatDetectionFailed:
            return ErrorRecoveryStrategy(
                canRetry: false,
                shouldFallback: true,
                userAction: "Continuer sans cette fonctionnalité"
            )
            
        case .videoAnalysisFailed, .visionProcessingFailed:
            return ErrorRecoveryStrategy(
                canRetry: false,
                shouldFallback: true,
                userAction: "Continuer sans analyse vidéo"
            )
            
        case .crossfadeApplicationFailed, .voiceDuckingFailed:
            return ErrorRecoveryStrategy(
                canRetry: false,
                shouldFallback: true,
                userAction: "Désactiver les effets avancés"
            )
            
        case .invalidAsset, .unsupportedFormat, .noAudioTrack:
            return ErrorRecoveryStrategy(
                canRetry: false,
                shouldFallback: false,
                userAction: "Choisir un autre fichier"
            )
            
        case .processingInProgress:
            return ErrorRecoveryStrategy(
                canRetry: true,
                shouldFallback: false,
                userAction: "Attendre ou annuler le traitement en cours"
            )
            
        default:
            return ErrorRecoveryStrategy(
                canRetry: true,
                shouldFallback: false,
                userAction: "Réessayer ou contacter le support"
            )
        }
    }
}

// MARK: - Error Context

/// Contexte d'erreur pour le débogage
public struct ErrorContext {
    public let timestamp: Date
    public let operation: String
    public let parameters: [String: Any]
    public let systemInfo: SystemInfo
    public let stackTrace: [String]
    
    public init(
        operation: String,
        parameters: [String: Any] = [:],
        systemInfo: SystemInfo = SystemInfo.current(),
        stackTrace: [String] = Thread.callStackSymbols
    ) {
        self.timestamp = Date()
        self.operation = operation
        self.parameters = parameters
        self.systemInfo = systemInfo
        self.stackTrace = stackTrace
    }
}

/// Information système pour le débogage
public struct SystemInfo {
    public let osVersion: String
    public let deviceModel: String
    public let availableMemory: Int64
    public let cpuCount: Int
    public let isAppleSilicon: Bool
    
    public init(
        osVersion: String,
        deviceModel: String,
        availableMemory: Int64,
        cpuCount: Int,
        isAppleSilicon: Bool
    ) {
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.availableMemory = availableMemory
        self.cpuCount = cpuCount
        self.isAppleSilicon = isAppleSilicon
    }
    
    public static func current() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        
        return SystemInfo(
            osVersion: processInfo.operatingSystemVersionString,
            deviceModel: getDeviceModel(),
            availableMemory: Int64(processInfo.physicalMemory),
            cpuCount: processInfo.processorCount,
            isAppleSilicon: isRunningOnAppleSilicon()
        )
    }
    
    private static func getDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    private static func isRunningOnAppleSilicon() -> Bool {
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        var result: Int32 = 0
        let success = sysctlbyname("hw.optional.arm64", &result, &size, nil, 0)
        return success == 0 && result == 1
    }
}

// MARK: - Error Reporter

/// Rapporteur d'erreurs pour le monitoring
public protocol ErrorReporter {
    func reportError(_ error: NeuralAutoCutError, context: ErrorContext)
    func reportRecovery(_ error: NeuralAutoCutError, strategy: ErrorRecoveryStrategy, success: Bool)
}

/// Implémentation par défaut du rapporteur d'erreurs
public class DefaultErrorReporter: ErrorReporter {
    private let logger: NeuralLogger
    
    public init(logger: NeuralLogger) {
        self.logger = logger
    }
    
    public func reportError(_ error: NeuralAutoCutError, context: ErrorContext) {
        logger.error("Erreur Neural Auto-Cut", metadata: [
            "error": "\(error)",
            "operation": context.operation,
            "timestamp": "\(context.timestamp)",
            "systemInfo": [
                "osVersion": context.systemInfo.osVersion,
                "deviceModel": context.systemInfo.deviceModel,
                "availableMemory": context.systemInfo.availableMemory,
                "isAppleSilicon": context.systemInfo.isAppleSilicon
            ]
        ])
    }
    
    public func reportRecovery(_ error: NeuralAutoCutError, strategy: ErrorRecoveryStrategy, success: Bool) {
        let level: NeuralLogger.Level = success ? .info : .warning
        logger.log(level: level, "Récupération d'erreur", metadata: [
            "error": "\(error)",
            "strategy": [
                "canRetry": strategy.canRetry,
                "shouldFallback": strategy.shouldFallback,
                "userAction": strategy.userAction ?? "Aucune"
            ],
            "success": success
        ])
    }
}

// MARK: - C Imports for System Info
import Darwin.sys.sysctl