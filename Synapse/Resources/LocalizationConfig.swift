import Foundation

/// Configuration de localisation pour Synapse
struct LocalizationConfig {
    
    /// Langue actuelle de l'application
    static var currentLanguage: String {
        return Locale.current.language.languageCode?.identifier ?? "fr"
    }
    
    /// Textes localisés pour l'interface
    enum Text {
        
        // MARK: - Application
        static let appName = NSLocalizedString("app.name", value: "Synapse", comment: "Nom de l'application")
        static let appTagline = NSLocalizedString("app.tagline", value: "Montage Vidéo Alimenté par l'IA", comment: "Slogan de l'application")
        static let appDescription = NSLocalizedString("app.description", value: "Créez de superbes montages vidéo synchronisés à la musique avec une IA avancée", comment: "Description de l'application")
        
        // MARK: - Interface Principale
        static let welcomeTitle = NSLocalizedString("welcome.title", value: "Bienvenue dans Synapse", comment: "Titre de bienvenue")
        static let welcomeSubtitle = NSLocalizedString("welcome.subtitle", value: "Votre assistant IA pour le montage vidéo", comment: "Sous-titre de bienvenue")
        static let welcomeDescription = NSLocalizedString("welcome.description", value: "Glissez vos vidéos et votre musique pour commencer", comment: "Description de bienvenue")
        
        // MARK: - Boutons d'Action
        static let chooseVideos = NSLocalizedString("button.choose_videos", value: "Choisir Vidéos", comment: "Bouton choisir vidéos")
        static let chooseMusic = NSLocalizedString("button.choose_music", value: "Choisir Musique", comment: "Bouton choisir musique")
        static let generateTimeline = NSLocalizedString("button.generate_timeline", value: "Générer Timeline", comment: "Bouton générer timeline")
        static let export = NSLocalizedString("button.export", value: "Exporter", comment: "Bouton exporter")
        static let preview = NSLocalizedString("button.preview", value: "Aperçu", comment: "Bouton aperçu")
        static let play = NSLocalizedString("button.play", value: "Lecture", comment: "Bouton lecture")
        static let pause = NSLocalizedString("button.pause", value: "Pause", comment: "Bouton pause")
        
        // MARK: - Sidebar
        static let sidebarProject = NSLocalizedString("sidebar.project", value: "Projet", comment: "Section projet")
        static let sidebarMedia = NSLocalizedString("sidebar.media", value: "Médias", comment: "Section médias")
        static let sidebarEffects = NSLocalizedString("sidebar.effects", value: "Effets", comment: "Section effets")
        static let sidebarSettings = NSLocalizedString("sidebar.settings", value: "Réglages", comment: "Section réglages")
        
        // MARK: - Statistiques
        static let statsSegments = NSLocalizedString("stats.segments", value: "Segments", comment: "Statistique segments")
        static let statsDuration = NSLocalizedString("stats.duration", value: "Durée", comment: "Statistique durée")
        static let statsQuality = NSLocalizedString("stats.quality", value: "Qualité", comment: "Statistique qualité")
        
        // MARK: - Actions Rapides
        static let quickActionsTitle = NSLocalizedString("quick_actions.title", value: "Actions Rapides", comment: "Titre actions rapides")
        static let autoFill = NSLocalizedString("quick_actions.auto_fill", value: "Remplissage Auto", comment: "Action remplissage automatique")
        static let optimize = NSLocalizedString("quick_actions.optimize", value: "Optimiser Plateforme", comment: "Action optimiser")
        static let refresh = NSLocalizedString("quick_actions.refresh", value: "Actualiser Vignettes", comment: "Action actualiser")
        
        // MARK: - Profils Couleur
        static let colorProfileTitle = NSLocalizedString("color_profile.title", value: "Profil Couleur", comment: "Titre profil couleur")
        static let cinematic = NSLocalizedString("color_profile.cinematic", value: "Cinématique", comment: "Profil cinématique")
        static let cinematicDesc = NSLocalizedString("color_profile.cinematic.desc", value: "Tons chauds, aspect film", comment: "Description cinématique")
        static let vivid = NSLocalizedString("color_profile.vivid", value: "Vif", comment: "Profil vif")
        static let vividDesc = NSLocalizedString("color_profile.vivid.desc", value: "Couleurs rehaussées", comment: "Description vif")
        static let blackWhite = NSLocalizedString("color_profile.bw", value: "N&B", comment: "Profil noir et blanc")
        static let blackWhiteDesc = NSLocalizedString("color_profile.bw.desc", value: "Monochrome classique", comment: "Description noir et blanc")
        
