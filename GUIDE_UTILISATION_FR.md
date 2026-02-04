# 📖 Guide d'Utilisation - Synapse

## 🚀 Démarrage Rapide

### 1. Ouverture du Projet
```bash
# Dans le Terminal
cd /chemin/vers/synapse
open Synapse.xcodeproj
```

### 2. Compilation et Lancement
- **Dans Xcode** : Appuyez sur `⌘R` (Cmd+R)
- **En ligne de commande** : `swift run`

## 🎬 Créer Votre Premier Montage

### Étape 1 : Préparation des Médias
1. **Rassemblez vos vidéos** dans un dossier
   - Formats supportés : MP4, MOV, ProRes, HEVC
   - Résolution recommandée : 1080p ou 4K
   - Durée idéale : 10 secondes à 5 minutes par clip

2. **Choisissez votre musique**
   - Formats supportés : MP3, WAV, AIFF, M4A
   - Qualité recommandée : 44.1kHz, stéréo
   - Durée : 30 secondes à 3 minutes

### Étape 2 : Import dans Synapse
1. **Lancez Synapse**
2. **Méthode 1 - Glisser-Déposer** :
   - Glissez vos vidéos dans la zone d'accueil
   - Glissez votre musique dans la même zone

3. **Méthode 2 - Sélection Manuelle** :
   - Cliquez "Choisir Vidéos"
   - Sélectionnez vos fichiers vidéo
   - Cliquez "Choisir Musique"
   - Sélectionnez votre fichier audio

### Étape 3 : Configuration du Projet
1. **Profil Couleur** (Sidebar → Effets) :
   - **Cinématique** : Tons chauds, aspect film
   - **Vif** : Couleurs saturées, moderne
   - **N&B** : Monochrome artistique

2. **Ratio d'Aspect** :
   - **9:16** : TikTok, Instagram Stories, YouTube Shorts
   - **16:9** : YouTube, Facebook, télévision
   - **1:1** : Instagram Posts, Facebook carrés

3. **Plateforme Cible** (Sidebar → Réglages) :
   - Optimise automatiquement la durée et le style

### Étape 4 : Génération IA
1. **Activez les Fonctions Intelligentes** (recommandé)
2. **Cliquez "Générer Timeline"**
3. **Patientez** pendant l'analyse :
   - Détection de visages et émotions
   - Analyse de la qualité vidéo
   - Synchronisation avec les beats
   - Protection des zones vocales

### Étape 5 : Personnalisation
1. **Prévisualisez** avec le lecteur intégré
2. **Réorganisez** les segments par glisser-déposer
3. **Supprimez** les segments indésirables (glisser vers la gauche)
4. **Favorisez** les meilleurs moments (glisser vers la droite)

### Étape 6 : Optimisation et Export
1. **Optimisez pour la plateforme** (bouton automatique)
2. **Générez un aperçu** pour vérifier le résultat
3. **Exportez** :
   - Choisissez la qualité (1080p/4K)
   - Sélectionnez le format (MP4 recommandé)
   - Lancez l'export

## 🎯 Conseils d'Utilisation

### Pour de Meilleurs Résultats

#### 📹 Vidéos
- **Variez les plans** : Gros plans, plans moyens, plans larges
- **Privilégiez la qualité** : Bonne exposition, image nette
- **Incluez des visages** : L'IA détecte mieux les émotions
- **Évitez les tremblements** : Utilisez un stabilisateur

#### 🎵 Musique
- **Choisissez un rythme marqué** : L'IA synchronise sur les beats
- **Évitez les morceaux trop lents** : Moins de 80 BPM
- **Préférez les versions instrumentales** : Pour éviter les conflits vocaux
- **Durée adaptée** : 30s-2min selon la plateforme

#### ⚙️ Paramètres
- **Activez toujours les Fonctions IA** : Meilleure analyse
- **Choisissez la bonne plateforme** : Optimisation automatique
- **Testez différents profils couleur** : Selon l'ambiance souhaitée

### Raccourcis Clavier Utiles

| Raccourci | Action |
|-----------|--------|
| `Espace` | Lecture/Pause |
| `←` | Reculer 5 secondes |
| `→` | Avancer 5 secondes |
| `⌘+` | Zoom avant timeline |
| `⌘-` | Zoom arrière timeline |
| `⌘R` | Actualiser aperçu |
| `⌘E` | Exporter |
| `⌘N` | Nouveau projet |
| `⌘S` | Sauvegarder |

## 🔧 Résolution de Problèmes

### Problèmes Courants

#### "Aucune vidéo détectée"
- **Vérifiez le format** : MP4, MOV, ProRes supportés
- **Vérifiez la taille** : Fichiers < 2 Go recommandés
- **Vérifiez les permissions** : Accès au dossier requis

#### "Analyse échouée"
- **Redémarrez l'application**
- **Vérifiez l'espace disque** : 5 Go libres minimum
- **Fermez autres applications** : Libérez la mémoire

#### "Export lent"
- **Réduisez la qualité** : 1080p au lieu de 4K
- **Fermez autres apps** : Libérez le GPU
- **Vérifiez la température** : Mac pas en surchauffe

