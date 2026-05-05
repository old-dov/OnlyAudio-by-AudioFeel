# OnlyAudio — Build Linux

Guide complet pour compiler et distribuer OnlyAudio sur Linux.

---

## Prérequis

### Dépendances système

```bash
# Ubuntu / Debian
sudo apt-get install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libmpv-dev

# Fedora / RHEL
sudo dnf install -y \
  clang cmake ninja-build pkg-config \
  gtk3-devel xz-devel \
  mpv-libs-devel

# Arch Linux
sudo pacman -S --needed \
  clang cmake ninja pkg-config \
  gtk3 xz mpv
```

### Flutter

```bash
# Via snap (Ubuntu)
sudo snap install flutter --classic

# Ou manuellement
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor
```

> `flutter doctor` doit indiquer Linux toolchain OK.

---

## Cloner et configurer le projet

```bash
git clone https://github.com/old-dov/OnlyAudio-by-AudioFeel.git
cd OnlyAudio-by-AudioFeel

flutter pub get
```

---

## Lancer en mode développement

```bash
flutter run -d linux
```

---

## Compiler en release

```bash
flutter build linux --release
```

L'application est générée dans :

```
build/linux/x64/release/bundle/
├── onlyaudio_by_audiofeel   ← exécutable principal
├── lib/                      ← bibliothèques partagées (libmpv, etc.)
└── data/                     ← assets Flutter
```

Pour lancer l'application compilée :

```bash
./build/linux/x64/release/bundle/onlyaudio_by_audiofeel
```

---

## Distribuer

### AppImage (recommandé)

```bash
# Installer appimagetool
wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool

# Préparer la structure AppDir
mkdir -p OnlyAudio.AppDir/usr/bin
cp -r build/linux/x64/release/bundle/* OnlyAudio.AppDir/usr/bin/

# Créer l'AppImage
./appimagetool OnlyAudio.AppDir OnlyAudio-x86_64.AppImage
```

### .deb (Debian / Ubuntu)

```bash
mkdir -p onlyaudio_1.0.0_amd64/DEBIAN
mkdir -p onlyaudio_1.0.0_amd64/usr/local/bin/onlyaudio
mkdir -p onlyaudio_1.0.0_amd64/usr/share/applications

cp -r build/linux/x64/release/bundle/* onlyaudio_1.0.0_amd64/usr/local/bin/onlyaudio/

cat > onlyaudio_1.0.0_amd64/DEBIAN/control << EOF
Package: onlyaudio
Version: 1.0.0
Architecture: amd64
Maintainer: AudioFeel
Description: OnlyAudio by AudioFeel — lecteur audio desktop
Depends: libgtk-3-0, libmpv1
EOF

cat > onlyaudio_1.0.0_amd64/usr/share/applications/onlyaudio.desktop << EOF
[Desktop Entry]
Name=OnlyAudio
Exec=/usr/local/bin/onlyaudio/onlyaudio_by_audiofeel
Type=Application
Categories=Audio;Music;
EOF

dpkg-deb --build onlyaudio_1.0.0_amd64
```

---

## Architecture technique Linux

### Moteur audio

L'audio est géré par **media_kit** (libmpv) via `media_kit_libs_linux`. Le même mécanisme que Windows et macOS est utilisé :

- **Serveur HTTP local** (127.0.0.1, port aléatoire) — libmpv reçoit les fichiers via HTTP
- **Dual-player pre-buffering** — le titre suivant est pré-bufferisé silencieusement, le swap est instantané

### Pas de sandbox

Contrairement à macOS, Linux n'a pas de sandbox applicatif par défaut. L'app peut accéder directement aux fichiers sans entitlements particuliers.

### Fenêtre

Gérée par **window_manager** + **GTK3**. Taille minimale 700×480, titre « OnlyAudio by AudioFeel ».

---

## Fonctionnalités supportées

| Fonctionnalité | Linux |
|----------------|-------|
| Lecture MP3, FLAC, WAV, OGG, M4A, AAC | ✅ |
| Métadonnées + pochette | ✅ |
| Playlist, shuffle, repeat | ✅ |
| Seek, volume | ✅ |
| Dual-player pre-buffering | ✅ |
| Plein écran | ✅ |
| Télécommande Android (API REST) | ✅ |

---

## Résolution de problèmes

### `libmpv.so` introuvable

```bash
sudo apt-get install libmpv-dev
# ou
sudo ldconfig
```

### `clang` ou `cmake` manquant

```bash
sudo apt-get install clang cmake ninja-build
```

### Aucun son en lecture

Vérifier que PulseAudio ou PipeWire est actif :

```bash
pactl info
# ou
pw-cli info
```

### Permission refusée sur les fichiers audio

Sur Linux, l'app accède directement aux fichiers sans restriction — vérifier les permissions du dossier audio :

```bash
ls -la /chemin/vers/musiques/
```

---

## Auteur

**AudioFeel** — © 2026
