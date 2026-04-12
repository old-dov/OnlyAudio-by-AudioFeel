# 🎵 OnlyAudio v2.0.0 — Télécommande Android

Contrôlez OnlyAudio depuis votre téléphone ! Cette version majeure ajoute une application Android compagnon pour piloter le lecteur à distance sur votre réseau local.

---

## ✨ Nouveautés

### 📱 Télécommande Android
- **Connexion automatique** : scan du réseau local pour trouver le PC, ou saisie manuelle de l'IP
- **Contrôle complet** : lecture/pause, piste précédente/suivante, volume, shuffle, repeat
- **Affichage temps réel** : pochette d'album, titre, artiste, barre de progression avec seek
- **Notification média** : contrôles directement dans la barre de notifications Android
- **Playlist** : parcourir et rechercher dans la playlist, lancer n'importe quelle piste
- **Mémorisation** : sauvegarde automatique de la dernière connexion

### 🖥️ Player Desktop
- **Mise à jour simplifiée** : l'installateur détecte et désinstalle automatiquement la version précédente
- **Serveur API intégré** : communication temps réel avec la télécommande via le réseau local (port 5000)

---

## 📦 Téléchargement

| Fichier | Plateforme | Description |
|---------|-----------|-------------|
| `OnlyAudio_Setup.exe` | Windows 10/11 | Installateur desktop (inclut mise à jour auto) |
| `OnlyAudio_Remote.apk` | Android 5.0+ | Télécommande mobile |

### Installation
1. **Desktop** : Lancez `OnlyAudio_Setup.exe` et suivez les étapes
2. **Android** : Installez `OnlyAudio_Remote.apk` sur votre téléphone
3. Assurez-vous que les deux appareils sont sur le **même réseau Wi-Fi**
4. Lancez OnlyAudio sur le PC, puis ouvrez la télécommande

---

## 🔧 Notes techniques
- Compatible Xiaomi/MIUI, Samsung One UI et autres surcouches Android
- API REST HTTP sur port 5000 (communication en clair sur réseau local)
- L'application Android fonctionne même si le service de notification média n'est pas disponible

---

**Changelog complet** : [CHANGELOG.md](CHANGELOG.md)
