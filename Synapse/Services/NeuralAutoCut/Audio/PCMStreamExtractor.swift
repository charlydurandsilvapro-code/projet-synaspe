import Foundation
import AVFoundation
import CoreMedia

// MARK: - PCM Stream Extractor

/// Extracteur de flux PCM optimisé pour le traitement en streaming
@available(macOS 14.0, *)
actor PCMStreamExtractor {
    
    // MARK: - Properties
    private let logger = NeuralLogger.pcmExtractor
    private let configuration: ProcessingConfiguration
    
    // MARK: - Extraction State
    private var isExtracting: Bool = false
    private var extractionTask: Task<Void, Never>?
    private var assetReader: AVAssetReader?
    private var audioOutput: AVAssetReaderAudioMixOutput?
    
    // MARK: - Performance Tracking
    private var extractionStartTime: Date?
    private var buffersExtracted: Int = 0
    private var totalSamplesProcessed: Int64 = 0
    
    // MARK: - Initialization
    
    init(configuration: ProcessingConfiguration) {
        self.configuration = configuration
        
        logger.info("PCMStreamExtractor initialisé", metadata: [
            "buffer_size": configuration.bufferSize,
            "enable_optimizations": configuration.enableAppleSiliconOptimizations
        ])
    }
    
    deinit {
        // Le cleanup sera fait automatiquement par l'actor lors de la déallocation
    }
    
    // MARK: - Public Interface
    
    /// Extrait le flux audio d'un asset sous forme de stream AsyncThrowingStream
    func extractAudioStream(from asset: AVAsset) -> AsyncThrowingStream<AudioBuffer, Error> {
        return AsyncThrowingStream { continuation in
            extractionTask = Task {
                do {
                    try await performExtraction(asset: asset, continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Annule l'extraction en cours
    func cancelExtraction() {
        extractionTask?.cancel()
        extractionTask = nil
        
        assetReader?.cancelReading()
        cleanup()
        
        isExtracting = false
        logger.info("Extraction PCM annulée")
    }
    
    /// Obtient les statistiques d'extraction actuelles
    var extractionStatistics: ExtractionStatistics {
        get async {
            let processingTime = extractionStartTime.map { Date().timeIntervalSince($0) } ?? 0
            
            return ExtractionStatistics(
                isExtracting: isExtracting,
                buffersExtracted: buffersExtracted,
                totalSamplesProcessed: totalSamplesProcessed,
                processingTime: processingTime,
                samplesPerSecond: processingTime > 0 ? Float(totalSamplesProcessed) / Float(processingTime) : 0
            )
        }
    }
    
    // MARK: - Private Implementation
    
    private func performExtraction(
        asset: AVAsset,
        continuation: AsyncThrowingStream<AudioBuffer, Error>.Continuation
    ) async throws {
        
        guard !isExtracting else {
            throw NeuralAutoCutError.processingInProgress
        }
        
        isExtracting = true
        extractionStartTime = Date()
        buffersExtracted = 0
        totalSamplesProcessed = 0
        
        defer {
            isExtracting = false
            cleanup()
        }
        
        logger.info("Début extraction PCM", metadata: [
            "asset": asset.description
        ])
        
        do {
            // Configuration de l'asset reader
            try await setupAssetReader(asset: asset)
            
            // Démarrage de la lecture
            guard let reader = assetReader, reader.startReading() else {
                throw NeuralAutoCutError.audioExtractionFailed("Impossible de démarrer la lecture de l'asset")
            }
            
            // Extraction des buffers
            try await extractBuffers(continuation: continuation)
            
            continuation.finish()
            
            let processingTime = Date().timeIntervalSince(extractionStartTime!)
            
            logger.info("Extraction PCM terminée", metadata: [
                "buffers_extracted": buffersExtracted,
                "total_samples": totalSamplesProcessed,
                "processing_time": processingTime,
                "samples_per_second": Float(totalSamplesProcessed) / Float(processingTime)
            ])
            
        } catch {
            logger.error("Erreur extraction PCM", metadata: [
                "error": error.localizedDescription,
                "buffers_extracted": buffersExtracted
            ])
            continuation.finish(throwing: error)
        }
    }
    
    private func setupAssetReader(asset: AVAsset) async throws {
        // Chargement des pistes audio
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NeuralAutoCutError.noAudioTrack
        }
        
        // Création de l'asset reader
        assetReader = try AVAssetReader(asset: asset)
        
        // Configuration du format audio de sortie (PCM Linear 32-bit float)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1 // Mono pour simplifier l'analyse
        ]
        
        // Création de l'output audio
        audioOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: outputSettings)
        audioOutput?.alwaysCopiesSampleData = false // Optimisation mémoire
        
        // Ajout de l'output au reader
        guard let output = audioOutput,
              let reader = assetReader,
              reader.canAdd(output) else {
            throw NeuralAutoCutError.audioExtractionFailed("Impossible de configurer l'output audio")
        }
        
        reader.add(output)
        
        logger.debug("Asset reader configuré", metadata: [
            "audio_tracks": audioTracks.count,
            "output_settings": outputSettings.description
        ])
    }
    
    private func extractBuffers(
        continuation: AsyncThrowingStream<AudioBuffer, Error>.Continuation
    ) async throws {
        
        guard let reader = assetReader,
              let output = audioOutput else {
            throw NeuralAutoCutError.audioExtractionFailed("Asset reader non configuré")
        }
        
        while reader.status == .reading {
            // Vérification d'annulation
            if Task.isCancelled {
                throw NeuralAutoCutError.processingCancelled
            }
            
            // Lecture du prochain sample buffer
            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                break // Fin du stream
            }
            
            do {
                // Conversion en AudioBuffer
                let audioBuffer = try createAudioBuffer(from: sampleBuffer)
                
                // Envoi du buffer via le stream
                continuation.yield(audioBuffer)
                
                // Mise à jour des statistiques
                buffersExtracted += 1
                totalSamplesProcessed += Int64(audioBuffer.frameCount)
                
                logger.debug("Buffer extrait", metadata: [
                    "buffer_index": buffersExtracted,
                    "frame_count": audioBuffer.frameCount,
                    "timestamp": audioBuffer.timestamp.seconds
                ])
                
            } catch {
                logger.warning("Erreur traitement buffer", metadata: [
                    "buffer_index": buffersExtracted,
                    "error": error.localizedDescription
                ])
            }
            
            // Libération du sample buffer
            CMSampleBufferInvalidate(sampleBuffer)
        }
        
        // Vérification du statut final
        if reader.status == .failed, let error = reader.error {
            throw NeuralAutoCutError.audioExtractionFailed("Erreur de lecture : \(error.localizedDescription)")
        }
    }
    
    private func createAudioBuffer(from sampleBuffer: CMSampleBuffer) throws -> AudioBuffer {
        // Extraction du block buffer audio
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw NeuralAutoCutError.bufferAllocationFailed
        }
        
        // Obtention des informations de format
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            throw NeuralAutoCutError.audioExtractionFailed("Format description manquant")
        }
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        guard let asbd = audioStreamBasicDescription else {
            throw NeuralAutoCutError.audioExtractionFailed("Stream basic description manquant")
        }
        
        // Calcul des paramètres
        let sampleRate = asbd.pointee.mSampleRate
        let channelCount = Int(asbd.pointee.mChannelsPerFrame)
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        
        // Extraction des données PCM
        var dataPointer: UnsafeMutablePointer<Int8>?
        var dataSize: Int = 0
        
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &dataSize,
            dataPointerOut: &dataPointer
        )
        
        guard status == noErr, let data = dataPointer else {
            throw NeuralAutoCutError.bufferAllocationFailed
        }
        
        // Création du buffer pointer pour les données Float
        let floatData = data.withMemoryRebound(to: Float.self, capacity: dataSize / MemoryLayout<Float>.size) { pointer in
            UnsafeBufferPointer(start: pointer, count: frameCount)
        }
        
        // Timestamp du buffer
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        return AudioBuffer(
            data: floatData,
            frameCount: frameCount,
            timestamp: presentationTime,
            sampleRate: sampleRate,
            channelCount: channelCount
        )
    }
    
    private func cleanup() {
        assetReader?.cancelReading()
        assetReader = nil
        audioOutput = nil
        
        logger.debug("PCMStreamExtractor nettoyé")
    }
}

