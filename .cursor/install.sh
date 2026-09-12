#!/usr/bin/env bash
# Cloud Agent install script for the Digital Islamic Hub Flutter monorepo.
# Idempotent: safe to run repeatedly and against cached state.
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"
FLUTTER_CHANNEL="stable"

# 1. Ensure the Flutter SDK is installed (stable channel provides Dart >= 3.10.7,
#    satisfying both apps' SDK constraints).
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo ">> Installing Flutter SDK ($FLUTTER_CHANNEL)..."
  rm -rf "$FLUTTER_DIR"
  git clone --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

# Expose flutter/dart to every shell the agent opens.
if command -v sudo >/dev/null 2>&1; then
  sudo ln -sf "$FLUTTER_DIR/bin/flutter" /usr/local/bin/flutter || true
  sudo ln -sf "$FLUTTER_DIR/bin/dart" /usr/local/bin/dart || true
fi

flutter config --no-analytics >/dev/null 2>&1 || true
# Pre-download the web engine artifacts so `flutter run -d web-server` starts quickly.
flutter precache --web >/dev/null 2>&1 || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB="$ROOT/digital_islamic_hub_new"
ADMIN="$ROOT/admin_panel"

# 2. Recreate gitignored assets required for the hub app to build.
#    These are only created when missing, so real Quran/Hadith databases or a
#    real .env supplied by a developer are never overwritten.
mkdir -p "$HUB/assets/database"
for db in quran_final_authentic_v2.db hadiths_only.db hadith_metadata.db; do
  target="$HUB/assets/database/$db"
  if [ ! -f "$target" ]; then
    echo ">> Creating placeholder database asset: $db"
    if command -v sqlite3 >/dev/null 2>&1; then
      sqlite3 "$target" "VACUUM;"
    else
      : > "$target"
    fi
  fi
done

if [ ! -f "$HUB/.env" ]; then
  echo ">> Creating placeholder .env for the hub app"
  cat > "$HUB/.env" <<'EOF'
# Provide a Google Generative AI (Gemini) API key to enable the Mufti AI chat feature.
AI_API_KEY=
EOF
fi

# 3. Resolve dependencies for both Flutter apps.
echo ">> Resolving dependencies for digital_islamic_hub_new..."
( cd "$HUB" && flutter pub get )
echo ">> Resolving dependencies for admin_panel..."
( cd "$ADMIN" && flutter pub get )

echo ">> Install complete."
