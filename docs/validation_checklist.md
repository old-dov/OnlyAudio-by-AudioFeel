# Validation Checklist (Windows)

## Functional parity

- [ ] Launch app and verify title "OnlyAudio by AudioFeel"
- [ ] Add files and folder, confirm dedup works
- [ ] Play/pause/next/prev behavior
- [ ] Seek and volume updates
- [ ] Shuffle and repeat toggles affect playback sequence
- [ ] Remove current track and clear playlist edge cases
- [ ] Search + sort (added/title/folder) update playlist view
- [ ] Jump to now playing centers selection
- [ ] Restart app and verify state persistence

## Remote API parity

- [ ] `GET /status` returns JSON with keys: `title`, `artist`, `album`, `pos`, `dur`, `cover_b64`
- [ ] `GET /play_pause` returns `OK` and toggles playback
- [ ] `GET /prev` returns `OK` and switches to previous track
- [ ] `GET /next` returns `OK` and switches to next track
- [ ] `GET /vol_up` returns `OK` and increases volume
- [ ] `GET /vol_down` returns `OK` and decreases volume
- [ ] `GET /shuffle` returns `OK` and toggles shuffle mode
- [ ] `GET /repeat` returns `OK` and toggles repeat mode

## Packaging

- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build windows`
