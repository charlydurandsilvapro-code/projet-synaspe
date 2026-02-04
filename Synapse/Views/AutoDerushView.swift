import SwiftUI
import AVKit

@available(macOS 14.0, *)
struct AutoDerushView: View {
    @StateObject private var derushEngine = AutoDerushEngine()
    @State private var selectedVideoURL: URL?
    @State private var derushResult: DerushResult?
    @State private var selectedSpeed: AutoDerushEngine.DerushSpeed = .medium
    @State private var preserveMinDuration: Double = 0.5
    @State private var showingVideoPicker = false
    @State private var showingExportDialog = false
    @State private var exportType: ExportType = .video
    @State private var playheadPosition: TimeInterval = 0
    @State private var isPlaying = false
    
    enum ExportType {
        case video, fcpxml, timeline
    }
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Contrôles
            DerushSidebarView(
                selectedVideoURL: $selectedVideoURL,
                selectedSpeed: $selectedSpeed,
                preserveMinDuration: $preserveMinDuration,
                showingVideoPicker: $showingVideoPicker,
                onStartDerush: startDerush
            )
            .frame(minWidth: 300)
            
        } detail: {
            // Zone principale - Timeline et prévisualisation
            VStack(spacing: 0) {
                // Header
                DerushHeaderView(
                    derushResult: derushResult,
                    onExport: { type in
                        exportType = type
                        showingExportDialog = true
                    }
                )
                .frame(height: 60)
                .background(.ultraThinMaterial)
                
                if derushEngine.isProcessing {
                    // Vue de traitement
                    DerushProcessingView(
                        engine: derushEngine
                    )
                } else if let result = derushResult {
                    // Vue de résultat avec timeline
                    DerushTimelineView(
                        result: result,
                        playheadPosition: $playheadPosition,
                        isPlaying: $isPlaying
                    )
                } else {
                    // Vue d'accueil
                    DerushWelcomeView(
                        onSelectVideo: { showingVideoPicker = true }
                    )
                }
            }
        }
        .navigationTitle("Auto-Dérush Synapse")
        .fileImporter(
            isPresented: $showingVideoPicker,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedVideoURL = url
                }
            case .failure(let error):
                print("Failed to import video: \(error)")
            }
        }
        .fileExporter(
            isPresented: $showingExportDialog,
            document: createExportDocument(),
            contentType: exportType == .fcpxml ? .xml : .mpeg4Movie,
            defaultFilename: exportType == .fcpxml ? "derush_project.fcpxml" : "derush_video.mp4"
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await handleExport(to: url)
                }
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
    
    private func startDerush() {
        guard let videoURL = selectedVideoURL else { return }
        
        Task {
            do {
                derushResult = try await derushEngine.performAutoDerush(
                    videoURL: videoURL,
                    speed: selectedSpeed,
                    preserveMinDuration: preserveMinDuration
                )
            } catch {
                print("Dérush failed: \(error)")
            }
        }
    }
    
    private func createExportDocument() -> TextDocument {
        return TextDocument(text: "")
    }
    
    private func handleExport(to url: URL) async {
        guard let result = derushResult else { return }
        
        do {
            switch exportType {
            case .video:
                try await derushEngine.exportDerushVideo(result, outputURL: url)
            case .fcpxml:
                try await derushEngine.exportToFCPXML(result, outputURL: url)
            case .timeline:
                // TODO: Export vers timeline IA
                break
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
}

// MARK: - Sidebar
@available(macOS 14.0, *)
struct DerushSidebarView: View {
    @Binding var selectedVideoURL: URL?
    @Binding var selectedSpeed: AutoDerushEngine.DerushSpeed
    @Binding var preserveMinDuration: Double
    @Binding var showingVideoPicker: Bool
    let onStartDerush: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Section Vidéo
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vidéo Source")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let url = selectedVideoURL {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "video")
                                    .foregroundStyle(.blue)
                                Text(url.lastPathComponent)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button("Changer de vidéo") {
                                showingVideoPicker = true
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    } else {
                        Button(action: { showingVideoPicker = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                                Text("Sélectionner une vidéo")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                }
                
                Divider()
                
                // Section Paramètres
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paramètres de Dérush")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    // Vitesse de coupe
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vitesse de Coupe")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Vitesse", selection: $selectedSpeed) {
                            ForEach(AutoDerushEngine.DerushSpeed.allCases, id: \.self) { speed in
                                Text(speed.rawValue).tag(speed)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Text(selectedSpeed.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    
                    // Durée minimale
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Durée Min. Segment")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(preserveMinDuration, specifier: "%.1f")s")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $preserveMinDuration, in: 0.2...2.0, step: 0.1)
                            .accentColor(.purple)
                        
                        Text("Durée minimale des segments conservés")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Section Actions
                VStack(spacing: 12) {
                    Button(action: onStartDerush) {
                        HStack {
                            Image(systemName: "scissors")
                            Text("Démarrer le Dérush")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedVideoURL == nil)
                    
                    Text("Le dérush analysera l'audio pour détecter la parole et supprimer les silences selon vos paramètres.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }
}

// MARK: - Header
@available(macOS 14.0, *)
struct DerushHeaderView: View {
    let derushResult: DerushResult?
    let onExport: (AutoDerushView.ExportType) -> Void
    
    var body: some View {
        HStack {
            // Informations
            if let result = derushResult {
                HStack(spacing: 20) {
                    InfoBadge(
                        label: "Original",
                        value: formatDuration(result.originalDuration),
                        color: .gray
                    )
                    
                    InfoBadge(
                        label: "Dérushé",
                        value: formatDuration(result.derushDuration),
                        color: .green
                    )
                    
                    InfoBadge(
                        label: "Compression",
                        value: "\(Int(result.compressionRatio * 100))%",
                        color: .blue
                    )
                    
                    InfoBadge(
                        label: "Coupes",
                        value: "\(result.segmentsRemoved)",
                        color: .orange
                    )
                }
            } else {
                Text("Auto-Dérush Synapse")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Boutons d'export
            if derushResult != nil {
                HStack(spacing: 8) {
                    Menu {
                        Button("Exporter Vidéo") {
                            onExport(.video)
                        }
                        
                        Button("Exporter FCPXML") {
                            onExport(.fcpxml)
                        }
                        
                        Button("Vers Timeline IA") {
                            onExport(.timeline)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Exporter")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Processing View
@available(macOS 14.0, *)
struct DerushProcessingView: View {
    @ObservedObject var engine: AutoDerushEngine
    
    var body: some View {
        VStack(spacing: 30) {
            // Indicateur de progression
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(engine.progress))
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: engine.progress)
                    
                    Text("\(Int(engine.progress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                
                VStack(spacing: 8) {
                    Text("Dérush en cours")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(engine.currentTask)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Étapes du processus
            VStack(alignment: .leading, spacing: 12) {
                ProcessStep(
                    title: "Analyse audio",
                    isCompleted: engine.progress > 0.3,
                    isCurrent: engine.progress <= 0.3
                )
                
                ProcessStep(
                    title: "Détection de parole",
                    isCompleted: engine.progress > 0.6,
                    isCurrent: engine.progress > 0.3 && engine.progress <= 0.6
                )
                
                ProcessStep(
                    title: "Génération des coupes",
                    isCompleted: engine.progress > 0.8,
                    isCurrent: engine.progress > 0.6 && engine.progress <= 0.8
                )
                
                ProcessStep(
                    title: "Création de la timeline",
                    isCompleted: engine.progress >= 1.0,
                    isCurrent: engine.progress > 0.8 && engine.progress < 1.0
                )
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }
}

// MARK: - Timeline View
@available(macOS 14.0, *)
struct DerushTimelineView: View {
    let result: DerushResult
    @Binding var playheadPosition: TimeInterval
    @Binding var isPlaying: Bool
    @State private var timelineScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Contrôles de lecture
            DerushPlaybackControls(
                result: result,
                playheadPosition: $playheadPosition,
                isPlaying: $isPlaying
            )
            .frame(height: 60)
            .background(.ultraThinMaterial)
            
            // Timeline
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 16) {
                    // Timeline originale
                    DerushTrackView(
                        title: "Original",
                        segments: result.derushSegments,
                        showRemoved: true,
                        scale: timelineScale,
                        playheadPosition: playheadPosition
                    )
                    
                    // Timeline dérushée
                    DerushTrackView(
                        title: "Dérushé",
                        segments: result.derushSegments.filter { $0.type == .kept },
                        showRemoved: false,
                        scale: timelineScale,
                        playheadPosition: playheadPosition
                    )
                }
                .padding()
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.09))
            
            // Contrôles de zoom
            HStack {
                Button(action: { timelineScale = max(0.5, timelineScale - 0.2) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                
                Text("\(Int(timelineScale * 100))%")
                    .frame(width: 50)
                    .font(.caption)
                
                Button(action: { timelineScale = min(3.0, timelineScale + 0.2) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                
                Spacer()
                
                Text("Segments conservés: \(result.derushSegments.filter { $0.type == .kept }.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Helper Views
@available(macOS 14.0, *)
struct InfoBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

@available(macOS 14.0, *)
struct ProcessStep: View {
    let title: String
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? .green : (isCurrent ? .purple : .gray.opacity(0.3)))
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else if isCurrent {
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .fontWeight(isCurrent ? .medium : .regular)
            
            Spacer()
        }
    }
}

@available(macOS 14.0, *)
struct DerushWelcomeView: View {
    let onSelectVideo: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "scissors.badge.ellipsis")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Auto-Dérush Intelligent")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Supprimez automatiquement les silences et gardez uniquement les moments de parole")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }
            
            Button(action: onSelectVideo) {
                HStack {
                    Image(systemName: "video.badge.plus")
                    Text("Sélectionner une Vidéo")
                }
                .font(.title2)
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.13))
    }
}

@available(macOS 14.0, *)
struct DerushPlaybackControls: View {
    let result: DerushResult
    @Binding var playheadPosition: TimeInterval
    @Binding var isPlaying: Bool
    
    var body: some View {
        HStack {
            // Contrôles de lecture
            HStack(spacing: 16) {
                Button(action: { playheadPosition = 0 }) {
                    Image(systemName: "backward.end")
                }
                
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                
                Button(action: { playheadPosition = result.derushDuration }) {
                    Image(systemName: "forward.end")
                }
            }
            
            Spacer()
            
            // Timecode
            Text("\(formatTime(playheadPosition)) / \(formatTime(result.derushDuration))")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

@available(macOS 14.0, *)
struct DerushTrackView: View {
    let title: String
    let segments: [DerushSegment]
    let showRemoved: Bool
    let scale: CGFloat
    let playheadPosition: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 80)
                
                // Segments
                HStack(spacing: 2) {
                    ForEach(segments, id: \.id) { segment in
                        DerushSegmentView(
                            segment: segment,
                            scale: scale,
                            showRemoved: showRemoved
                        )
                    }
                }
                .padding(.horizontal, 4)
                
                // Playhead
                if !showRemoved {
                    Rectangle()
                        .fill(.red)
                        .frame(width: 2, height: 80)
                        .offset(x: CGFloat(playheadPosition * scale * 50))
                }
            }
        }
    }
}

@available(macOS 14.0, *)
struct DerushSegmentView: View {
    let segment: DerushSegment
    let scale: CGFloat
    let showRemoved: Bool
    
    var body: some View {
        let width = CGFloat(segment.duration * scale * 50)
        
        RoundedRectangle(cornerRadius: 4)
            .fill(segmentColor)
            .frame(width: max(width, 2), height: 70)
            .overlay(
                VStack(spacing: 2) {
                    if width > 60 {
                        Text(formatDuration(segment.duration))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                        
                        if segment.type == .removed, let reason = segment.removalReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(4)
            )
            .opacity(segment.type == .removed && !showRemoved ? 0.3 : 1.0)
    }
    
    private var segmentColor: Color {
        switch segment.type {
        case .kept:
            return .green
        case .removed:
            return .red.opacity(0.7)
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        return String(format: "%.1fs", seconds)
    }
}