import Foundation
import os.log

// MARK: - Neural Logger

/// Logger spécialisé pour le moteur Neural Auto-Cut
public class NeuralLogger {
    
    // MARK: - Log Levels
    public enum Level: String, CaseIterable, Comparable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        public static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.priority < rhs.priority
        }
        
        var priority: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .warning: return 2
            case .error: return 3
            case .critical: return 4
            }
        }
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - Properties
    private let category: String
    private let subsystem: String
    private let osLog: OSLog
    private let minimumLevel: Level
    private let dateFormatter: DateFormatter
    private let enableConsoleOutput: Bool
    private let enableFileOutput: Bool
    private let logFileURL: URL?
    
    // MARK: - Initialization
    
    public init(
        category: String,
        subsystem: String = "com.synapse.neural-auto-cut",
        minimumLevel: Level = .info,
        enableConsoleOutput: Bool = true,
        enableFileOutput: Bool = false,
        logFileURL: URL? = nil
    ) {
        self.category = category
        self.subsystem = subsystem
        self.osLog = OSLog(subsystem: subsystem, category: category)
        self.minimumLevel = minimumLevel
        self.enableConsoleOutput = enableConsoleOutput
        self.enableFileOutput = enableFileOutput
        self.logFileURL = logFileURL ?? Self.defaultLogFileURL()
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter.locale = Locale(identifier: "fr_FR")
    }
    
    // MARK: - Logging Methods
    
    /// Log avec niveau spécifique
    public func log(level: Level, _ message: String, metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        guard level >= minimumLevel else { return }
        
        let logEntry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            metadata: metadata,
            file: URL(fileURLWithPath: file).lastPathComponent,
            function: function,
            line: line
        )
        
        processLogEntry(logEntry)
    }
    
    /// Log de debug
    public func debug(_ message: String, metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log d'information
    public func info(_ message: String, metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log d'avertissement
    public func warning(_ message: String, metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log d'erreur
    public func error(_ message: String, metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    /// Log critique
    public func critical(_ message: String, metadata: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message, metadata: metadata, file: file, function: function, line: line)
    }
    
    // MARK: - Specialized Logging
    
    /// Log de performance avec mesure de temps
    public func performance(_ operation: String, duration: TimeInterval, metadata: [String: Any] = [:]) {
        var performanceMetadata = metadata
        performanceMetadata["duration_ms"] = Int(duration * 1000)
        performanceMetadata["operation_type"] = "performance"
        
        let level: Level = duration > 1.0 ? .warning : .info
        log(level: level, "Performance: \(operation)", metadata: performanceMetadata)
    }
    
    /// Log de mémoire
    public func memory(_ operation: String, memoryUsage: Int64, metadata: [String: Any] = [:]) {
        var memoryMetadata = metadata
        memoryMetadata["memory_bytes"] = memoryUsage
        memoryMetadata["memory_mb"] = memoryUsage / (1024 * 1024)
        memoryMetadata["operation_type"] = "memory"
        
        let level: Level = memoryUsage > 1_000_000_000 ? .warning : .info // > 1GB
        log(level: level, "Mémoire: \(operation)", metadata: memoryMetadata)
    }
    
    /// Log d'analyse audio
    public func audioAnalysis(_ message: String, segmentCount: Int? = nil, duration: TimeInterval? = nil, metadata: [String: Any] = [:]) {
        var analysisMetadata = metadata
        analysisMetadata["analysis_type"] = "audio"
        if let count = segmentCount {
            analysisMetadata["segment_count"] = count
        }
        if let dur = duration {
            analysisMetadata["duration_seconds"] = dur
        }
        
        log(level: .info, "Analyse Audio: \(message)", metadata: analysisMetadata)
    }
    
    /// Log d'analyse vidéo
    public func videoAnalysis(_ message: String, frameCount: Int? = nil, resolution: CGSize? = nil, metadata: [String: Any] = [:]) {
        var analysisMetadata = metadata
        analysisMetadata["analysis_type"] = "video"
        if let count = frameCount {
            analysisMetadata["frame_count"] = count
        }
        if let res = resolution {
            analysisMetadata["resolution"] = "\(Int(res.width))x\(Int(res.height))"
        }
        
        log(level: .info, "Analyse Vidéo: \(message)", metadata: analysisMetadata)
    }
    
    // MARK: - Private Methods
    
    private func processLogEntry(_ entry: LogEntry) {
        // OSLog (système)
        os_log("%{public}@", log: osLog, type: entry.level.osLogType, formatLogEntry(entry))
        
        // Console output
        if enableConsoleOutput {
            print(formatConsoleOutput(entry))
        }
        
        // File output
        if enableFileOutput {
            writeToFile(entry)
        }
    }
    
    private func formatLogEntry(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let location = "\(entry.file):\(entry.line)"
        
        var formatted = "[\(timestamp)] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)"
        
        if !entry.metadata.isEmpty {
            let metadataString = formatMetadata(entry.metadata)
            formatted += " | \(metadataString)"
        }
        
        formatted += " (\(location))"
        return formatted
    }
    
    private func formatConsoleOutput(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        let emoji = entry.level.emoji
        
        var output = "\(emoji) [\(timestamp)] [\(entry.category)] \(entry.message)"
        
        if !entry.metadata.isEmpty {
            output += "\n   📋 Métadonnées: \(formatMetadata(entry.metadata))"
        }
        
        if entry.level >= .error {
            output += "\n   📍 Localisation: \(entry.file):\(entry.line) in \(entry.function)"
        }
        
        return output
    }
    
    private func formatMetadata(_ metadata: [String: Any]) -> String {
        return metadata.map { key, value in
            "\(key)=\(formatMetadataValue(value))"
        }.joined(separator: ", ")
    }
    
    private func formatMetadataValue(_ value: Any) -> String {
        switch value {
        case let string as String:
            return "\"\(string)\""
        case let number as NSNumber:
            return number.stringValue
        case let array as [Any]:
            return "[\(array.map { formatMetadataValue($0) }.joined(separator: ", "))]"
        case let dict as [String: Any]:
            return "{\(formatMetadata(dict))}"
        default:
            return "\(value)"
        }
    }
    
    private func writeToFile(_ entry: LogEntry) {
        guard let fileURL = logFileURL else { return }
        
        let logLine = formatLogEntry(entry) + "\n"
        
        DispatchQueue.global(qos: .utility).async {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(logLine.data(using: .utf8) ?? Data())
                    fileHandle.closeFile()
                } else {
                    try logLine.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                // Fallback vers console si l'écriture fichier échoue
                print("⚠️ Échec écriture log fichier: \(error)")
                print(self.formatConsoleOutput(entry))
            }
        }
    }
    
    private static func defaultLogFileURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Synapse/Logs")
        
        // Créer le dossier si nécessaire
        try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        return logsDirectory.appendingPathComponent("neural-auto-cut-\(dateString).log")
    }
}

