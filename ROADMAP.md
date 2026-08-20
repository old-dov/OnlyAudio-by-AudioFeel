# Roadmap

Fonctionnalités envisagées, pas encore planifiées à une version précise.

## Known issues

### "À suivre" ne s'affiche pas sur la télécommande (2026-08-20) — RÉSOLU

L'installeur `OnlyAudio_Setup_v2.4.0.exe` publié sur la release a été compilé
depuis le commit `8ad209f`, **avant** l'ajout de `next_title`/`next_artist`
dans `remoteStatusPayload()` (commit `805e63e`). Le player desktop
actuellement installé par les utilisateurs ne renvoie donc pas ces champs sur
`/status`, et la télécommande (qui masque la ligne "À suivre" quand
`nextTitle` est vide) n'affiche jamais rien à part le titre en cours.

**Ce n'était pas un bug de code** — le code des deux côtés était correct.
Corrigé en rebuild le player desktop en release et en remplaçant
`OnlyAudio_Setup_v2.4.0.exe` sur la release GitHub v2.4.0 par le nouveau
build (qui inclut bien `next_title`/`next_artist` dans `/status`).

## Support multilingue (FR / EN / DE / ES)

**Statut** : reporté (2026-08-20) — chantier identifié mais pas encore démarré.

Actuellement, tout le texte de l'UI (desktop **et** télécommande) est du français
en dur : aucune des deux apps n'a `flutter_localizations`/`intl`, ni fichiers
`.arb`. Le sélecteur de langue de l'installateur Inno Setup (FR/EN) ne concerne
que l'assistant d'installation — il n'a aucun effet sur la langue de l'appli
une fois lancée.

### Ce qu'il faudra faire
- Ajouter `flutter_localizations` + `intl` aux deux `pubspec.yaml` (desktop et `remote_app`)
- Créer les fichiers `.arb` pour FR/EN/DE/ES (8 fichiers au total, ~45-60 clés à traduire)
- Détecter la langue via la locale du système au démarrage (pas de lien possible avec le choix fait dans l'installateur Windows)
- Câbler `MaterialApp` (`localizationsDelegates`, `supportedLocales`) dans les deux apps
- Remplacer chaque chaîne en dur (`Text('...')`, labels de boutons via `_darkBtn(...)`, tooltips, hints) par la clé traduite correspondante — env. 11 fichiers concernés
- Rebuild + `flutter analyze` des deux apps pour vérifier qu'aucune chaîne n'a été oubliée

### Portée estimée
Chantier borné mais transverse aux deux apps — pas un patch ponctuel. À reprendre en une session dédiée.
