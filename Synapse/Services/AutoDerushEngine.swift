import Foundation
import AVFoundation
import CoreMedia
import Accelerate

@available(macOS 14.0, *)
@MainActor
class AutoDerushEngine: ObservableObject {
    
    // MARK: - Configuration
    @Published var isProcessing: Bool = false
    @Published var progress: Float = 0.0
    @Published var currentTask: String = ""
    
    // MARK: - Dérush Parameters
    enum DerushSpeed: String, CaseIterable {
        case fast = "Rapide"
        case medium = "Moyen" 
        case slow = "Lent"
        
        var cutInterval: TimeInterval {
            switch self {
            case .fast: return 0.3    // Coupe après 0.3s de silence
            case .medium: return 0.8  // Coupe après 0.8s de silence
            case .slow: return 1.5    // Coupe après 1.5s de silence
            }
        }
        
        var description: String {
            switch self {
            case .fast: return "Coupe rapide des silences (0.3s)"
            case .medium: return "Coupe modérée des silences (0.8s)"
            case .slow: return "Coupe lente des silences (1.5s)"
            }
        }
    }
    
    // MARK: - Audio Analysis Parameters
    private let silenceThreshold: Float = -40.0  // dB
    private let speechThreshold: Float = -25.0   // dB
    private let windowSize: Int = 1024
    private let hopSize: Int = 512
    private let sampleRate: Double = 44100
    
    // MARK: - Main Dérush Method
    func performAutoDerush(
        videoURL: URL,
        speed: DerushSpeed,
        preserveMinDuration: TimeInterval = 0.5
    ) async throws -> DerushResult {
        
        isProcessing = true
        progress = 0.0
        currentTask = "Analyse audio de la vidéo..."
        
        // Isolation des tâches lourdes pour ne pas bloquer l'UI
        let result = try await Task.detached(priority: .userInitiated) {
            // 1. Extraction et analyse audio
            let audioAnalysis = try await self.analyzeVideoAudioIsolated(videoURL)
            
            await MainActor.run {
                self.progress = 0.3
                self.currentTask = "Détection des zones de parole..."
            }
            
            // 2. Détection des segments de parole et silences
            let speechSegments = self.detectSpeechSegmentsIsolated(audioAnalysis, speed: speed)
            
            await MainActor.run {
                self.progress = 0.6
                self.currentTask = "Génération des points de coupe..."
            }
            
            // 3. Génération des coupes basées sur les silences
            let cutPoints = self.generateCutPointsIsolated(
                speechSegments: speechSegments,
                speed: speed,
                minDuration: preserveMinDuration
            )
            
            await MainActor.run {
                self.progress = 0.8
                self.currentTask = "Création de la timeline dérushée..."
            }
            
            // 4. Création des segments vidéo dérushés
            let derushSegments = try await self.createDerushSegmentsIsolated(
                videoURL: videoURL,
                cutPoints: cutPoints
            )
            
            await MainActor.run {
                self.currentTask = "Finalisation..."
            }
            
            // 5. Calcul des statistiques
            let originalDuration = try await self.getVideoDurationIsolated(videoURL)
            let derushDuration = derushSegments.reduce(0) { $0 + $1.duration }
            let compressionRatio = derushDuration / originalDuration
            
            // 6. Sous-échantillonnage audio pour waveform (1 point tous les 100 samples)
            let audioSamples = audioAnalysis.samples.enumerated()
                .compactMap { index, sample in index % 100 == 0 ? sample : nil }
            
            // 7. Création composition preview (segments conservés uniquement)
            let previewComp = try? await self.createPreviewComposition(
                videoURL: videoURL,
                derushSegments: derushSegments
            )
            
            return DerushResult(
                originalURL: videoURL,
                derushSegments: derushSegments,
                cutPoints: cutPoints,
                speechSegments: speechSegments,
                originalDuration: originalDuration,
                derushDuration: derushDuration,
                compressionRatio: compressionRatio,
                speed: speed,
                segmentsRemoved: cutPoints.count,
                silenceRemoved: originalDuration - derushDuration,
                audioSamples: audioSamples,
                previewComposition: previewComp
            )
        }.value
        
        isProcessing = false
        progress = 1.0
        
        return result
    }
    
    // MARK: - Isolated Analysis Methods (sans @MainActor)
    
    private nonisolated func analyzeVideoAudioIsolated(_ videoURL: URL) async throws -> AudioAnalysisData {
        return try await analyzeVideoAudio(videoURL)
    }
    
    private nonisolated func detectSpeechSegmentsIsolated(
        _ audioData: AudioAnalysisData,
        speed: DerushSpeed
    ) -> [SpeechSegment] {
        return detectSpeechSegments(audioData, speed: speed)
    }
    