// MARK: - Log Entry

/// Entrée de log structurée
private struct LogEntry {
    let timestamp: Date
    let level: NeuralLogger.Level
    let category: String
    let message: String
    let metadata: [String: Any]
    let file: String
    let function: String
    let line: Int
}

// MARK: - Logger Extensions

extension NeuralLogger {
    
    /// Crée un logger pour une catégorie spécifique
    public static func forCategory(_ category: String) -> NeuralLogger {
        return NeuralLogger(category: category)
    }
    
    /// Logger pour l'extraction PCM
    public static var pcmExtractor: NeuralLogger {
        return forCategory("PCMExtractor")
    }
    
    /// Logger pour l'analyse RMS
    public static var rmsAnalyzer: NeuralLogger {
        return forCategory("RMSAnalyzer")
    }
    
    /// Logger pour la classification audio
    public static var soundClassifier: NeuralLogger {
        return forCategory("SoundClassifier")
    }
    
    /// Logger pour la détection de rythme
    public static var beatDetector: NeuralLogger {
        return forCategory("BeatDetector")
    }
    
    /// Logger pour le moteur de décision
    public static var decisionEngine: NeuralLogger {
        return forCategory("DecisionEngine")
    }
    
    /// Logger pour la construction de composition
    public static var compositionBuilder: NeuralLogger {
        return forCategory("CompositionBuilder")
    }
    
    /// Logger pour l'analyse Vision
    public static var visionAnalyzer: NeuralLogger {
        return forCategory("VisionAnalyzer")
    }
}

// MARK: - Performance Measurement

/// Utilitaire pour mesurer les performances
public struct PerformanceMeasurement {
    private let logger: NeuralLogger
    private let operation: String
    private let startTime: Date
    private var metadata: [String: Any]
    
    public init(logger: NeuralLogger, operation: String, metadata: [String: Any] = [:]) {
        self.logger = logger
        self.operation = operation
        self.startTime = Date()
        self.metadata = metadata
        
        logger.debug("Début: \(operation)", metadata: metadata)
    }
    
    public mutating func addMetadata(_ key: String, _ value: Any) {
        metadata[key] = value
    }
    
    public func finish(additionalMetadata: [String: Any] = [:]) {
        let duration = Date().timeIntervalSince(startTime)
        var finalMetadata = metadata
        finalMetadata.merge(additionalMetadata) { _, new in new }
        
        logger.performance(operation, duration: duration, metadata: finalMetadata)
    }
}

// MARK: - Memory Tracking

/// Utilitaire pour tracker l'utilisation mémoire
public struct MemoryTracker {
    private let logger: NeuralLogger
    private let operation: String
    private let initialMemory: Int64
    
    public init(logger: NeuralLogger, operation: String) {
        self.logger = logger
        self.operation = operation
        self.initialMemory = Self.getCurrentMemoryUsage()
        
        logger.debug("Début tracking mémoire: \(operation)", metadata: [
            "initial_memory_mb": initialMemory / (1024 * 1024)
        ])
    }
    
    public func checkpoint(_ name: String) {
        let currentMemory = Self.getCurrentMemoryUsage()
        let delta = currentMemory - initialMemory
        
        logger.memory("\(operation) - \(name)", memoryUsage: currentMemory, metadata: [
            "delta_mb": delta / (1024 * 1024),
            "checkpoint": name
        ])
    }
    
    public func finish() {
        let finalMemory = Self.getCurrentMemoryUsage()
        let delta = finalMemory - initialMemory
        
        logger.memory("\(operation) - Terminé", memoryUsage: finalMemory, metadata: [
            "total_delta_mb": delta / (1024 * 1024),
            "final_memory_mb": finalMemory / (1024 * 1024)
        ])
    }
    
    private static func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - C Imports for Memory Tracking
import Darwin.Mach