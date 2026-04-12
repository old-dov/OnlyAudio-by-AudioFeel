# 🎵 OnlyAudio by AudioFeel

Lecteur audio desktop Windows avec télécommande Android.

![Windows](https://img.shields.io/badge/Windows-10%2F11-blue?logo=windows)
![Android](https://img.shields.io/badge/Android-5.0%2B-green?logo=android)
![Version](https://img.shields.io/badge/version-2.0.0-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

---

## Fonctionnalités

### 🖥️ Player Desktop (Windows)
- Lecture audio : MP3, FLAC, WAV, OGG, M4A
- Affichage des métadonnées (titre, artiste, album, pochette)
- Playlist complète avec shuffle et repeat
- Barre de progression avec seek
- Contrôle du volume
- Interface sombre moderne
- Installateur avec mise à jour automatique

### 📱 Télécommande Android
- Contrôle du player desktop depuis votre téléphone
- Détection automatique du PC sur le réseau local
- Pochette d'album, titre, artiste en temps réel
- Contrôles : lecture, pause, précédent, suivant, shuffle, repeat, volume
- Notification média avec contrôles dans la barre Android
- Navigation et recherche dans la playlist

---

## Installation

### Desktop (Windows)
1. Téléchargez `OnlyAudio_Setup.exe` depuis la [page Releases](../../releases/latest)
2. Lancez l'installateur
3. OnlyAudio est prêt !

> La mise à jour détecte et désinstalle automatiquement la version précédente.

### Télécommande Android
1. Téléchargez `OnlyAudio_Remote.apk` depuis la [page Releases](../../releases/latest)
2. Installez l'APK sur votre téléphone
3. Lancez OnlyAudio sur le PC
4. Ouvrez la télécommande → scan automatique ou saisie de l'IP du PC

> **Important** : Le téléphone et le PC doivent être sur le même réseau Wi-Fi.

---

## Comment ça marche

```
┌──────────────┐     HTTP (port 5000)     ┌──────────────────┐
│   OnlyAudio  │ ◄──────────────────────► │  OnlyAudio       │
│   Desktop    │     réseau local Wi-Fi   │  Remote (Android) │
│   (Windows)  │                          │                   │
└──────────────┘                          └──────────────────┘
```

Le player desktop embarque un serveur API sur le port 5000. La télécommande Android communique avec ce serveur pour envoyer les commandes et recevoir l'état de lecture en temps réel.

---

## Stack technique

| Composant | Technologies |
|-----------|-------------|
| Player Desktop | Python, Kivy, pygame, Mutagen, Flask |
| Télécommande Android | Flutter, Dart, audio_service |
| Communication | API REST HTTP (JSON) |
| Installateur | PyInstaller + Inno Setup |

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

### Desktop
```powershell
# Prérequis : Python 3.12, venv avec les dépendances
.venv312\Scripts\python.exe -m PyInstaller onlyaudio.spec --noconfirm
# Puis compiler l'installateur avec Inno Setup
ISCC.exe installer.iss
```

### Télécommande Android
```powershell
cd remote_app
flutter build apk --release
# APK : build/app/outputs/flutter-apk/app-release.apk
```

---

## Auteur

**AudioFeel** — © 2026