#### "Pas de son dans l'export"
- **Vérifiez le fichier audio** : Format supporté
- **Relancez l'analyse audio** : Bouton actualiser
- **Vérifiez les permissions** : Accès microphone

### Optimisation Performance

#### Pour Mac M1/M2/M3
- **Activez l'accélération GPU** : Automatique
- **Utilisez la mémoire unifiée** : Optimisé
- **Profitez du Neural Engine** : IA accélérée

#### Pour Mac Intel
- **Fermez applications gourmandes** : Chrome, etc.
- **Réduisez la qualité d'aperçu** : Plus fluide
- **Utilisez des proxies** : Pour gros fichiers

## 📊 Comprendre l'Interface

### Sidebar (Barre Latérale)

#### Section Projet
- **Statistiques temps réel** : Segments, durée, qualité
- **Actions rapides** : Remplissage auto, optimisation
- **Informations projet** : Métadonnées

#### Section Médias
- **Bibliothèque** : Vignettes des vidéos importées
- **Import** : Boutons d'ajout de médias
- **Gestion** : Organisation des fichiers

#### Section Effets
- **Profils couleur** : Cinématique, Vif, N&B
- **Ratios d'aspect** : 9:16, 16:9, 1:1
- **Préréglages** : Configurations rapides

#### Section Réglages
- **Fonctions IA** : Activation/désactivation
- **Plateforme cible** : Optimisation automatique
- **Préférences** : Configuration avancée

### Zone Principale

#### Lecteur Vidéo
- **Contrôles overlay** : Apparaissent au survol
- **Scrubbing précis** : Glissez sur la barre de progression
- **Plein écran** : Double-clic ou bouton

#### Timeline
- **Segments visuels** : Vignettes et informations
- **Zoom** : Molette ou boutons +/-
- **Réorganisation** : Glisser-déposer
- **Waveform** : Visualisation audio

## 🎨 Personnalisation Avancée

### Profils Couleur Détaillés

#### Cinématique
- **Usage** : Films, documentaires, contenu émotionnel
- **Caractéristiques** : Tons chauds, contraste modéré
- **Idéal pour** : Portraits, couchers de soleil, ambiances

#### Vif
- **Usage** : Réseaux sociaux, contenu dynamique
- **Caractéristiques** : Couleurs saturées, contraste élevé
- **Idéal pour** : Sport, fêtes, paysages colorés

#### Noir & Blanc
- **Usage** : Contenu artistique, vintage
- **Caractéristiques** : Monochrome, contraste renforcé
- **Idéal pour** : Portraits dramatiques, architecture

### Optimisation par Plateforme

#### TikTok (9:16, 15-60s)
- **Style** : Dynamique, coupures rapides
- **Rythme** : Synchronisé aux beats
- **Focus** : Visages et actions

#### Instagram (1:1 ou 9:16, 15-60s)
- **Style** : Esthétique, couleurs vives
- **Rythme** : Modéré à rapide
- **Focus** : Composition et beauté

#### YouTube (16:9, 30-180s)
- **Style** : Narratif, rythme varié
- **Rythme** : Adapté au contenu
- **Focus** : Histoire et engagement

## 🚀 Fonctionnalités Avancées

### IA Détection de Moments
- **Sourires** : Détection automatique des expressions
- **Actions** : Mouvements et dynamisme
- **Composition** : Règle des tiers, cadrage
- **Qualité** : Netteté, exposition, stabilité

### Synchronisation Musicale
- **Détection BPM** : Analyse automatique du tempo
- **Grille de beats** : Alignement précis des coupures
- **Profil énergétique** : Adaptation du rythme de montage
- **Protection vocale** : Évite les coupures dans les dialogues

### Rendu Optimisé
- **Metal Performance** : Accélération GPU
- **Cache intelligent** : Évite les recalculs
- **Export parallèle** : Utilise tous les cœurs
- **Formats optimisés** : HEVC, ProRes selon l'usage

## 📈 Workflow Professionnel

### Préparation
1. **Organisez vos médias** : Dossiers par projet
2. **Sauvegardez** : Copies de sécurité
3. **Planifiez** : Storyboard ou script
4. **Testez** : Formats et qualité

### Production
1. **Import organisé** : Batch par séquences
2. **Analyse complète** : Toutes les fonctions IA
3. **Itération rapide** : Plusieurs versions
4. **Validation** : Aperçus fréquents

### Post-Production
1. **Optimisation finale** : Plateforme spécifique
2. **Contrôle qualité** : Vérification complète
3. **Export multiple** : Différents formats
4. **Archivage** : Sauvegarde du projet

---

## 🎯 Résumé des Bonnes Pratiques

### ✅ À Faire
- Utilisez des vidéos de qualité (1080p minimum)
- Activez toujours les fonctions IA
- Choisissez une musique rythmée
- Variez les types de plans
- Testez différents profils couleur
- Optimisez pour votre plateforme cible

### ❌ À Éviter
- Fichiers vidéo corrompus ou de mauvaise qualité
- Musique sans rythme marqué
- Trop de segments similaires
- Ignorer les optimisations de plateforme
- Exporter sans prévisualiser
- Oublier de sauvegarder le projet

---

**🎬 Avec ce guide, vous êtes prêt à créer des montages vidéo professionnels avec Synapse ! 🚀**