// MARK: - Supporting Types

/// Statistiques d'extraction PCM
public struct ExtractionStatistics {
    public let isExtracting: Bool
    public let buffersExtracted: Int
    public let totalSamplesProcessed: Int64
    public let processingTime: TimeInterval
    public let samplesPerSecond: Float
    
    public var megaSamplesPerSecond: Float {
        return samplesPerSecond / 1_000_000
    }
    
    public var status: String {
        return isExtracting ? "Extraction en cours" : "Inactif"
    }
    
    public var efficiency: String {
        let msps = megaSamplesPerSecond
        switch msps {
        case 10...: return "Très rapide"
        case 5..<10: return "Rapide"
        case 1..<5: return "Modéré"
        default: return "Lent"
        }
    }
}

// MARK: - Extensions

extension PCMStreamExtractor {
    
    /// Extrait un échantillon rapide pour les tests
    func extractSample(from asset: AVAsset, duration: TimeInterval = 10.0) -> AsyncThrowingStream<AudioBuffer, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Configuration pour échantillonnage limité
                    let reader = try AVAssetReader(asset: asset)
                    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                    
                    guard let audioTrack = audioTracks.first else {
                        throw NeuralAutoCutError.noAudioTrack
                    }
                    
                    let outputSettings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVLinearPCMBitDepthKey: 32,
                        AVLinearPCMIsFloatKey: true,
                        AVLinearPCMIsBigEndianKey: false,
                        AVLinearPCMIsNonInterleaved: false,
                        AVSampleRateKey: 44100.0,
                        AVNumberOfChannelsKey: 1
                    ]
                    
                    let output = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: outputSettings)
                    
                    // Limitation de la durée
                    let timeRange = CMTimeRange(
                        start: CMTime.zero,
                        duration: CMTime(seconds: duration, preferredTimescale: 600)
                    )
                    output.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithm.spectral
                    reader.timeRange = timeRange
                    
                    reader.add(output)
                    
                    guard reader.startReading() else {
                        throw NeuralAutoCutError.audioExtractionFailed("Impossible de démarrer l'échantillonnage")
                    }
                    
                    var bufferCount = 0
                    let maxBuffers = Int(duration * 44100 / Double(configuration.bufferSize))
                    
                    while reader.status == .reading && bufferCount < maxBuffers {
                        guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
                        
                        let audioBuffer = try createAudioBuffer(from: sampleBuffer)
                        continuation.yield(audioBuffer)
                        
                        bufferCount += 1
                        CMSampleBufferInvalidate(sampleBuffer)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}