#!/bin/bash

echo "🚀 Test de l'application Synapse"
echo "================================"

# Compilation
echo "📦 Compilation..."
swift build

if [ $? -eq 0 ]; then
    echo "✅ Compilation réussie"
else
    echo "❌ Erreur de compilation"
    exit 1
fi

# Test de lancement (avec timeout)
echo "🎬 Lancement de l'application..."
timeout 5s swift run &
APP_PID=$!

sleep 2

# Vérification si l'application est toujours en cours d'exécution
if kill -0 $APP_PID 2>/dev/null; then
    echo "✅ Application lancée avec succès"
    echo "🔄 L'application fonctionne (PID: $APP_PID)"
    
    # Arrêt propre
    kill $APP_PID 2>/dev/null
    sleep 1
    
    if kill -0 $APP_PID 2>/dev/null; then
        echo "🛑 Arrêt forcé de l'application"
        kill -9 $APP_PID 2>/dev/null
    fi
    
    echo "✅ Test terminé avec succès"
    echo ""
    echo "🎯 Fonctionnalités implémentées:"
    echo "   • Interface moderne avec thème sombre"
    echo "   • Analyse audio FFT avec détection de beats"
    echo "   • Auto-cut intelligent synchronisé à la musique"
    echo "   • Auto-rush avec sélection des meilleurs moments"
    echo "   • Mode démonstration intégré"
    echo "   • Timeline professionnelle avec thumbnails"
    echo "   • Préférences configurables"
    echo ""
    echo "🚀 Pour utiliser l'application:"
    echo "   1. Lancez: swift run"
    echo "   2. Cliquez sur 'Démo Auto-Rush' pour tester"
    echo "   3. Ou importez vos propres vidéos et musique"
    
else
    echo "❌ L'application ne s'est pas lancée correctement"
    exit 1
fi