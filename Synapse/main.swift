import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.0, *)
struct SynapseApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

@available(macOS 14.0, *)
struct ContentView: View {
    @StateObject private var viewModel = ProjectViewModel()
    @State private var showingExportDialog = false
    @State private var selectedTab: MainTab = .timeline
    
    enum MainTab: String, CaseIterable {
        case timeline = "Timeline"
        case effects = "Effets"
        case audio = "Audio"
        case export = "Export"
        
        var icon: String {
            switch self {
            case .timeline: return "timeline.selection"
            case .effects: return "wand.and.stars"
            case .audio: return "waveform"
            case .export: return "square.and.arrow.up"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.12, green: 0.12, blue: 0.13)
                .ignoresSafeArea()
            
            if viewModel.isProcessing {
                ProcessingView(status: viewModel.processingStatus)
            } else if viewModel.project.timeline.isEmpty {
                WelcomeView(viewModel: viewModel)
            } else {
                ProfessionalWorkspaceView(viewModel: viewModel, selectedTab: $selectedTab)
            }
        }
        .preferredColorScheme(.dark)
        .fileExporter(
            isPresented: $showingExportDialog,
            document: TextDocument(text: ""),
            contentType: .mpeg4Movie,
            defaultFilename: "synapse_export.mp4"
        ) { result in
            switch result {
            case .success(let url):
                Task {
                    await viewModel.exportProject(to: url)
                }
            case .failure(let error):
                print("Export failed: \(error)")
            }
        }
    }
}

// MARK: - Welcome View
@available(macOS 14.0, *)
struct WelcomeView: View {
    @ObservedObject var viewModel: ProjectViewModel
    @State private var isDragging = false
    @State private var showingVideoPicker = false
    @State private var showingAudioPicker = false
    
    var body: some View {
        ZStack {
            // Animated Background
            AnimatedBackgroundView()
            
            VStack(spacing: 40) {
                // Hero Section
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Synapse")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Text("Montage Vidéo Alimenté par l'IA")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("Créez de superbes montages vidéo synchronisés à la musique avec une IA avancée")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 600)
                }
                
                // Drop Zone
                VStack(spacing: 24) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        isDragging ? 
                                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [.white.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                                        style: StrokeStyle(lineWidth: 2, dash: isDragging ? [] : [10, 5])
                                    )
                            )
                            .frame(width: 500, height: 200)
                            .scaleEffect(isDragging ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3), value: isDragging)
                        
                        VStack(spacing: 16) {
                            Image(systemName: isDragging ? "arrow.down.circle.fill" : "square.and.arrow.down")
                                .font(.system(size: 50))
                                .foregroundStyle(isDragging ? .purple : .secondary)
                                .animation(.easeInOut(duration: 0.2), value: isDragging)
                            
                            Text(isDragging ? "Déposez vos fichiers ici" : "Glissez & Déposez vos Fichiers Vidéo")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(isDragging ? .purple : .primary)
                            
                            Text("Formats supportés : ProRes, H.264, HEVC, MP4, MOV")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDrop(of: [.movie, .audio], isTargeted: $isDragging) { providers in
                        handleDrop(providers: providers, viewModel: viewModel)
                        return true
                    }
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        ModernActionButton(
                            title: "Choisir Vidéos",
                            icon: "video.badge.plus",
                            color: .blue,
                            action: { showingVideoPicker = true }
                        )
                        
                        ModernActionButton(
                            title: "Choisir Musique",
                            icon: "music.note.list",
                            color: .green,
                            action: { showingAudioPicker = true }
                        )
                    }
                    
