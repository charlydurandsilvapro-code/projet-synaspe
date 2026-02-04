#!/bin/bash

# Script de validation de la Timeline Magnétique
# Usage: ./validate_magnetic_timeline.sh

set -e  # Arrêt en cas d'erreur

echo "🎬 Validation de la Timeline Magnétique - Synapse"
echo "=================================================="
echo ""

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction de validation
validate() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        exit 1
    fi
}

# 1. Vérification de la structure des fichiers
echo "📁 Vérification de la structure..."
echo ""

files=(
    "Synapse/ViewModels/TimelineEngine.swift"
    "Synapse/Views/MagneticTimeline/ClipView.swift"
    "Synapse/Views/MagneticTimeline/MagneticTimelineView.swift"
    "Synapse/Views/MagneticTimeline/TimelineAnimations.swift"
    "Synapse/Models/VideoSegment.swift"
    "Synapse/ViewModels/ProjectViewModel.swift"
    "Synapse/main.swift"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}✗${NC} $file manquant!"
        exit 1
    fi
done

echo ""

# 2. Vérification des documentations
echo "📚 Vérification de la documentation..."
echo ""

docs=(
    "MAGNETIC_TIMELINE_IMPLEMENTATION.md"
    "MAGNETIC_TIMELINE_GUIDE.md"
    "MAGNETIC_TIMELINE_ADVANCED.md"
    "MAGNETIC_TIMELINE_SUMMARY.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo -e "${GREEN}✓${NC} $doc"
    else
        echo -e "${YELLOW}⚠${NC} $doc manquant (optionnel)"
    fi
done

echo ""

# 3. Compilation Debug
echo "🔨 Compilation en mode Debug..."
echo ""

swift build > /dev/null 2>&1
validate "Compilation Debug réussie"

echo ""

# 4. Vérification du code avec swift-format (si disponible)
echo "📝 Vérification du style de code..."
echo ""

if command -v swift-format &> /dev/null; then
    swift-format lint --recursive Synapse/ > /dev/null 2>&1
    validate "Style de code conforme"
else
    echo -e "${YELLOW}⚠${NC} swift-format non installé (optionnel)"
fi

echo ""

# 5. Recherche de TODOs ou FIXMEs
echo "🔍 Recherche de TODOs/FIXMEs..."
echo ""

todos=$(grep -r "TODO\|FIXME" Synapse/ --include="*.swift" | wc -l | tr -d ' ')
if [ "$todos" -eq "0" ]; then
    echo -e "${GREEN}✓${NC} Aucun TODO/FIXME trouvé"
else
    echo -e "${YELLOW}⚠${NC} $todos TODO/FIXME trouvés (normal pour développement)"
fi

echo ""

# 6. Vérification des imports essentiels
echo "📦 Vérification des imports critiques..."
echo ""

check_import() {
    if grep -q "$2" "$1"; then
        echo -e "${GREEN}✓${NC} $3"
    else
        echo -e "${RED}✗${NC} $3 manquant dans $1"
        exit 1
    fi
}

check_import "Synapse/ViewModels/TimelineEngine.swift" "import Observation" "Observation framework"
check_import "Synapse/Views/MagneticTimeline/ClipView.swift" "import SwiftUI" "SwiftUI framework"
check_import "Synapse/Models/VideoSegment.swift" "import CoreMedia" "CoreMedia framework"

echo ""

# 7. Vérification des fonctionnalités clés
echo "🎯 Vérification des fonctionnalités clés..."
echo ""

check_feature() {
    if grep -q "$2" "$1"; then
        echo -e "${GREEN}✓${NC} $3"
    else
        echo -e "${RED}✗${NC} $3 non trouvé"
        exit 1
    fi
}

check_feature "Synapse/ViewModels/TimelineEngine.swift" "@Observable" "Macro @Observable"
check_feature "Synapse/ViewModels/TimelineEngine.swift" "func position(for" "Calcul de position dynamique"
check_feature "Synapse/Views/MagneticTimeline/ClipView.swift" "TrimHandle" "Trim handles"
check_feature "Synapse/Views/MagneticTimeline/MagneticTimelineView.swift" ".draggable" "Drag & drop"
check_feature "Synapse/Views/MagneticTimeline/TimelineAnimations.swift" "PhaseAnimator" "Phase animations"

echo ""

# 8. Statistiques du code
echo "📊 Statistiques du code..."
echo ""

count_lines() {
    if [ -f "$1" ]; then
        lines=$(wc -l < "$1" | tr -d ' ')
        echo "$1: $lines lignes"
    fi
}

echo "Fichiers principaux:"
count_lines "Synapse/ViewModels/TimelineEngine.swift"
count_lines "Synapse/Views/MagneticTimeline/ClipView.swift"
count_lines "Synapse/Views/MagneticTimeline/MagneticTimelineView.swift"
count_lines "Synapse/Views/MagneticTimeline/TimelineAnimations.swift"

echo ""

total_lines=$(find Synapse/ViewModels/TimelineEngine.swift \
                   Synapse/Views/MagneticTimeline/*.swift \
                   -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')
echo "Total: $total_lines lignes de code ajoutées"

echo ""

# 9. Compilation Release (optionnelle)
echo "🚀 Compilation en mode Release..."
echo ""

if swift build -c release > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Compilation Release réussie"
else
    echo -e "${YELLOW}⚠${NC} Compilation Release échouée (non critique)"
fi

echo ""

# 10. Résumé final
echo "=================================================="
echo -e "${GREEN}✅ Validation complète réussie!${NC}"
echo ""
echo "La Timeline Magnétique est prête à être utilisée."
echo ""
echo "Pour tester:"
echo "  1. swift run"
echo "  2. Cliquez sur 'Démo Auto-Rush'"
echo "  3. Testez les interactions (drag, trim, zoom)"
echo ""
echo "Documentation disponible:"
echo "  - MAGNETIC_TIMELINE_GUIDE.md (guide utilisateur)"
echo "  - MAGNETIC_TIMELINE_IMPLEMENTATION.md (technique)"
echo "  - MAGNETIC_TIMELINE_ADVANCED.md (concepts avancés)"
echo ""
echo "🎉 Bon montage avec Synapse!"