    private nonisolated func generateCutPointsIsolated(
        speechSegments: [SpeechSegment],
        speed: DerushSpeed,
        minDuration: TimeInterval
    ) -> [DerushCutPoint] {
        return generateCutPoints(speechSegments: speechSegments, speed: speed, minDuration: minDuration)
    }
    
    private nonisolated func createDerushSegmentsIsolated(
        videoURL: URL,
        cutPoints: [DerushCutPoint]
    ) async throws -> [DerushSegment] {
        return try await createDerushSegments(videoURL: videoURL, cutPoints: cutPoints)
    }
    
    private nonisolated func getVideoDurationIsolated(_ videoURL: URL) async throws -> TimeInterval {
        return try await getVideoDuration(videoURL)
    }
    
    // MARK: - Audio Analysis
    private nonisolated func analyzeVideoAudio(_ videoURL: URL) async throws -> AudioAnalysisData {
        let asset = AVAsset(url: videoURL)
        
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw DerushError.noAudioTrack
        }
        
        let reader = try AVAssetReader(asset: asset)
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(readerOutput)
        
        guard reader.startReading() else {
            throw DerushError.audioReadFailed
        }
        
        var audioSamples: [Float] = []
        var timeStamps: [TimeInterval] = []
        var currentTime: TimeInterval = 0
        
        while reader.status == .reading {
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else { break }
            
            let samples = extractFloatSamples(from: sampleBuffer)
            audioSamples.append(contentsOf: samples)
            
            // Calcul des timestamps
            _ = Double(samples.count) / sampleRate
            for _ in samples {
                timeStamps.append(currentTime)
                currentTime += 1.0 / sampleRate
            }
            
            CMSampleBufferInvalidate(sampleBuffer)
        }
        
