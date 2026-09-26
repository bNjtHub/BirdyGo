#!/bin/bash
# Hook SessionStart : prépare le projet au début de chaque session cloud.
# Ne fait rien en local : sur le PC, ces commandes se lancent à la main.
[ "$CLAUDE_CODE_REMOTE" = "true" ] || exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter est absent : vérifier le setup script de l'environnement cloud."
  exit 0
fi

flutter pub get >/dev/null 2>&1 || echo "flutter pub get a échoué, relancer la commande pour voir l'erreur."
flutter gen-l10n >/dev/null 2>&1 || true
exit 0
