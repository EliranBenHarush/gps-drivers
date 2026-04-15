#!/bin/bash
set -e

FLUTTER_VERSION="3.41.6"
FLUTTER_DIR="$HOME/flutter"

# Download & cache Flutter SDK
if [ ! -f "$FLUTTER_DIR/bin/flutter" ]; then
  echo "⬇️  Downloading Flutter $FLUTTER_VERSION..."
  wget -q "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -O flutter.tar.xz
  tar xf flutter.tar.xz -C "$HOME"
  rm flutter.tar.xz
  echo "✅ Flutter extracted"
else
  echo "✅ Flutter cached"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

flutter --version
flutter config --enable-web
flutter create . --platforms web
flutter pub get
flutter build web \
  --dart-define=MAPBOX_TOKEN=${MAPBOX_TOKEN} \
  --release

echo "✅ Build complete"