        return AudioAnalysisData(
            samples: audioSamples,
            timeStamps: timeStamps,
            sampleRate: sampleRate,
            duration: currentTime
        )
    }
    
    // MARK: - Speech Detection
    private nonisolated func detectSpeechSegments(
        _ audioData: AudioAnalysisData,
        speed: DerushSpeed
    ) -> [SpeechSegment] {
        
        var segments: [SpeechSegment] = []
        let windowSamples = Int(sampleRate * 0.1) // 100ms windows
        
        var currentSegment: SpeechSegment?
        
        for i in stride(from: 0, to: audioData.samples.count, by: windowSamples) {
            let endIndex = min(i + windowSamples, audioData.samples.count)
            let windowData = Array(audioData.samples[i..<endIndex])
            
            // Calcul du niveau RMS en dB
            let rms = calculateRMS(windowData)
            let dbLevel = 20 * log10(max(rms, 1e-10))
            
            let timestamp = audioData.timeStamps[i]
            let isSpeech = dbLevel > silenceThreshold
            
            if isSpeech {
                // Début ou continuation de parole
                if var segment = currentSegment {
                    segment.endTime = timestamp + 0.1
                    currentSegment = segment
                } else {
                    currentSegment = SpeechSegment(
                        startTime: timestamp,
                        endTime: timestamp + 0.1,
                        averageLevel: dbLevel,
                        confidence: calculateSpeechConfidence(dbLevel)
                    )
                }
            } else {
                // Silence détecté
                if let segment = currentSegment {
                    // Fin du segment de parole
                    segments.append(segment)
                    currentSegment = nil
                }
            }
        }
        
        // Ajouter le dernier segment si nécessaire
        if let segment = currentSegment {
            segments.append(segment)
        }
        
        // Filtrage des segments trop courts
        return segments.filter { $0.duration >= 0.2 } // Minimum 200ms
    }
    
    // MARK: - Cut Point Generation
    private nonisolated func generateCutPoints(
        speechSegments: [SpeechSegment],
        speed: DerushSpeed,
        minDuration: TimeInterval
    ) -> [DerushCutPoint] {
        
        var cutPoints: [DerushCutPoint] = []
        let cutInterval = speed.cutInterval
        
        for i in 0..<(speechSegments.count - 1) {
            let currentSegment = speechSegments[i]
            let nextSegment = speechSegments[i + 1]
            
            let silenceStart = currentSegment.endTime
            let silenceEnd = nextSegment.startTime
            let silenceDuration = silenceEnd - silenceStart
            
            // Si le silence est assez long pour être coupé
            if silenceDuration > cutInterval {
                let cutStart = silenceStart + 0.1 // Garde 100ms après la parole
                let cutEnd = silenceEnd - 0.1     // Garde 100ms avant la parole
                let cutDuration = cutEnd - cutStart
                
                if cutDuration > 0.1 { // Minimum 100ms à couper
                    cutPoints.append(DerushCutPoint(
                        startTime: cutStart,
                        endTime: cutEnd,
                        duration: cutDuration,
                        reason: "Silence de \(String(format: "%.1f", silenceDuration))s",
                        silenceLevel: calculateAverageSilenceLevel(
                            start: silenceStart,
                            end: silenceEnd
                        )
                    ))
                }
            }
        }
        
        return cutPoints
    }
    
    // MARK: - Segment Creation
    private nonisolated func createDerushSegments(
        videoURL: URL,
        cutPoints: [DerushCutPoint]
    ) async throws -> [DerushSegment] {
        
        let totalDuration = try await getVideoDuration(videoURL)
        var segments: [DerushSegment] = []
        var currentTime: TimeInterval = 0
        
        // Tri des points de coupe par temps
        let sortedCuts = cutPoints.sorted { $0.startTime < $1.startTime }
        
        for (_, cutPoint) in sortedCuts.enumerated() {
            // Segment avant la coupe
            if cutPoint.startTime > currentTime {
                let segmentDuration = cutPoint.startTime - currentTime
                
                segments.append(DerushSegment(
                    id: UUID(),
                    originalStartTime: currentTime,
                    originalEndTime: cutPoint.startTime,
                    duration: segmentDuration,
                    timelinePosition: segments.reduce(0) { $0 + $1.duration },
                    type: .kept,
                    sourceURL: videoURL
                ))
            }
            
            // Segment coupé (pour référence)
            segments.append(DerushSegment(
                id: UUID(),
                originalStartTime: cutPoint.startTime,
                originalEndTime: cutPoint.endTime,
                duration: cutPoint.duration,
                timelinePosition: -1, // Pas dans la timeline finale
                type: .removed,
                sourceURL: videoURL,
                removalReason: cutPoint.reason
            ))
            
            currentTime = cutPoint.endTime
        }
        
        // Segment final après la dernière coupe
        if currentTime < totalDuration {
            let segmentDuration = totalDuration - currentTime
            
            segments.append(DerushSegment(
                id: UUID(),
                originalStartTime: currentTime,
                originalEndTime: totalDuration,
                duration: segmentDuration,
                timelinePosition: segments.filter { $0.type == .kept }.reduce(0) { $0 + $1.duration },
                type: .kept,
                sourceURL: videoURL
            ))
        }
        
        return segments
    }
    
    // MARK: - Export Functions
    func exportToFCPXML(_ result: DerushResult, outputURL: URL) async throws {
        let keptSegments = result.derushSegments.filter { $0.type == .kept }
        
        let fcpxml = generateFCPXML(
            segments: keptSegments,
            originalURL: result.originalURL,
            projectName: "Synapse Auto-Dérush"
        )
        
        try fcpxml.write(to: outputURL, atomically: true, encoding: .utf8)
    }
    
    func exportDerushVideo(_ result: DerushResult, outputURL: URL) async throws {
        currentTask = "Export de la vidéo dérushée..."
        isProcessing = true
        
        try await Task.detached(priority: .userInitiated) {
            let keptSegments = result.derushSegments.filter { $0.type == .kept }
            
            // Création de la composition vidéo
            let composition = AVMutableComposition()
            
            guard let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw DerushError.exportFailed
            }
            
            guard let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw DerushError.exportFailed
            }
            
            let asset = AVAsset(url: result.originalURL)
            guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
                  let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                throw DerushError.exportFailed
            }
            
            var insertTime = CMTime.zero
            
            for segment in keptSegments {
                let startTime = CMTime(seconds: segment.originalStartTime, preferredTimescale: 600)
                let duration = CMTime(seconds: segment.duration, preferredTimescale: 600)
                let timeRange = CMTimeRangeMake(start: startTime, duration: duration)
                
                try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: insertTime)
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: insertTime)
                
                insertTime = CMTimeAdd(insertTime, duration)
            }
            
            // Export
            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw DerushError.exportFailed
            }
            
            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mp4
            
            await exportSession.export()
            
            if exportSession.status != .completed {
                throw DerushError.exportFailed
            }
        }.value
        
        isProcessing = false
    }
    
    // MARK: - Helper Methods
    private nonisolated func extractFloatSamples(from sampleBuffer: CMSampleBuffer) -> [Float] {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return [] }
        
        let length = CMBlockBufferGetDataLength(blockBuffer)
        let sampleCount = length / MemoryLayout<Int16>.size
        
        var int16Samples = Array<Int16>(repeating: 0, count: sampleCount)
        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &int16Samples)
        
        // Conversion Int16 vers Float
        return int16Samples.map { Float($0) / Float(Int16.max) }
    }
    
    private nonisolated func calculateRMS(_ samples: [Float]) -> Float {
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }
    
    private nonisolated func calculateSpeechConfidence(_ dbLevel: Float) -> Float {
        // Confiance basée sur le niveau audio
        let normalizedLevel = max(0, min(1, (dbLevel - silenceThreshold) / (speechThreshold - silenceThreshold)))
        return normalizedLevel
    }
    
    private nonisolated func calculateAverageSilenceLevel(start: TimeInterval, end: TimeInterval) -> Float {
        // Simulation du niveau de silence moyen
        return Float.random(in: -50.0...(-40.0))
    }
    
    private nonisolated func getVideoDuration(_ url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
    
    private nonisolated func generateFCPXML(segments: [DerushSegment], originalURL: URL, projectName: String) -> String {
        _ = "25"
        let timecode = "00:00:00:00"
        
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE fcpxml>
        <fcpxml version="1.10">
            <resources>
                <format id="r1" name="FFVideoFormat1080p25" frameDuration="100/2500s" width="1920" height="1080"/>
                <asset id="r2" name="\(originalURL.lastPathComponent)" uid="\(UUID().uuidString)" start="0s" duration="\(segments.reduce(0) { $0 + $1.duration })s" hasVideo="1" hasAudio="1">
                    <media-rep kind="original-media" src="\(originalURL.path)"/>
                </asset>
            </resources>
            <library>
                <event name="Synapse Auto-Dérush">
                    <project name="\(projectName)">
                        <sequence format="r1" tcStart="\(timecode)" tcFormat="NDF" audioLayout="stereo" audioRate="48k">
                            <spine>
        """
        
        var currentTime: TimeInterval = 0
        
        for segment in segments {
            let startTime = formatTime(segment.originalStartTime)
            let duration = formatTime(segment.duration)
            let offset = formatTime(currentTime)
            
            xml += """
                                <asset-clip ref="r2" offset="\(offset)" name="\(originalURL.lastPathComponent)" start="\(startTime)" duration="\(duration)"/>
            """
            
            currentTime += segment.duration
        }
        
        xml += """
                            </spine>
                        </sequence>
                    </project>
                </event>
            </library>
        </fcpxml>
        """
        
        return xml
    }
    
    private nonisolated func formatTime(_ seconds: TimeInterval) -> String {
        return "\(Int(seconds * 2500))/2500s"
    }
    
    // MARK: - Preview Composition
    private nonisolated func createPreviewComposition(
        videoURL: URL,
        derushSegments: [DerushSegment]
    ) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw DerushError.exportFailed
        }
        
        let asset = AVAsset(url: videoURL)
        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let sourceAudioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw DerushError.noAudioTrack
        }
        
        var currentTime = CMTime.zero
        
        for segment in derushSegments where segment.type == .kept {
            let startTime = CMTime(seconds: segment.originalStartTime, preferredTimescale: 600)
            let duration = CMTime(seconds: segment.duration, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, duration: duration)
            
            try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)
            try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        return composition
    }
}

// MARK: - Supporting Types
struct AudioAnalysisData {
    let samples: [Float]
    let timeStamps: [TimeInterval]
    let sampleRate: Double
    let duration: TimeInterval
}

struct SpeechSegment {
    let startTime: TimeInterval
    var endTime: TimeInterval
    let averageLevel: Float
    let confidence: Float
    
    var duration: TimeInterval {
        endTime - startTime
    }
}

struct DerushCutPoint {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let duration: TimeInterval
    let reason: String
    let silenceLevel: Float
}

struct DerushSegment: Equatable {
    let id: UUID
    let originalStartTime: TimeInterval
    let originalEndTime: TimeInterval
    let duration: TimeInterval
    let timelinePosition: TimeInterval // -1 si segment supprimé
    let type: SegmentType
    let sourceURL: URL
    var removalReason: String?
    
    enum SegmentType: Equatable {
        case kept    // Segment conservé
        case removed // Segment supprimé
    }
}

struct DerushResult: Equatable {
    let originalURL: URL
    let derushSegments: [DerushSegment]
    let cutPoints: [DerushCutPoint]
    let speechSegments: [SpeechSegment]
    let originalDuration: TimeInterval
    let derushDuration: TimeInterval
    let compressionRatio: TimeInterval
    let speed: AutoDerushEngine.DerushSpeed
    let segmentsRemoved: Int
    let silenceRemoved: TimeInterval
    let audioSamples: [Float]
    let previewComposition: AVMutableComposition?
    
    static func == (lhs: DerushResult, rhs: DerushResult) -> Bool {
        lhs.originalURL == rhs.originalURL &&
        lhs.derushSegments.count == rhs.derushSegments.count &&
        lhs.originalDuration == rhs.originalDuration
    }
}

enum DerushError: Error {
    case noAudioTrack
    case audioReadFailed
    case exportFailed
    
    var localizedDescription: String {
        switch self {
        case .noAudioTrack:
            return "Aucune piste audio trouvée dans la vidéo"
        case .audioReadFailed:
            return "Échec de la lecture audio"
        case .exportFailed:
            return "Échec de l'export"
        }
    }
}