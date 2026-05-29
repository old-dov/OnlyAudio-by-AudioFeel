# 🎵 OnlyAudio by AudioFeel

Lecteur audio desktop Windows & macOS avec télécommande Android.

![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?logo=windows)
![macOS](https://img.shields.io/badge/macOS-10.14%2B-lightgrey?logo=apple)
![Linux](https://img.shields.io/badge/Linux-x64-orange?logo=linux)
![Android](https://img.shields.io/badge/Android-5.0%2B-green?logo=android)
![Flutter](https://img.shields.io/badge/Flutter-3.41%2B-blue?logo=flutter)
![Version](https://img.shields.io/badge/version-2.0.0-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Fonctionnalités

### 🖥️ Player Desktop (Windows, macOS & Linux)
- Lecture audio : MP3, FLAC, WAV, OGG, M4A, AAC
- Affichage des métadonnées (titre, artiste, album, année, pochette)
- Playlist complète avec shuffle et repeat
- Barre de progression avec seek
- Contrôle du volume
- Plein écran
- Interface sombre moderne
- Pre-buffering dual-player (changement de piste instantané)
- Installateur Windows avec mise à jour automatique

### 📱 Télécommande Android
- Contrôle du player desktop depuis votre téléphone
- Détection automatique du PC sur le réseau local
- Pochette d'album, titre, artiste en temps réel
- Contrôles : lecture, pause, précédent, suivant, shuffle, repeat, volume
- Notification média avec contrôles dans la barre Android
- Navigation et recherche dans la playlist

---

## Installation

### Desktop Windows
1. Téléchargez `OnlyAudio_Setup.exe` depuis la [page Releases](../../releases/latest)
2. Lancez l'installateur
3. OnlyAudio est prêt !

> La mise à jour détecte et désinstalle automatiquement la version précédente.

### Desktop macOS
1. Téléchargez `OnlyAudio-mac.zip` depuis la [page Releases](../../releases/latest)
2. Décompressez et glissez `OnlyAudio.app` dans votre dossier Applications
3. Au premier lancement : clic droit → Ouvrir (si Gatekeeper le bloque)

> Pour compiler depuis les sources, voir [docs/macos_build.md](docs/macos_build.md).

### Desktop Linux
1. Téléchargez `OnlyAudio-x86_64.AppImage` depuis la [page Releases](../../releases/latest)
2. Rendez-le exécutable : `chmod +x OnlyAudio-x86_64.AppImage`
3. Lancez : `./OnlyAudio-x86_64.AppImage`

> Pour compiler depuis les sources, voir [docs/linux_build.md](docs/linux_build.md).

### Télécommande Android
1. Téléchargez `OnlyAudio_Remote.apk` depuis la [page Releases](../../releases/latest)
2. Installez l'APK sur votre téléphone
3. Lancez OnlyAudio sur le PC
4. Ouvrez la télécommande → scan automatique ou saisie de l'IP du PC

> **Important** : Le téléphone et le PC doivent être sur le même réseau Wi-Fi.

---

## Comment ça marche

```
┌──────────────────────────────┐     HTTP (port 5000)     ┌──────────────────┐
│     OnlyAudio Desktop        │ ◄──────────────────────► │  OnlyAudio       │
│  (Windows / macOS / Linux)   │     réseau local Wi-Fi   │  Remote (Android) │
└──────────────────────────────┘                          └──────────────────┘
```

Le player desktop embarque un serveur API sur le port 5000. La télécommande Android communique avec ce serveur pour envoyer les commandes et recevoir l'état de lecture en temps réel.

---

## Stack technique

| Composant | Technologies |
|-----------|-------------|
| Player Desktop (Windows, macOS & Linux) | Flutter, Dart, media_kit (libmpv) |
| Télécommande Android | Flutter, Dart, audio_service |
| Communication | API REST HTTP (JSON) |
| Installateur Windows | Inno Setup |

---

## Endpoints API

| Endpoint | Description |
|----------|-------------|
| `GET /status` | État actuel (titre, artiste, album, position, durée, pochette) |
| `GET /playlist` | Liste des pistes, état shuffle/repeat |
| `POST /play_pause` | Lecture / Pause |
| `POST /prev` | Piste précédente |
| `POST /next` | Piste suivante |
| `POST /vol_up` | Volume + |
| `POST /vol_down` | Volume - |
| `POST /shuffle` | Toggle shuffle |
| `POST /repeat` | Toggle repeat |
| `POST /seek/<ms>` | Seek à la position (ms) |
| `POST /play_index/<i>` | Jouer la piste n°i |
| `GET /discover` | Vérifier la présence du serveur |

---

## Build depuis les sources

### Desktop Windows
```powershell
flutter pub get
./scripts/build_windows_release.ps1
```

Pour preparer directement les livrables de distribution dans `dist` :

```powershell
./scripts/publish_windows_release.ps1
```

Ce script :
- lance le build Windows release
- compile l'installateur
- met a jour `dist/OnlyAudio/` avec la version portable
- copie `OnlyAudio_Setup.exe` dans `dist/`

Le script accepte un compilateur Inno Setup explicite et refuse les builds preview par defaut.

```powershell
# Utiliser un ISCC.exe stable installe ailleurs
./scripts/build_windows_release.ps1 -IsccPath "D:\Tools\Inno Setup 7\ISCC.exe"

# Ou definir le chemin une fois pour la session
$env:ONLYAUDIO_ISCC_PATH = "D:\Tools\Inno Setup 7\ISCC.exe"
./scripts/build_windows_release.ps1

# Autoriser volontairement une version preview si necessaire
./scripts/build_windows_release.ps1 -AllowPreview

# Publier tous les livrables dans dist avec un ISCC.exe explicite
./scripts/publish_windows_release.ps1 -IsccPath "D:\Tools\Inno Setup 7\ISCC.exe"
```

### Desktop macOS
Voir le guide complet : [docs/macos_build.md](docs/macos_build.md)

```bash
flutter pub get
cd macos && pod install && cd ..
flutter build macos --release
```

### Desktop Linux
Voir le guide complet : [docs/linux_build.md](docs/linux_build.md)

```bash
flutter pub get
flutter build linux --release
```

### Télécommande Android
```bash
cd remote_app
flutter build apk --release
# APK : build/app/outputs/flutter-apk/app-release.apk
```

---

## Auteur

**AudioFeel** — © 2026