                    // Generate Button
                    if !viewModel.videoURLs.isEmpty && viewModel.audioURL != nil {
                        VStack(spacing: 12) {
                            ModernActionButton(
                                title: "Auto-Rush Intelligent",
                                icon: "brain.head.profile",
                                color: .purple,
                                isPrimary: true,
                                action: {
                                    Task {
                                        await viewModel.performIntelligentAutoRush()
                                    }
                                }
                            )
                            .help("Analyse complète et sélection automatique des meilleurs moments")
                            
                            HStack(spacing: 8) {
                                ModernActionButton(
                                    title: "Coupes Intelligentes",
                                    icon: "scissors",
                                    color: .blue,
                                    action: {
                                        Task {
                                            await viewModel.generateSmartCutsOnly()
                                        }
                                    }
                                )
                                .help("Génère des points de coupe synchronisés à la musique")
                                
                                ModernActionButton(
                                    title: "Timeline Classique",
                                    icon: "wand.and.stars",
                                    color: .green,
                                    action: {
                                        Task {
                                            await viewModel.generateTimeline()
                                        }
                                    }
                                )
                                .help("Génération de timeline traditionnelle")
                            }
                        }
                        .scaleEffect(1.05)
                        .animation(.spring(response: 0.5), value: !viewModel.videoURLs.isEmpty && viewModel.audioURL != nil)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingVideoPicker,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await viewModel.addVideos(urls)
                }
            case .failure(let error):
                print("Failed to import videos: \(error)")
            }
        }
        .fileImporter(
            isPresented: $showingAudioPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.addAudio(url)
                    }
                }
            case .failure(let error):
                print("Failed to import audio: \(error)")
            }
        }
    }
}

// MARK: - Professional Workspace
@available(macOS 14.0, *)
struct ProfessionalWorkspaceView: View {
    @ObservedObject var viewModel: ProjectViewModel
    @Binding var selectedTab: ContentView.MainTab
    @State private var showingSidebar = true
    @State private var sidebarWidth: CGFloat = 280
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Sidebar
                if showingSidebar {
                    ModernSidebarView(viewModel: viewModel)
                        .frame(width: sidebarWidth)
                        .background(
                            RoundedRectangle(cornerRadius: 0)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 1)
                                        .offset(x: sidebarWidth/2),
                                    alignment: .trailing
                                )
                        )
                        .transition(.move(edge: .leading))
                }
                
                // Main Content Area
                VStack(spacing: 0) {
                    // Top Toolbar
                    ModernToolbarView(
                        viewModel: viewModel,
                        selectedTab: $selectedTab,
                        showingSidebar: $showingSidebar
                    )
                    .frame(height: 60)
                    .background(.ultraThinMaterial)
                    
                    // Content Area
                    GeometryReader { contentGeometry in
                        VStack(spacing: 0) {
                            // Video Preview Area (60% of height)
                            VideoPreviewArea(viewModel: viewModel)
                                .frame(height: contentGeometry.size.height * 0.6)
                            
                            // Timeline Area (40% of height)
                            ModernTimelineView(viewModel: viewModel)
                                .frame(height: contentGeometry.size.height * 0.4)
                                .background(
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
                                        .overlay(
                                            Rectangle()
                                                .fill(Color.white.opacity(0.1))
                                                .frame(height: 1),
                                            alignment: .top
                                        )
                                )
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSidebar)
    }
}

// MARK: - Processing View
@available(macOS 14.0, *)
struct ProcessingView: View {
    let status: String
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.12, blue: 0.13)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated loading indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(
                            .linear(duration: 1)
                            .repeatForever(autoreverses: false),
                            value: rotationAngle
                        )
                }
                
                VStack(spacing: 12) {
                    Text("Traitement en cours")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            rotationAngle = 360
        }
    }
}

// MARK: - Helper Functions
private func handleDrop(providers: [NSItemProvider], viewModel: ProjectViewModel) {
    for provider in providers {
        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.movie.identifier, options: nil) { data, error in
                if let url = data as? URL {
                    Task {
                        await viewModel.addVideos([url])
                    }
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.audio.identifier, options: nil) { data, error in
                if let url = data as? URL {
                    Task {
                        await viewModel.addAudio(url)
                    }
                }
            }
        }
    }
}

struct TextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    
    init(text: String) {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        text = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data())
    }
}

// Point d'entrée de l'application
if #available(macOS 14.0, *) {
    SynapseApp.main()
}