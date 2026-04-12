# Changelog

## [2.0.0] - 2026-04-12

### Nouveautés
- **Télécommande Android** — Nouvelle application mobile pour contrôler OnlyAudio depuis votre téléphone
  - Connexion automatique par scan réseau ou saisie manuelle de l'IP
  - Contrôles complets : lecture/pause, précédent/suivant, volume, shuffle, repeat
  - Barre de progression avec seek
  - Affichage de la pochette, titre, artiste et album en temps réel
  - Notification média Android avec contrôles dans la barre de notifications
  - Navigation dans la playlist avec recherche
  - Sauvegarde de la dernière connexion

### Améliorations
- **Installateur** — Détection et désinstallation automatique de la version précédente lors de la mise à jour
- **Serveur distant** — API Flask intégrée au player desktop (port 5000) pour la communication avec la télécommande

### Technique
- Application Android développée en Flutter/Dart
- Communication HTTP temps réel entre mobile et desktop
- Compatible Android 5.0+ (API 21+)
- Compatible Xiaomi/MIUI et autres surcouches constructeur

## [1.0.0] - 2026

### Première release
- Lecteur audio desktop Windows (Python/Kivy)
- Lecture MP3/FLAC/WAV/OGG/M4A
- Affichage des métadonnées et pochettes d'album
- Playlist avec shuffle et repeat
- Interface sombre moderne
- Installateur Windows