        // MARK: - Ratios d'Aspect
        static let aspectRatioTitle = NSLocalizedString("aspect_ratio.title", value: "Ratio d'Aspect", comment: "Titre ratio d'aspect")
        static let portrait = NSLocalizedString("aspect_ratio.portrait", value: "9:16 Portrait", comment: "Ratio portrait")
        static let portraitDesc = NSLocalizedString("aspect_ratio.portrait.desc", value: "TikTok, Instagram", comment: "Description portrait")
        static let landscape = NSLocalizedString("aspect_ratio.landscape", value: "16:9 Paysage", comment: "Ratio paysage")
        static let landscapeDesc = NSLocalizedString("aspect_ratio.landscape.desc", value: "YouTube, Desktop", comment: "Description paysage")
        static let square = NSLocalizedString("aspect_ratio.square", value: "1:1 Carré", comment: "Ratio carré")
        static let squareDesc = NSLocalizedString("aspect_ratio.square.desc", value: "Post Instagram", comment: "Description carré")
        
        // MARK: - IA
        static let aiTitle = NSLocalizedString("ai.title", value: "Fonctionnalités IA", comment: "Titre IA")
        static let smartFeatures = NSLocalizedString("ai.smart_features", value: "Fonctions Intelligentes", comment: "Fonctions intelligentes")
        static let smartFeaturesDesc = NSLocalizedString("ai.smart_features.desc", value: "Active l'analyse IA avancée pour de meilleurs résultats", comment: "Description fonctions intelligentes")
        
        // MARK: - Plateformes
        static let platformTitle = NSLocalizedString("platform.title", value: "Plateforme Cible", comment: "Titre plateforme")
        static let instagram = NSLocalizedString("platform.instagram", value: "Instagram", comment: "Plateforme Instagram")
        static let tiktok = NSLocalizedString("platform.tiktok", value: "TikTok", comment: "Plateforme TikTok")
        static let youtube = NSLocalizedString("platform.youtube", value: "YouTube", comment: "Plateforme YouTube")
        static let facebook = NSLocalizedString("platform.facebook", value: "Facebook", comment: "Plateforme Facebook")
        
        // MARK: - Timeline
        static let timelineTitle = NSLocalizedString("timeline.title", value: "Timeline", comment: "Titre timeline")
        static let zoomIn = NSLocalizedString("timeline.zoom_in", value: "Zoom Avant", comment: "Zoom avant")
        static let zoomOut = NSLocalizedString("timeline.zoom_out", value: "Zoom Arrière", comment: "Zoom arrière")
        static let fitWindow = NSLocalizedString("timeline.fit_window", value: "Ajuster Fenêtre", comment: "Ajuster fenêtre")
        
        // MARK: - Messages de Statut
        static let analyzing = NSLocalizedString("status.analyzing", value: "Analyse en cours...", comment: "Statut analyse")
        static let generating = NSLocalizedString("status.generating", value: "Génération de la timeline...", comment: "Statut génération")
        static let rendering = NSLocalizedString("status.rendering", value: "Rendu vidéo...", comment: "Statut rendu")
        static let exporting = NSLocalizedString("status.exporting", value: "Export en cours...", comment: "Statut export")
        static let complete = NSLocalizedString("status.complete", value: "Terminé !", comment: "Statut terminé")
        
        // MARK: - Erreurs
        static let errorNoVideo = NSLocalizedString("error.no_video", value: "Aucune vidéo sélectionnée", comment: "Erreur pas de vidéo")
        static let errorNoAudio = NSLocalizedString("error.no_audio", value: "Aucune musique sélectionnée", comment: "Erreur pas d'audio")
        static let errorAnalysisFailed = NSLocalizedString("error.analysis_failed", value: "Échec de l'analyse", comment: "Erreur analyse")
        static let errorExportFailed = NSLocalizedString("error.export_failed", value: "Échec de l'export", comment: "Erreur export")
        
        // MARK: - Import/Export
        static let dragDrop = NSLocalizedString("import.drag_drop", value: "Glissez vos fichiers ici", comment: "Glisser-déposer")
        static let supportedFormats = NSLocalizedString("import.supported_formats", value: "Formats supportés : MP4, MOV, ProRes, MP3, WAV", comment: "Formats supportés")
    }
    
    /// Formatage des durées en français
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        if minutes > 0 {
            return "\(minutes)min \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    /// Formatage des nombres en français
    static func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    /// Formatage des pourcentages
    static func formatPercentage(_ value: Float) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }
    
    /// Formatage des tailles de fichier
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// Extension pour faciliter l'utilisation des textes localisés
extension String {
    /// Retourne la chaîne localisée
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Retourne la chaîne localisée avec des arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}