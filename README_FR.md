# 🧠 Synapse - Montage Vidéo Alimenté par l'IA pour macOS

<div align="center">

![Logo Synapse](https://img.shields.io/badge/Synapse-Éditeur%20Vidéo%20IA-8B5CF6?style=for-the-badge&logo=brain&logoColor=white)

[![macOS](https://img.shields.io/badge/macOS-14.0+-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/fr/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-FA7343?style=flat-square&logo=swift&logoColor=white)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-1575F9?style=flat-square&logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0+-0066CC?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/swiftui/)

*Une application de montage vidéo professionnelle qui utilise l'intelligence artificielle pour créer automatiquement des montages vidéo synchronisés à la musique.*

</div>

## ✨ Fonctionnalités

### 🎬 Montage Intelligent
- **Analyse sémantique** : Détection de visages, segmentation de scènes, évaluation de qualité
- **Intelligence audio** : Détection BPM, analyse de grille de beats, profil énergétique
- **Génération automatique** : Timeline IA synchronisée à la musique
- **Coupures intelligentes** : Évite les coupures au milieu des dialogues

### 🎨 Interface Moderne
- **Design professionnel** : Interface sombre optimisée pour le montage
- **Espace de travail multi-panneaux** : Barre latérale, aperçu, timeline comme Final Cut Pro
- **Lecteur vidéo avancé** : Contrôles en superposition avec scrubbing précis
- **Timeline visuelle** : Vignettes, formes d'onde, animations fluides

### 🚀 Technologies Avancées
- **Performance Metal** : Rendu accéléré par GPU
- **Framework Vision** : Analyse d'image et détection de contenu
- **Core ML** : Intelligence artificielle intégrée
- **SwiftUI** : Interface utilisateur moderne et réactive

## 📋 Prérequis

- **macOS 14.0** (Sonoma) ou plus récent
- **Xcode 15.0** ou plus récent
- **Apple Silicon** (M1/M2/M3) recommandé
- **8 Go de RAM** minimum

## 🛠 Installation

### Option 1: Xcode (Recommandé)
```bash
# Cloner le dépôt
git clone https://github.com/votre-nom-utilisateur/synapse.git
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
│   ├── main.swift             # Point d'entrée de l'app
│   ├── Vues/                  # Vues SwiftUI
│   ├── ModèlesVue/            # Logique de présentation
│   ├── Modèles/               # Modèles de données
│   ├── Services/              # Services métier
│   └── Ressources/            # Ressources
├── Tests/                     # Tests unitaires
├── Package.swift              # Configuration SPM
└── Documentation/             # Documentation complète
```

## 🎯 Utilisation

### 1. Import de Médias
- **Glisser-Déposer** : Glissez vos vidéos et musiques dans l'interface
- **Sélection manuelle** : Utilisez les boutons "Choisir Vidéos" et "Choisir Musique"
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
- **Profils couleur** : Cinématique, Vif, Noir & Blanc
- **Ratios d'aspect** : 9:16 (TikTok), 16:9 (YouTube), 1:1 (Instagram)
- **Plateformes** : Optimisation automatique pour chaque réseau social

### 4. Export
- **Formats** : MP4, MOV, ProRes
- **Qualités** : 1080p, 4K
- **Optimisations** : Export accéléré par matériel (HEVC)

## 🧠 Modules IA

### IngesteurNeuronal
```swift
// Analyse vidéo avec Framework Vision
- Détection et suivi de visages
- Évaluation de qualité (netteté, exposition, stabilité)
- Détection de saillance pour recadrage intelligent
- Étiquetage sémantique automatique
```

### CerveauAudio
```swift
// Analyse audio avancée
- Détection de transitoires pour coupures précises
- Calcul BPM et génération de grille de beats
- Profil énergétique (sections basse/moyenne/haute énergie)
- Analyse d'amplitude RMS
```

### DétecteurMomentsIntelligents
```swift
// Détection intelligente des meilleurs moments
- Analyse émotionnelle (40% du score)
- Détection d'action (35% du score)
- Analyse de composition (25% du score)
- Étiquetage automatique des moments forts
```

### DétecteurActivitéVocale
```swift
// Protection intelligente des voix
- Analyse RMS + Taux de passage par zéro
- Détection multi-langue
- Tampon de sécurité avant/après dialogue
- Extension automatique des clips
```

## 🎨 Interface Utilisateur

### Système de Design
- **Couleurs** : Violet (#8B5CF6), Rose (#EC4899), Bleu (#3B82F6)
- **Thème** : Mode sombre professionnel
- **Matériaux** : Glassmorphisme avec .ultraThinMaterial
- **Animations** : Micro-interactions fluides

### Composants Modernes
- `BoutonModerne` : Boutons stylisés avec icônes
- `VueCarteStats` : Cartes de statistiques en temps réel
- `BoutonProfilCouleur` : Sélecteur de profils visuels
- `VueVignetteMédia` : Aperçus de médias avec génération automatique

## 🚀 Performance

### Optimisations
- **Shaders Performance Metal** : Traitement accéléré par GPU
- **Concurrence Swift** : async/await + TaskGroups
- **Cache intelligent** : CIImage et vignettes
- **Acteurs** : Sécurité thread-safe

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
- **Modèle** : MVVM + Coordinateur
- **Concurrence** : Concurrence Swift (async/await)
- **Persistance** : CoreData + CloudKit
- **Rendu** : Metal + CoreImage

## 📱 Compatibilité

### Formats Vidéo
- **Import** : MP4, MOV, M4V, ProRes, HEVC, H.264
- **Export** : MP4 (H.264/HEVC), MOV, ProRes

### Formats Audio
- **Import** : MP3, WAV, AIFF, M4A, AAC
- **Analyse** : 44,1kHz, mono/stéréo

## 🎯 Fonctionnalités Clés

### 🎬 Montage Automatique
- **Analyse intelligente** : L'IA comprend le contenu de vos vidéos
- **Synchronisation musicale** : Coupures parfaitement alignées sur les beats
- **Détection d'émotions** : Privilégie les moments avec sourires et expressions
- **Respect des dialogues** : Ne coupe jamais au milieu d'une phrase

### 🎨 Interface Professionnelle
- **Design Final Cut Pro** : Interface familière aux professionnels
- **Thème sombre** : Optimisé pour de longues sessions de montage
- **Animations fluides** : Retours visuels constants et agréables
- **Contrôles intuitifs** : Tout à portée de main

### 🚀 Performance Optimisée
- **Rendu GPU** : Utilise la puissance de votre Mac
- **Traitement parallèle** : Analyse plusieurs vidéos simultanément
- **Cache intelligent** : Évite les recalculs inutiles
- **Export rapide** : Temps réel même en 4K

## 🎓 Guide d'Utilisation

### Étape 1 : Préparation
1. **Rassemblez vos médias** : Vidéos et musique dans un dossier
2. **Choisissez votre style** : Réfléchissez au rendu souhaité
3. **Définissez la plateforme** : TikTok, YouTube, Instagram...

### Étape 2 : Import
1. **Lancez Synapse** : Ouvrez l'application
2. **Glissez vos fichiers** : Directement dans l'interface
3. **Ou utilisez les boutons** : "Choisir Vidéos" et "Choisir Musique"

### Étape 3 : Configuration
1. **Sélectionnez le profil couleur** : Cinématique, Vif, ou N&B
2. **Choisissez le ratio** : Selon votre plateforme cible
3. **Activez les fonctions IA** : Pour un résultat optimal

### Étape 4 : Génération
1. **Cliquez "Générer Timeline"** : L'IA fait le travail
2. **Patientez quelques secondes** : Analyse en cours
3. **Admirez le résultat** : Timeline automatiquement créée

### Étape 5 : Personnalisation
1. **Prévisualisez** : Utilisez le lecteur intégré
2. **Ajustez si nécessaire** : Glissez pour réorganiser
3. **Optimisez pour la plateforme** : Bouton automatique

### Étape 6 : Export
1. **Choisissez la qualité** : 1080p ou 4K
2. **Sélectionnez le format** : MP4 recommandé
3. **Lancez l'export** : Et partagez votre création !

## 🤝 Contribution

1. Forkez le projet
2. Créez votre branche (`git checkout -b fonctionnalite/SuperFonctionnalite`)
3. Committez vos changements (`git commit -m 'Ajout SuperFonctionnalite'`)
4. Poussez vers la branche (`git push origin fonctionnalite/SuperFonctionnalite`)
5. Ouvrez une Pull Request

## 📄 Licence

Ce projet est sous licence propriétaire. Voir le fichier `LICENSE` pour plus de détails.

## 🙏 Remerciements

- **Apple** : Frameworks AVFoundation, Vision, CoreImage, Metal, SwiftUI
- **Communauté Swift** : Outils et ressources
- **Inspiration** : Final Cut Pro, DaVinci Resolve, Adobe Premiere

---

<div align="center">

**Créé avec ❤️ et 🧠 par l'équipe Synapse**

[Documentation](./EVALUATION.md) • [Améliorations](./IMPROVEMENTS.md) • [Interface](./VISUAL_IMPROVEMENTS.md)

**🇫🇷 Version française complète - Prêt pour Xcode ! 🚀**

</div>