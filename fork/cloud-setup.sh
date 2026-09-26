#!/bin/bash
# Script d'installation de l'environnement cloud Claude Code « Flutter ».
# À coller dans le champ Setup script de l'environnement, sur claude.ai/code.
# Il installe Flutter stable dans /opt/flutter. Le résultat est gardé en cache
# par l'environnement (environ 7 jours), il ne tourne donc pas à chaque session.

FLUTTER_DIR=/opt/flutter
BASE=https://storage.googleapis.com/flutter_infra_release/releases

command -v xz >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq xz-utils; } || true

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  ARCHIVE=$(curl -fsSL "$BASE/releases_linux.json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
h = d["current_release"]["stable"]
print(next(r["archive"] for r in d["releases"] if r["hash"] == h))
') || true
  if [ -n "$ARCHIVE" ]; then
    curl -fsSL "$BASE/$ARCHIVE" | tar -xJ -C /opt || true
  fi
fi

git config --system --add safe.directory '*' || true

if [ -x "$FLUTTER_DIR/bin/flutter" ]; then
  ln -sf "$FLUTTER_DIR/bin/flutter" /usr/local/bin/flutter
  ln -sf "$FLUTTER_DIR/bin/dart" /usr/local/bin/dart
  flutter config --no-analytics >/dev/null 2>&1 || true
  flutter --version || true
  chmod -R a+rwX "$FLUTTER_DIR" || true
fi

exit 0
