# 🧠 Synapse - AI-Powered Video Editing for macOS

<div align="center">

![Synapse Logo](https://img.shields.io/badge/Synapse-AI%20Video%20Editor-8B5CF6?style=for-the-badge&logo=brain&logoColor=white)

[![macOS](https://img.shields.io/badge/macOS-14.0+-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343?style=flat-square&logo=swift&logoColor=white)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-1575F9?style=flat-square&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0+-0066CC?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/swiftui/)

*Une application de montage vidéo professionnelle qui utilise l'IA pour créer automatiquement des montages vidéo synchronisés à la musique.*

</div>

## ✨ Fonctionnalités

### 🎬 Montage Intelligent
- **Analyse sémantique** : Détection de visages, segmentation de scènes, scoring de qualité
- **Intelligence audio** : Détection BPM, analyse de grille de beats, profil énergétique
- **Génération automatique** : Timeline IA synchronisée à la musique
- **Voice-aware cutting** : Évite les coupures au milieu des dialogues

### 🎨 Interface Moderne
- **Design professionnel** : Interface sombre optimisée pour le montage
- **Workspace multi-panneaux** : Sidebar, preview, timeline comme Final Cut Pro
- **Lecteur vidéo avancé** : Contrôles overlay avec scrubbing précis
- **Timeline visuelle** : Thumbnails, waveforms, animations fluides

### 🚀 Technologies Avancées
- **Metal Performance** : Rendu GPU accéléré
- **Vision Framework** : Analyse d'image et détection de contenu
- **Core ML** : Intelligence artificielle intégrée
- **SwiftUI** : Interface utilisateur moderne et réactive

## 📋 Prérequis

- **macOS 14.0** (Sonoma) ou plus récent
- **Xcode 15.0** ou plus récent
- **Apple Silicon** (M1/M2/M3) recommandé
- **8GB RAM** minimum

## 🛠 Installation

### Option 1: Xcode (Recommandé)
```bash
# Cloner le repository
git clone https://github.com/votre-username/synapse.git
cd synapse

# Ouvrir dans Xcode
open Synapse.xcodeproj
```

### Option 2: Swift Package Manager
```bash
# Compiler avec SPM
swift build

# Lancer l'application
swift run
```

## 🏗 Structure du Projet

```
Synapse/
├── Synapse.xcodeproj/          # Projet Xcode
├── Synapse/                    # Code source principal
│   ├── SynapseApp.swift       # Point d'entrée de l'app
│   ├── Views/                 # Vues SwiftUI
│   │   ├── ContentView.swift
│   │   ├── ModernComponents.swift
│   │   └── VideoPlayerView.swift
│   ├── ViewModels/            # Logique de présentation
│   │   └── ProjectViewModel.swift
│   ├── Models/                # Modèles de données
│   │   ├── AudioTrack.swift
│   │   ├── VideoSegment.swift
│   │   └── ProjectState.swift
│   ├── Services/              # Services métier
│   │   ├── AudioBrain.swift
│   │   ├── NeuralIngestor.swift
│   │   ├── SmartMomentDetector.swift
│   │   ├── VoiceActivityDetector.swift
│   │   ├── SmartAutoCompletion.swift
│   │   ├── SmartTransitionEngine.swift
│   │   ├── EnhancedMontageDirector.swift
│   │   ├── MontageDirector.swift
│   │   ├── MetalRenderer.swift
│   │   ├── RealtimePreviewEngine.swift
│   │   └── PersistenceController.swift
│   └── Resources/             # Ressources
│       └── Synapse.xcdatamodeld
├── Tests/                     # Tests unitaires
├── Package.swift              # Configuration SPM
├── README.md                  # Documentation
├── EVALUATION.md              # Évaluation technique
├── IMPROVEMENTS.md            # Améliorations IA
└── VISUAL_IMPROVEMENTS.md     # Améliorations visuelles
```

## 🎯 Utilisation

### 1. Import de Médias
- **Drag & Drop** : Glissez vos vidéos et musiques dans l'interface
- **Sélection manuelle** : Utilisez les boutons "Choose Videos" et "Choose Music"
- **Formats supportés** : ProRes, H.264, HEVC, MP4, MOV, MP3, WAV, AIFF

### 2. Génération de Timeline
```swift
// L'IA analyse automatiquement :
// - Qualité des segments vidéo
// - Détection de visages et émotions
// - Synchronisation avec les beats
// - Protection des zones vocales
```

### 3. Personnalisation
- **Profils couleur** : Cinematic, Vivid, Black & White
- **Ratios d'aspect** : 9:16 (TikTok), 16:9 (YouTube), 1:1 (Instagram)
- **Plateformes** : Optimisation automatique pour chaque réseau social

### 4. Export
- **Formats** : MP4, MOV, ProRes
- **Qualités** : 1080p, 4K
- **Optimisations** : Hardware-accelerated export (HEVC)

## 🧠 Modules IA

### NeuralIngestor
```swift
// Analyse vidéo avec Vision Framework
- Détection de visages et tracking
- Scoring de qualité (netteté, exposition, stabilité)
- Détection de saillance pour recadrage intelligent
- Tagging sémantique automatique
```

### AudioBrain
```swift
// Analyse audio avancée
- Détection de transitoires pour cuts précis
- Calcul BPM et génération de grille de beats
- Profil énergétique (sections low/mid/high energy)
- Analyse RMS d'amplitude
```

### SmartMomentDetector
```swift
// Détection intelligente des meilleurs moments
- Analyse émotionnelle (40% du score)
- Détection d'action (35% du score)
- Analyse de composition (25% du score)
- Auto-tagging des highlights
```

### VoiceActivityDetector
```swift
// Protection intelligente des voix
- Analyse RMS + Zero-Crossing Rate
- Détection multi-langue
- Buffer de sécurité avant/après dialogue
- Extension automatique des clips
```

## 🎨 Interface Utilisateur

### Design System
- **Couleurs** : Purple (#8B5CF6), Pink (#EC4899), Blue (#3B82F6)
- **Thème** : Dark mode professionnel
- **Matériaux** : Glassmorphism avec .ultraThinMaterial
- **Animations** : Micro-interactions fluides

### Composants Modernes
- `ModernButton` : Boutons stylisés avec icônes
- `StatsCardView` : Cartes de statistiques en temps réel
- `ColorProfileButton` : Sélecteur de profils visuels
- `MediaThumbnailView` : Aperçus de médias avec génération automatique

## 🚀 Performance

### Optimisations
- **Metal Performance Shaders** : Traitement GPU accéléré
- **Concurrence Swift** : async/await + TaskGroups
- **Cache intelligent** : CIImage et thumbnails
- **Actors** : Sécurité thread-safe

### Benchmarks
- **Analyse vidéo** : ~2-3s par minute de contenu
- **Génération timeline** : <5s pour 50 segments
- **Export 1080p** : Temps réel (1min vidéo = 1min export)

## 🔧 Développement

### Compilation
```bash
# Debug
swift build -c debug

# Release
swift build -c release

# Tests
swift test
```

### Architecture
- **Pattern** : MVVM + Coordinator
- **Concurrence** : Swift Concurrency (async/await)
- **Persistence** : CoreData + CloudKit
- **Rendering** : Metal + CoreImage

## 📱 Compatibilité

### Formats Vidéo
- **Import** : MP4, MOV, M4V, ProRes, HEVC, H.264
- **Export** : MP4 (H.264/HEVC), MOV, ProRes

### Formats Audio
- **Import** : MP3, WAV, AIFF, M4A, AAC
- **Analyse** : 44.1kHz, mono/stéréo

## 🤝 Contribution

1. Fork le projet
2. Créez votre branche (`git checkout -b feature/AmazingFeature`)
3. Committez vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence propriétaire. Voir le fichier `LICENSE` pour plus de détails.

## 🙏 Remerciements

- **Apple** : Frameworks AVFoundation, Vision, CoreImage, Metal, SwiftUI
- **Communauté Swift** : Outils et ressources
- **Inspiration** : Final Cut Pro, DaVinci Resolve, Adobe Premiere

---

<div align="center">

**Fait avec ❤️ et 🧠 par l'équipe Synapse**

[Documentation](./EVALUATION.md) • [Améliorations](./IMPROVEMENTS.md) • [Interface](./VISUAL_IMPROVEMENTS.md)

</div>