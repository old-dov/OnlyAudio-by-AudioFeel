# OnlyAudio — Guide d'utilisation macOS

> Guide destiné aux utilisateurs macOS, sans aucune notion technique requise.

---

## 1. Installation

### Télécharger l'application

1. Va sur la page **[Releases du projet](https://github.com/old-dov/OnlyAudio-by-AudioFeel/releases/latest)**
2. Sous la section **Assets**, clique sur **OnlyAudio-macOS.zip** pour le télécharger

### Installer l'application

1. Double-clique sur le fichier `OnlyAudio-macOS.zip` pour l'extraire — tu obtiens `OnlyAudio.app`
2. Glisse `OnlyAudio.app` dans ton dossier **Applications**

### Premier lancement (contourner l'avertissement macOS)

Comme l'application n'est pas signée par Apple, macOS va bloquer le premier lancement. C'est normal.

**Comment l'ouvrir quand même :**

1. Va dans ton dossier **Applications**
2. **Clic droit** (ou Control + clic) sur `OnlyAudio.app`
3. Clique sur **Ouvrir**
4. Dans la fenêtre d'avertissement, clique à nouveau sur **Ouvrir**

> Cette manipulation n'est nécessaire qu'une seule fois. Les lancements suivants fonctionnent normalement.

---

## 2. Découvrir l'interface

```
┌─────────────────────────────────────────────────────────────────┐
│  Logo  OnlyAudio · Your sound. Your way.       12:34:56  ⛶  X  │  ← Barre du haut
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│                      Pochette de l'album                         │  ← Zone centrale
│                       (fond de l'app)                            │
│                                                                  │
├──────────┬───┬───────────────────────────┬───┬──────────────────┤
│          │   │                           │   │                  │
│ PLAYLIST │ ‹ │   Titre · Artiste · Info  │ › │    CONTRÔLES     │  ← Barre du bas
│          │   │   ══════════════════════  │   │                  │
│          │   │   Barre de progression    │   │  |<  PLAY  >|   │
└──────────┴───┴───────────────────────────┴───┴──────────────────┘
```

L'application est organisée en **3 colonnes** en bas :
- **Gauche** : la playlist (liste des morceaux)
- **Centre** : les infos du morceau en cours + progression
- **Droite** : les boutons de contrôle

Les petites **flèches `‹` et `›`** entre les colonnes permettent de masquer ou afficher chaque volet.

---

## 3. Ajouter de la musique

Dans le volet **Playlist** (à gauche) :

| Bouton | Action |
|--------|--------|
| **+FICHIER** | Ajoute un ou plusieurs fichiers audio |
| **+DOSSIER** | Ajoute tous les fichiers audio d'un dossier entier |
| **-TITRE** | Retire le morceau actuellement en lecture |
| **VIDER** | Vide toute la playlist |

**Formats supportés :** MP3, FLAC, WAV, OGG, M4A, AAC

---

## 4. Lire de la musique

- **Clic sur un titre** dans la playlist → lance ce morceau
- **Double barre d'espace** sur la barre de progression → avance ou recule dans le morceau (glisse avec la souris)

Dans le volet **Contrôles** (à droite) :

| Bouton | Action |
|--------|--------|
| **\|<** | Morceau précédent |
| **PLAY / PAUSE** | Lancer ou mettre en pause |
| **>\|** | Morceau suivant |
| **ALEA** | Lecture aléatoire (vert = activé) |
| **BOUCLE** | Répéter la playlist (vert = activé) |
| **−** et **+** | Baisser ou monter le volume |

Le **slider de volume** (la barre bleue) peut aussi être glissé directement.

---

## 5. Rechercher un morceau

Dans le volet Playlist, utilise le **champ de recherche** pour filtrer les titres en temps réel.

Le bouton **TRI** à côté permet de changer l'ordre d'affichage (nom, durée, etc.).

---

## 6. Plein écran

Clique sur l'icône **⛶** en haut à droite pour passer en plein écran.  
Clique à nouveau pour revenir en mode fenêtré.

---

## 7. Télécommande Android (optionnel)

OnlyAudio peut être contrôlé depuis ton téléphone Android via l'app **OnlyAudio Remote**.

**Prérequis :** le téléphone et le Mac doivent être connectés au **même réseau Wi-Fi**.

1. Télécharge **OnlyAudio_Remote.apk** depuis la page Releases
2. Installe-le sur ton téléphone (autorise les sources inconnues si demandé)
3. Lance OnlyAudio sur le Mac
4. Ouvre la télécommande → elle détecte automatiquement le Mac

Depuis le téléphone tu peux : lecture/pause, piste suivante/précédente, volume, shuffle, repeat, voir la pochette et naviguer dans la playlist.

---

## 8. Quitter l'application

Clique sur le **X** en haut à droite de l'application.

---

## En cas de problème

- **L'app ne s'ouvre pas** → Vérifie que tu as bien fait clic droit → Ouvrir au premier lancement
- **Pas de son** → Vérifie que le volume macOS n'est pas coupé et que le slider de volume dans l'app n'est pas à zéro
- **La télécommande ne trouve pas le Mac** → Vérifie que le téléphone et le Mac sont sur le même Wi-Fi

---

*OnlyAudio by AudioFeel — © 2026*
