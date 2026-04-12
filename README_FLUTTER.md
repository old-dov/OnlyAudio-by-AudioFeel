# OnlyAudio by AudioFeel (Flutter)

Windows-first Flutter rewrite of the original `onlyaudio.py`.

## Features implemented

- Desktop 3-panel UI redesign (playlist, now-playing, controls)
- File and folder import with audio extension filtering
- Metadata parsing (title, artist, album, duration, cover art)
- Playback controls (play/pause, next/prev, seek, volume, shuffle, repeat)
- Browsing UX (live search, sort cycle, remove current, clear, jump to playing)
- Persistence of playlist + player state + browse state
- Android remote API parity on port `5000`

## Remote endpoints

- `/status`
- `/play_pause`
- `/prev`
- `/next`
- `/vol_up`
- `/vol_down`
- `/shuffle`
- `/repeat`

## Run

```bash
flutter pub get
flutter run -d windows
```

## Verify

```bash
flutter analyze
flutter test
```
