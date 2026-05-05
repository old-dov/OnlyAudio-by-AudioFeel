# OnlyAudio — Build macOS

Guide complet pour compiler et distribuer OnlyAudio sur macOS.

---

## Prérequis

| Outil | Version minimale | Installation |
|-------|-----------------|-------------|
| macOS | 10.14 Mojave | — |
| Xcode | 14+ | App Store |
| Command Line Tools | — | `xcode-select --install` |
| CocoaPods | 1.12+ | `sudo gem install cocoapods` |
| Flutter | 3.41+ | [flutter.dev](https://flutter.dev) |
| puro (optionnel) | — | `brew install puro` |

> **Note :** Xcode doit être ouvert au moins une fois et la licence acceptée (`sudo xcodebuild -license accept`).

---

## Cloner et configurer le projet

```bash
git clone https://github.com/old-dov/OnlyAudio-by-AudioFeel.git
cd OnlyAudio-by-AudioFeel

# Télécharger les dépendances Dart
flutter pub get

# Installer les pods macOS
cd macos && pod install && cd ..
```

---

## Lancer en mode développement

```bash
flutter run -d macos
```

---

## Compiler en release

```bash
flutter build macos --release
```

L'application est générée dans :

```
build/macos/Build/Products/Release/OnlyAudio.app
```

Pour créer une archive distribuable (`.dmg` ou `.zip`) :

```bash
# Créer un .zip directement utilisable
cd build/macos/Build/Products/Release/
zip -r OnlyAudio-mac.zip OnlyAudio.app
```

---

## Distribuer hors App Store (Notarisation)

Pour distribuer l'app en dehors du Mac App Store sans que Gatekeeper ne la bloque, il faut la **signer** et la **notariser**.

### 1. Signer avec un certificat Developer ID

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: TON NOM (TEAM_ID)" \
  build/macos/Build/Products/Release/OnlyAudio.app
```

### 2. Créer le DMG

```bash
hdiutil create -volname "OnlyAudio" \
  -srcfolder build/macos/Build/Products/Release/OnlyAudio.app \
  -ov -format UDZO OnlyAudio.dmg
```

### 3. Notariser

```bash
xcrun notarytool submit OnlyAudio.dmg \
  --apple-id "TON_APPLE_ID" \
  --password "MOT_DE_PASSE_APP_SPECIFIQUE" \
  --team-id "TEAM_ID" \
  --wait

xcrun stapler staple OnlyAudio.dmg
```

> Pour une distribution personnelle/test, tu peux simplement contourner Gatekeeper sur le Mac cible : `xattr -rd com.apple.quarantine OnlyAudio.app`

---

## Architecture technique macOS

### Moteur audio

L'audio est géré par **media_kit** (libmpv) via `media_kit_libs_macos_audio`. Le même mécanisme que Windows est utilisé :

- **Serveur HTTP local** (127.0.0.1, port aléatoire) — libmpv reçoit les fichiers via HTTP pour éviter les problèmes de permissions sandbox
- **Dual-player pre-buffering** — le titre suivant est pré-bufferisé silencieusement, le swap est instantané

### Entitlements sandbox

| Permission | Rôle |
|-----------|------|
| `com.apple.security.app-sandbox` | Isolation macOS (obligatoire pour App Store) |
| `com.apple.security.network.server` | Serveur HTTP local (streaming audio vers libmpv) |
| `com.apple.security.network.client` | Client localhost (connexion au serveur) |
| `com.apple.security.files.user-selected.read-write` | Lecture des fichiers audio sélectionnés par l'utilisateur |

### Fenêtre

Gérée par **window_manager** — taille minimale 700×480, titre « OnlyAudio by AudioFeel ».

---

## Fonctionnalités supportées

| Fonctionnalité | macOS |
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

### Pas de son
Vérifier que les entitlements `network.server` et `network.client` sont bien présents dans `macos/Runner/DebugProfile.entitlements` et `Release.entitlements`.

### "App is damaged and can't be opened"
```bash
xattr -rd com.apple.quarantine /Applications/OnlyAudio.app
```

### pod install échoue
```bash
sudo gem install cocoapods
cd macos && pod repo update && pod install
```

### Flutter introuvable
Ajouter Flutter au PATH :
```bash
export PATH="$PATH:/chemin/vers/flutter/bin"
```

---

## Auteur

**AudioFeel** — © 2026
