#!/usr/bin/env bash
# Build PWA de producción: iconos + flutter build web + sellado de versión para auto-update.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE_HREF="${BASE_HREF:-/}"

echo "==> Generando iconos PWA desde assets/images/logo_icon.png"
python3 tool/generate_pwa_icons.py

echo "==> Flutter build web (release) base-href=${BASE_HREF}"
flutter pub get
flutter build web \
  --release \
  --base-href "${BASE_HREF}" \
  --pwa-strategy none \
  --no-tree-shake-icons

echo "==> Sellando buildId en artefactos PWA (version.json, index.html, SW FCM)"
python3 tool/stamp_pwa_build.py

OUT="$ROOT/build/web"

if grep -q '%%PWA_BUILD_ID%%' "$OUT/index.html"; then
  echo "ERROR: index.html todavía tiene %%PWA_BUILD_ID%% sin sellar. Abortando."
  exit 1
fi

if [[ -f "$OUT/flutter_service_worker.js" ]]; then
  echo "WARN: eliminando flutter_service_worker.js residual"
  rm -f "$OUT/flutter_service_worker.js"
fi

echo ""
echo "==> Listo. Despliega TODO el contenido de build/web en HTTPS."
echo "    IMPORTANTE: usa este script (no solo 'flutter build web') antes de subir."
echo "    En Firebase Console → Authentication → Settings → Authorized domains"
echo "    agrega: app.tochitopro.com"
echo ""
ls -la "$OUT" | head -20
