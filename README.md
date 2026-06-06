# lazy_word

`lazy_word` is a local-first Flutter flashcard app for learning vocabulary from downloaded Anki `.apkg` decks.

The app imports an APKG file on-device, parses the Anki collection and media locally, stores cards and review progress in SQLite, and provides two swipe-based study flows:

- Read-through mode for moving through a deck and marking unknown cards.
- Unknown review mode for weighted practice until difficult cards are known consistently.

There are no accounts, backend services, sync, analytics, telemetry, or network features. Deck data, media, and progress stay on the device.

## Tech

- Flutter desktop/mobile app
- Local SQLite storage with `sqflite` and `sqflite_common_ffi`
- APKG archive parsing with local media extraction
- HTML card rendering with `flutter_html`
- Local audio playback, including `ffplay` on Linux

## Development

```bash
flutter pub get
flutter analyze --no-pub
flutter test
flutter build linux --no-pub
flutter build apk --release
```

## Linux Package

Build the Debian package:

```bash
scripts/build_deb.sh
```

The package is written to:

```text
dist/lazy-word_1.0.0_amd64.deb
```

## Linux Install

Install the packaged Debian build from the repository root:

```bash
sudo apt install ./dist/lazy-word_1.0.0_amd64.deb
```

Or install with an absolute path from anywhere:

```bash
sudo apt install /home/ubuntu/lazy_word/dist/lazy-word_1.0.0_amd64.deb
```

Run the app:

```bash
lazy-word
```

if you got this issue

```bash
/opt/lazy-word/lazy_word: symbol lookup error: /opt/lazy-word/lazy_word: undefined symbol: g_once_init_enter_pointer
```
try to upgrade you ubuntu to 26.04, since i developed in this distro

If `apt` cannot resolve the local file path, use `dpkg`:

```bash
sudo dpkg -i ./dist/lazy-word_1.0.0_amd64.deb
sudo apt-get install -f
```

## Linux Uninstall

Remove the app package:

```bash
sudo apt remove lazy-word
```

Remove package configuration too:

```bash
sudo apt purge lazy-word
```

Imported decks and review progress are user data and are not deleted by package removal. To reset the app completely:

```bash
rm -f "$HOME/.dart_tool/sqflite_common_ffi/databases/lazy_word.db"*
rm -rf "$HOME/Documents/lazy_word"
```

# Android Install
`/home/ubuntu/develop/android-sdk/platform-tools/adb install build/app/outputs/flutter-apk/app-release.apk`

## Download the apkg resource from
https://ankiweb.net/shared/decks?search=english&sort=rating

## License

MIT
